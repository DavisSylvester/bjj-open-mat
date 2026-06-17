import type {
  Attendee,
  AttendeesResponse,
  OpenMat,
  OpenMatDetail,
  OpenMatListResponse,
  RsvpResponse,
} from "@bjj/contract";
import type { OpenMatRepository } from "../repositories/open-mat.repository.mts";

export interface OpenMatListFilters {
  dayOfWeek?: number;
  limit?: number;
  page?: number;
}

// Demo identity used for RSVP in the seed/no-auth scaffold. Replaced by the
// authenticated user id once auth middleware is wired.
const DEMO_USER: Attendee = {
  userId: "u-me",
  name: "You",
  beltRank: "blue",
  beltStripes: 2,
  skillLevel: "intermediate",
  rsvpAt: "",
};

export class OpenMatService {
  public constructor(private readonly repo: OpenMatRepository) {}

  public list(filters: OpenMatListFilters): OpenMatListResponse {
    let mats: OpenMat[] = this.repo.findAll();
    if (filters.dayOfWeek !== undefined) {
      mats = mats.filter((m) => m.dayOfWeek === filters.dayOfWeek);
    }
    // Sort by start time, then nearest-first as the tiebreak.
    mats.sort((a, b) => {
      const byTime = a.startTime.localeCompare(b.startTime);
      if (byTime !== 0) return byTime;
      return (a.distanceKm ?? Number.POSITIVE_INFINITY) - (b.distanceKm ?? Number.POSITIVE_INFINITY);
    });
    return { data: mats, count: mats.length };
  }

  public detail(id: string): OpenMatDetail | undefined {
    return this.repo.findById(id);
  }

  public attendees(id: string): AttendeesResponse {
    const data = this.repo.attendeesFor(id);
    return { data, count: data.length };
  }

  public rsvp(id: string, sessionDate: string, nowIso: string): RsvpResponse {
    const list = this.repo.addAttendee(id, { ...DEMO_USER, rsvpAt: nowIso });
    return { ok: true, attendeeCount: list.length, attending: true };
  }

  public cancelRsvp(id: string): RsvpResponse {
    const list = this.repo.removeAttendee(id, DEMO_USER.userId);
    return { ok: true, attendeeCount: list.length, attending: false };
  }
}
