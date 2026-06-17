import type { Attendee, OpenMatDetail } from "@bjj/contract";
import { seedAttendees, seedOpenMats } from "../data/seed.mts";

// Owns all data access. Swap the in-memory seed for a real datastore here
// without touching the service or routes.
export class OpenMatRepository {
  private readonly openMats: OpenMatDetail[];
  private readonly attendees: Map<string, Attendee[]>;

  public constructor() {
    this.openMats = seedOpenMats.map((m) => ({ ...m }));
    this.attendees = new Map(
      Object.entries(seedAttendees).map(([id, list]) => [id, list.map((a) => ({ ...a }))]),
    );
  }

  public findAll(): OpenMatDetail[] {
    return this.openMats.map((m) => ({ ...m }));
  }

  public findById(id: string): OpenMatDetail | undefined {
    const found = this.openMats.find((m) => m.id === id);
    return found ? { ...found } : undefined;
  }

  public attendeesFor(id: string): Attendee[] {
    return (this.attendees.get(id) ?? []).map((a) => ({ ...a }));
  }

  public addAttendee(id: string, attendee: Attendee): Attendee[] {
    const list = this.attendees.get(id) ?? [];
    if (!list.some((a) => a.userId === attendee.userId)) {
      list.push(attendee);
    }
    this.attendees.set(id, list);
    this.syncCount(id);
    return this.attendeesFor(id);
  }

  public removeAttendee(id: string, userId: string): Attendee[] {
    const list = (this.attendees.get(id) ?? []).filter((a) => a.userId !== userId);
    this.attendees.set(id, list);
    this.syncCount(id);
    return this.attendeesFor(id);
  }

  private syncCount(id: string): void {
    const mat = this.openMats.find((m) => m.id === id);
    if (mat) {
      mat.attendeeCount = (this.attendees.get(id) ?? []).length;
    }
  }
}
