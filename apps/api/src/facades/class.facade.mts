// apps/api/src/facades/class.facade.mts
import type {
  ClassAttendee, ClassOccurrence, CreateClassRequest, GymClass, OccurrenceOverrideRequest,
  ScheduledClass, UpdateClassRequest, UserRole,
} from '@bjj/contract';
import { AppError } from '../http/errors.mts';
import { assertCanManageGym } from './gym-authz.mts';
import type { ClassRepository } from '../repositories/class.repository.mts';
import type { ClassOccurrenceRepository } from '../repositories/class-occurrence.repository.mts';
import type { ClassRsvpRepository } from '../repositories/class-rsvp.repository.mts';
import type { MembershipRepository } from '../repositories/membership.repository.mts';
import type { GymRepository } from '../repositories/gym.repository.mts';
import type { UserRepository } from '../repositories/user.repository.mts';

type IdFactory = () => string;
type ClassRepo = Pick<ClassRepository, 'insert' | 'findById' | 'listActiveByGym' | 'update'>;
type OccRepo = Pick<ClassOccurrenceRepository, 'upsert' | 'find' | 'listByGymRange'>;
type RsvpRepo = Pick<ClassRsvpRepository, 'add' | 'remove' | 'count' | 'countsForClassDates' | 'list'>;
type MemberRepo = Pick<MembershipRepository, 'find'>;
type GymRepo = Pick<GymRepository, 'findById'>;
type UserRepo = Pick<UserRepository, 'findById'>;

// Weekday (0=Sun..6=Sat) for an ISO YYYY-MM-DD date, in UTC.
function weekdayOf(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

// Every ISO date in [from,to] inclusive.
function datesInRange(from: string, to: string): string[] {
  const out: string[] = [];
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  for (let t = start.getTime(); t <= end.getTime(); t += 86_400_000) {
    out.push(new Date(t).toISOString().slice(0, 10));
  }
  return out;
}

export function occursOn(cls: GymClass, date: string): boolean {
  if (cls.isRecurring) return cls.dayOfWeek !== undefined && weekdayOf(date) === cls.dayOfWeek;
  return cls.specificDate === date;
}

export class ClassFacade {

  public constructor(
    private readonly classes: ClassRepo,
    private readonly occurrences: OccRepo,
    private readonly rsvps: RsvpRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  public async create(callerId: string, gymId: string, req: CreateClassRequest, callerRole: UserRole): Promise<GymClass> {
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, gymId, callerRole);
    const isRecurring: boolean = req.isRecurring ?? true;
    if (isRecurring && req.dayOfWeek === undefined) throw new AppError('bad_request', 'Recurring class requires dayOfWeek');
    if (!isRecurring && !req.specificDate) throw new AppError('bad_request', 'One-off class requires specificDate');
    const cls: GymClass = {
      ...req,
      isRecurring,
      id: this.newId(),
      gymId,
      status: 'active',
      createdAt: new Date().toISOString(),
    };
    return this.classes.insert(cls);
  }

  public async listDefinitions(gymId: string): Promise<GymClass[]> {
    return this.classes.listActiveByGym(gymId);
  }

  private async getClassOr404(classId: string): Promise<GymClass> {
    const cls: GymClass | null = await this.classes.findById(classId);
    if (!cls) throw new AppError('not_found', `Class ${classId} not found`);
    return cls;
  }

  public async update(callerId: string, classId: string, req: UpdateClassRequest, callerRole: UserRole): Promise<GymClass> {
    const cls: GymClass = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    return (await this.classes.update(classId, req)) as GymClass;
  }

  public async archive(callerId: string, classId: string, callerRole: UserRole): Promise<void> {
    const cls: GymClass = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    await this.classes.update(classId, { status: 'archived' });
  }

  public async overrideOccurrence(
    callerId: string, classId: string, date: string, req: OccurrenceOverrideRequest, callerRole: UserRole,
  ): Promise<ClassOccurrence> {
    const cls: GymClass = await this.getClassOr404(classId);
    await assertCanManageGym({ gyms: this.gyms, memberships: this.memberships }, callerId, cls.gymId, callerRole);
    if (!occursOn(cls, date)) throw new AppError('bad_request', `${date} is not an occurrence of class ${classId}`);
    const existing: ClassOccurrence | null = await this.occurrences.find(classId, date);
    const occurrence: ClassOccurrence = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, date,
      status: req.status ?? existing?.status ?? 'scheduled',
      startTime: req.startTime ?? existing?.startTime,
      endTime: req.endTime ?? existing?.endTime,
      instructorUserId: req.instructorUserId ?? existing?.instructorUserId,
      instructorName: req.instructorName ?? existing?.instructorName,
      note: req.note ?? existing?.note,
    };
    return this.occurrences.upsert(occurrence);
  }

  public async schedule(gymId: string, from: string, to: string): Promise<ScheduledClass[]> {
    const [classes, overrides]: [GymClass[], ClassOccurrence[]] = await Promise.all([
      this.classes.listActiveByGym(gymId),
      this.occurrences.listByGymRange(gymId, from, to),
    ]);
    const overrideByKey = new Map<string, ClassOccurrence>();
    for (const o of overrides) overrideByKey.set(`${o.classId}:${o.date}`, o);

    const range: string[] = datesInRange(from, to);
    const result: ScheduledClass[] = [];
    for (const cls of classes) {
      const dates: string[] = range.filter((d) => occursOn(cls, d));
      const counts: Record<string, number> = await this.rsvps.countsForClassDates(cls.id, dates);
      for (const date of dates) {
        const ov: ClassOccurrence | undefined = overrideByKey.get(`${cls.id}:${date}`);
        result.push({
          classId: cls.id, gymId, date, title: cls.title,
          classType: cls.classType, classTypeLabel: cls.classTypeLabel,
          giType: cls.giType, skillLevel: cls.skillLevel,
          startTime: ov?.startTime ?? cls.startTime,
          endTime: ov?.endTime ?? cls.endTime,
          instructorUserId: ov?.instructorUserId ?? cls.instructorUserId,
          instructorName: ov?.instructorName ?? cls.instructorName,
          status: ov?.status ?? 'scheduled',
          note: ov?.note,
          capacity: cls.capacity,
          goingCount: counts[date] ?? 0,
        });
      }
    }
    result.sort((a, b) => (a.date === b.date ? a.startTime.localeCompare(b.startTime) : a.date.localeCompare(b.date)));
    return result;
  }

  public async rsvp(userId: string, classId: string, date: string): Promise<void> {
    const cls: GymClass = await this.getClassOr404(classId);
    if (!occursOn(cls, date)) throw new AppError('bad_request', `${date} is not an occurrence of class ${classId}`);
    const ov: ClassOccurrence | null = await this.occurrences.find(classId, date);
    if (ov?.status === 'cancelled') throw new AppError('conflict', 'This class occurrence is cancelled');
    if (cls.capacity !== undefined) {
      const going: number = await this.rsvps.count(classId, date);
      if (going >= cls.capacity) throw new AppError('conflict', 'This class is full');
    }
    const membership = await this.memberships.find(cls.gymId, userId);
    const isMember: boolean = membership !== null && membership.status === 'active';
    await this.rsvps.add(classId, date, userId, isMember);
  }

  public async unrsvp(userId: string, classId: string, date: string): Promise<void> {
    await this.rsvps.remove(classId, date, userId);
  }

  public async attendees(classId: string, date: string): Promise<ClassAttendee[]> {
    const rows = await this.rsvps.list(classId, date);
    return Promise.all(rows.map(async (r): Promise<ClassAttendee> => {
      const u = await this.users.findById(r.userId);
      return {
        userId: r.userId, isMember: r.isMember,
        name: u?.displayName ?? 'Guest', beltRank: u?.beltRank, avatarUrl: u?.avatarUrl,
        hasProfile: u !== null,
      };
    }));
  }
}
