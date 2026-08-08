import type {
  AdminMembersTree,
  AdminRosterRow,
  GymSummary,
  NoGymUserRow,
  StateGroup,
} from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { GymMemberCounts, MembershipRepository } from "../repositories/membership.repository.mjs";
import type { UserRepository } from "../repositories/user.repository.mjs";
import type { GymFacade } from "./gym.facade.mjs";

export type MembershipRepo = Pick<MembershipRepository, "countsByGym" | "listByGymForAdmin">;
export type UserRepo = Pick<UserRepository, "findByIds" | "listWithoutMemberships">;
export type GymRepo = Pick<GymFacade, "list">;

/// Gyms are read in one page large enough to cover the directory. The tree is
/// only as complete as this read, which is the documented limit in the spec:
/// past a few thousand gyms the tree itself needs paging.
const GYM_SCAN_LIMIT = 5000;

export class AdminMembersFacade {

  public constructor(
    private readonly memberships: MembershipRepo,
    private readonly users: UserRepo,
    private readonly gyms: GymRepo,
  ) {}

  public async tree(): Promise<AdminMembersTree> {
    const [counts, gymPage, gymless] = await Promise.all([
      this.memberships.countsByGym(),
      this.gyms.list({ skip: 0, limit: GYM_SCAN_LIMIT }),
      this.users.listWithoutMemberships(0, 1),
    ]);

    // The tree is only as complete as this single page of gyms. Past the limit
    // a gym with members can only be reported as unknown, so say so out loud
    // rather than truncating in silence.
    if (gymPage.total > GYM_SCAN_LIMIT) {
      logger.warn(
        `Admin members tree scanned ${GYM_SCAN_LIMIT} of ${gymPage.total} gyms; gyms past the scan limit surface as unknown`,
        { total: gymPage.total, limit: GYM_SCAN_LIMIT },
      );
    }

    const countByGymId = new Map<string, GymMemberCounts>(counts.map((c) => [c.gymId, c]));

    // Only gyms that actually have members belong here. Including all of them
    // would bury a handful of real rows under hundreds of empty ones.
    const summaries: GymSummary[] = [];
    const stateByGymId = new Map<string, string | undefined>();
    const matchedGymIds = new Set<string>();
    for (const gym of gymPage.items) {
      const count = countByGymId.get(gym.id);
      if (!count) continue;
      matchedGymIds.add(gym.id);
      summaries.push({
        id: gym.id,
        name: gym.name,
        ...(gym.city === undefined ? {} : { city: gym.city }),
        ...(gym.ownerId === undefined ? {} : { ownerId: gym.ownerId }),
        memberCount: count.memberCount,
        pendingCount: count.pendingCount,
      });
      stateByGymId.set(gym.id, gym.state);
    }

    // A counted gymId with no gym document is a data error (deleted gym, or a
    // gym past the scan limit). Those memberships still exist, so surface them
    // under `(No State)` with a name that names the problem instead of letting
    // the rows disappear from every group.
    for (const count of counts) {
      if (matchedGymIds.has(count.gymId)) continue;
      summaries.push({
        id: count.gymId,
        name: `Unknown gym (${count.gymId})`,
        memberCount: count.memberCount,
        pendingCount: count.pendingCount,
      });
    }

    const byState = new Map<string, GymSummary[]>();
    const noState: GymSummary[] = [];
    for (const summary of summaries) {
      const state = stateByGymId.get(summary.id);
      if (state === undefined || state.length === 0) {
        noState.push(summary);
        continue;
      }
      const bucket = byState.get(state);
      if (bucket) bucket.push(summary);
      else byState.set(state, [summary]);
    }

    const byName = (a: GymSummary, b: GymSummary): number => a.name.localeCompare(b.name);
    const states: StateGroup[] = [...byState.entries()]
      .map(([state, gyms]): StateGroup => ({ state, gyms: [...gyms].sort(byName) }))
      .sort((a, b) => a.state.localeCompare(b.state));

    return {
      states,
      noState: noState.sort(byName),
      noGym: { userCount: gymless.total },
    };
  }

  public async gymRoster(
    gymId: string,
    skip: number,
    limit: number,
  ): Promise<{ items: AdminRosterRow[]; total: number }> {
    const { items, total } = await this.memberships.listByGymForAdmin(gymId, skip, limit);
    const users = await this.users.findByIds(items.map((m) => m.userId));
    const userById = new Map(users.map((u) => [u.id, u]));

    const rows: AdminRosterRow[] = items.map((m): AdminRosterRow => {
      const user = userById.get(m.userId);
      return {
        membershipId: m.id,
        gymId: m.gymId,
        userId: m.userId,
        // A membership pointing at a deleted user is a data error. Show the id
        // and flag it rather than dropping the row and under-reporting.
        displayName: user?.displayName ?? m.userId,
        email: user?.email ?? "",
        ...(m.gymRole === undefined ? {} : { gymRole: m.gymRole }),
        // Legacy rows predate the status field; the schema default is active.
        status: m.status ?? "active",
        visibleInRoster: m.visibleInRoster,
        verifiedMember: m.verifiedMember,
        joinedAt: m.joinedAt,
        ...(user ? {} : { unresolved: true }),
      };
    });

    return { items: rows, total };
  }

  public async noGymUsers(skip: number, limit: number): Promise<{ items: NoGymUserRow[]; total: number }> {
    const { items, total } = await this.users.listWithoutMemberships(skip, limit);
    return {
      items: items.map((u): NoGymUserRow => ({
        userId: u.id,
        displayName: u.displayName,
        email: u.email,
        createdAt: u.createdAt ?? "",
      })),
      total,
    };
  }
}
