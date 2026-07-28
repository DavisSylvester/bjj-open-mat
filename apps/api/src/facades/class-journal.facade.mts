// apps/api/src/facades/class-journal.facade.mts
import type {
  ClassJournalEntry, ClassOccurrence, GymClass, InstructorFeedbackItem, InstructorRating,
  InstructorRatingSummary, UpsertInstructorRatingRequest, UpsertJournalRequest, UserRole,
} from '@bjj/contract';
import { AppError } from '../http/errors.mts';
import { assertActiveMember, assertCanManageGym } from './gym-authz.mts';
import { occursOn } from './class.facade.mts';
import type { ClassJournalRepository } from '../repositories/class-journal.repository.mts';
import type { InstructorRatingRepository } from '../repositories/instructor-rating.repository.mts';
import type { ClassRepository } from '../repositories/class.repository.mts';
import type { ClassOccurrenceRepository } from '../repositories/class-occurrence.repository.mts';
import type { MembershipRepository } from '../repositories/membership.repository.mts';
import type { GymRepository } from '../repositories/gym.repository.mts';
import type { UserRepository } from '../repositories/user.repository.mts';

type IdFactory = () => string;
type JournalRepo = Pick<ClassJournalRepository, 'upsert' | 'findMine' | 'listByUserRange' | 'listSharedForOccurrence'>;
type RatingRepo = Pick<InstructorRatingRepository, 'upsert' | 'summaryForInstructor' | 'listForGymInstructor'>;
type ClassRepo = Pick<ClassRepository, 'findById'>;
type OccRepo = Pick<ClassOccurrenceRepository, 'find'>;
type MemberRepo = Pick<MembershipRepository, 'find'>;
type GymRepo = Pick<GymRepository, 'findById'>;
type UserRepo = Pick<UserRepository, 'findById'>;

export class ClassJournalFacade {

  public constructor(
    private readonly journals: JournalRepo,
    private readonly ratings: RatingRepo,
    private readonly classes: ClassRepo,
    private readonly occurrences: OccRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly newId: IdFactory,
  ) {}

  private async getClassOr404(classId: string): Promise<GymClass> {
    const cls = await this.classes.findById(classId);
    if (!cls) throw new AppError('not_found', `Class ${classId} not found`);
    return cls;
  }

  private authzDeps(): { gyms: GymRepo; memberships: MemberRepo } {
    return { gyms: this.gyms, memberships: this.memberships };
  }

  public async upsertJournal(userId: string, classId: string, req: UpsertJournalRequest, role: UserRole): Promise<ClassJournalEntry> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    if (!occursOn(cls, req.date)) throw new AppError('bad_request', `${req.date} is not an occurrence of class ${classId}`);
    const existing = await this.journals.findMine(classId, req.date, userId);
    const entry: ClassJournalEntry = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, userId, date: req.date,
      whatWasTaught: req.whatWasTaught,
      techniqueTags: req.techniqueTags ?? existing?.techniqueTags ?? [],
      rounds: req.rounds, intensity: req.intensity, partners: req.partners, note: req.note,
      shared: req.shared ?? existing?.shared ?? false,
      createdAt: existing?.createdAt,
    };
    return this.journals.upsert(entry);
  }

  public async myJournal(userId: string, from: string, to: string): Promise<ClassJournalEntry[]> {
    return this.journals.listByUserRange(userId, from, to);
  }

  public async sharedForOccurrence(userId: string, classId: string, date: string, role: UserRole): Promise<ClassJournalEntry[]> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    const shared = await this.journals.listSharedForOccurrence(classId, date);
    const mine = await this.journals.findMine(classId, date, userId);
    if (mine && !shared.some((e) => e.userId === userId)) return [mine, ...shared];
    return shared;
  }

  private resolveInstructor(cls: GymClass, occ: ClassOccurrence | null): { instructorUserId?: string; instructorName?: string } {
    return {
      instructorUserId: occ?.instructorUserId ?? cls.instructorUserId,
      instructorName: occ?.instructorName ?? cls.instructorName,
    };
  }

  public async rateInstructor(userId: string, classId: string, req: UpsertInstructorRatingRequest, role: UserRole): Promise<InstructorRating> {
    const cls = await this.getClassOr404(classId);
    await assertActiveMember(this.authzDeps(), userId, cls.gymId, role);
    if (!occursOn(cls, req.date)) throw new AppError('bad_request', `${req.date} is not an occurrence of class ${classId}`);
    const occ = await this.occurrences.find(classId, req.date);
    const instructor = this.resolveInstructor(cls, occ);
    const existing = (await this.ratings.listForGymInstructor(cls.gymId)).find(
      (r) => r.classId === classId && r.date === req.date && r.ratedByUserId === userId,
    );
    const rating: InstructorRating = {
      id: existing?.id ?? this.newId(),
      classId, gymId: cls.gymId, date: req.date,
      instructorUserId: instructor.instructorUserId,
      instructorName: instructor.instructorName,
      ratedByUserId: userId, stars: req.stars, comment: req.comment,
      anonymous: req.anonymous ?? false,
      createdAt: existing?.createdAt,
    };
    return this.ratings.upsert(rating);
  }

  public async instructorSummary(instructorUserId: string): Promise<InstructorRatingSummary> {
    const s = await this.ratings.summaryForInstructor(instructorUserId);
    return { instructorUserId, avg: s.avg, count: s.count };
  }

  public async gymInstructorFeedback(
    callerId: string, gymId: string, instructorUserId: string | undefined,
    from: string | undefined, to: string | undefined, role: UserRole,
  ): Promise<InstructorFeedbackItem[]> {
    await assertCanManageGym(this.authzDeps(), callerId, gymId, role);
    const rows = await this.ratings.listForGymInstructor(gymId, instructorUserId, from, to);
    return Promise.all(rows.map(async (r): Promise<InstructorFeedbackItem> => {
      let ratedByName: string | undefined;
      if (!r.anonymous) {
        const u = await this.users.findById(r.ratedByUserId);
        ratedByName = u?.displayName;
      }
      return { classId: r.classId, date: r.date, stars: r.stars, comment: r.comment, ratedByName, anonymous: r.anonymous, createdAt: r.createdAt };
    }));
  }
}
