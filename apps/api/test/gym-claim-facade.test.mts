import { describe, expect, it } from "bun:test";
import type {
  Gym,
  GymClaim,
  GymMembership,
  Notification,
  User,
} from "@bjj/contract";
import { AppError } from "../src/http/errors.mts";
import { GymClaimFacade } from "../src/facades/gym-claim.facade.mts";
import type { PushPayload } from "../src/push/push.types.mts";

// ── In-memory fakes ─────────────────────────────────────────────────────────
function makeFakes(seedGym: Partial<Gym> = {}, pushCapture?: { userIds: string[]; payload: PushPayload }[]): {
  facade: GymClaimFacade;
  claims: Map<string, GymClaim>;
  gyms: Map<string, Gym>;
  users: Map<string, User>;
  memberships: Map<string, GymMembership>;
  notifications: Notification[];
} {
  const claims = new Map<string, GymClaim>();
  const gyms = new Map<string, Gym>();
  const users = new Map<string, User>();
  const memberships = new Map<string, GymMembership>();
  const notifications: Notification[] = [];
  gyms.set("g1", { id: "g1", name: "Alliance", address: "1 Main St", amenities: [], isVerified: false, ...seedGym });

  const mkey = (gymId: string, userId: string): string => `${gymId}::${userId}`;
  let seq = 0;
  const newId = (): string => `id-${++seq}`;

  const gymClaimsRepo = {
    insert: async (c: GymClaim): Promise<GymClaim> => { claims.set(c.id, c); return c; },
    findById: async (id: string): Promise<GymClaim | null> => claims.get(id) ?? null,
    findPendingByGymAndClaimant: async (gymId: string, claimantId: string): Promise<GymClaim | null> =>
      [...claims.values()].find((c) => c.gymId === gymId && c.claimantId === claimantId && c.status === "pending") ?? null,
    findLatestByGymAndClaimant: async (gymId: string, claimantId: string): Promise<GymClaim | null> =>
      [...claims.values()]
        .filter((c) => c.gymId === gymId && c.claimantId === claimantId)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0] ?? null,
    listByStatus: async (status: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.status === status),
    listByClaimant: async (claimantId: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.claimantId === claimantId),
    listPendingByGym: async (gymId: string): Promise<GymClaim[]> =>
      [...claims.values()].filter((c) => c.gymId === gymId && c.status === "pending"),
    updateStatus: async (id: string, patch: Partial<GymClaim>): Promise<GymClaim | null> => {
      const cur = claims.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      claims.set(id, next);
      return next;
    },
  };
  const gymsRepo = {
    findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null,
    update: async (id: string, patch: Partial<Gym>): Promise<Gym | null> => {
      const cur = gyms.get(id);
      if (!cur) return null;
      const next = { ...cur, ...patch };
      gyms.set(id, next);
      return next;
    },
  };
  const usersRepo = {
    findById: async (id: string): Promise<User | null> => users.get(id) ?? null,
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = users.get(id) ?? ({ id } as User);
      const next = { ...cur, ...patch };
      users.set(id, next);
      return next;
    },
  };
  const membershipsRepo = {
    find: async (gymId: string, userId: string): Promise<GymMembership | null> => memberships.get(mkey(gymId, userId)) ?? null,
    update: async (gymId: string, userId: string, patch: Partial<GymMembership>): Promise<GymMembership | null> => {
      const cur = memberships.get(mkey(gymId, userId));
      if (!cur) return null;
      const next = { ...cur, ...patch };
      memberships.set(mkey(gymId, userId), next);
      return next;
    },
    upsertJoin: async (m: GymMembership): Promise<GymMembership> => {
      const existing = memberships.get(mkey(m.gymId, m.userId));
      if (existing) return existing;
      memberships.set(mkey(m.gymId, m.userId), m);
      return m;
    },
  };
  const notificationsRepo = {
    insert: async (n: Notification): Promise<Notification> => { notifications.push(n); return n; },
  };
  const pushes = pushCapture ?? [];
  const push = { pushToUsers: async (userIds: string[], payload: PushPayload): Promise<void> => { pushes.push({ userIds, payload }); } };

  const facade = new GymClaimFacade(gymClaimsRepo, gymsRepo, usersRepo, membershipsRepo, notificationsRepo, push, newId);
  return { facade, claims, gyms, users, memberships, notifications };
}

describe("GymClaimFacade — submit / cancel / reject", () => {
  it("submits a claim for an unowned gym with kind 'claim'", async () => {
    const { facade, claims } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    expect(c.kind).toBe("claim");
    expect(c.status).toBe("pending");
    expect(claims.size).toBe(1);
  });

  it("submits a transfer for an owned gym and notifies the current owner", async () => {
    const { facade, notifications } = makeFakes({ ownerId: "owner9" });
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine now" });
    expect(c.kind).toBe("transfer");
    expect(notifications).toHaveLength(1);
    expect(notifications[0]?.userId).toBe("owner9");
    expect(notifications[0]?.type).toBe("gym_claim");
  });

  it("push fires with type=gym_claim when transfer notifies current owner", async () => {
    const pushes: { userIds: string[]; payload: PushPayload }[] = [];
    const { facade } = makeFakes({ ownerId: "owner9" }, pushes);
    await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    expect(pushes).toHaveLength(1);
    expect(pushes[0].payload.data.type).toBe("gym_claim");
  });

  it("rejects a duplicate pending claim", async () => {
    const { facade } = makeFakes();
    await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    let threw = false;
    try {
      await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "again" });
    } catch (e) {
      threw = e instanceof AppError && e.code === "conflict";
    }
    expect(threw).toBe(true);
  });

  it("rejects claiming a gym you already own", async () => {
    const { facade } = makeFakes({ ownerId: "u1" });
    let threw = false;
    try {
      await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    } catch (e) {
      threw = e instanceof AppError && e.code === "conflict";
    }
    expect(threw).toBe(true);
  });

  it("404s submitting for a missing gym", async () => {
    const { facade } = makeFakes();
    let code = "";
    try {
      await facade.submit("u1", "missing", { relationship: "owner", contact: "x", message: "y" });
    } catch (e) {
      if (e instanceof AppError) code = e.code;
    }
    expect(code).toBe("not_found");
  });

  it("cancels a pending claim", async () => {
    const { facade, claims } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.cancel("u1", "g1");
    expect(claims.get(c.id)?.status).toBe("cancelled");
  });

  it("rejects a claim with a note and notifies the claimant", async () => {
    const { facade, notifications } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.reject("admin1", c.id, "could not verify");
    expect(notifications.some((n) => n.userId === "u1" && n.type === "gym_claim")).toBe(true);
  });

  it("getMyClaimForGym returns the latest claim", async () => {
    const { facade } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    const got = await facade.getMyClaimForGym("u1", "g1");
    expect(got?.id).toBe(c.id);
  });
});

describe("GymClaimFacade — approve", () => {
  it("grants ownership on a claim: sets ownerId, elevates role, owner membership", async () => {
    const { facade, gyms, users } = makeFakes();
    users.set("u1", { id: "u1", email: "u1@gym.com", displayName: "U1", role: "practitioner" } as never);
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(gyms.get("g1")?.ownerId).toBe("u1");
    expect(users.get("u1")?.role).toBe("gym_owner");
  });

  it("creates an owner membership for the claimant", async () => {
    const { facade, memberships } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(memberships.get("g1::u1")?.gymRole).toBe("owner");
    expect(memberships.get("g1::u1")?.verifiedMember).toBe(true);
  });

  it("does not downgrade an admin claimant's account role", async () => {
    const { facade, users } = makeFakes();
    users.set("u1", { id: "u1", email: "a@b.c", displayName: "Ann", role: "admin" } as never);
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(users.get("u1")?.role).toBe("admin");
  });

  it("on transfer, downgrades the previous owner's membership to member", async () => {
    const { facade, memberships, gyms } = makeFakes({ ownerId: "owner9" });
    memberships.set("g1::owner9", {
      id: "m0", gymId: "g1", userId: "owner9", status: "active", verifiedMember: true,
      gymRole: "owner", isHome: true, visibleInRoster: true, joinMethod: "self",
      joinedAt: "2020-01-01T00:00:00.000Z",
    });
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(gyms.get("g1")?.ownerId).toBe("u1");
    expect(memberships.get("g1::owner9")?.gymRole).toBe("member");
    expect(memberships.get("g1::owner9")?.isHome).toBe(true); // isHome untouched
  });

  it("supersedes other pending claims for the same gym", async () => {
    const { facade, claims } = makeFakes();
    const c1 = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    const c2 = await facade.submit("u2", "g1", { relationship: "manager", contact: "u2@gym.com", message: "no mine" });
    await facade.approve("admin1", c1.id);
    expect(claims.get(c1.id)?.status).toBe("approved");
    expect(claims.get(c2.id)?.status).toBe("rejected");
  });

  it("notifies the claimant on approval", async () => {
    const { facade, notifications } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    expect(notifications.some((n) => n.userId === "u1" && (n.data?.["outcome"] === "approved"))).toBe(true);
  });

  it("409s approving a non-pending claim", async () => {
    const { facade } = makeFakes();
    const c = await facade.submit("u1", "g1", { relationship: "owner", contact: "u1@gym.com", message: "mine" });
    await facade.approve("admin1", c.id);
    let code = "";
    try {
      await facade.approve("admin1", c.id);
    } catch (e) {
      if (e instanceof AppError) code = e.code;
    }
    expect(code).toBe("conflict");
  });
});

describe("GymClaimFacade — admin enrichment", () => {
  it("enriches pending claims with gym name/phone/website + claimant email", async () => {
    const { facade, users } = makeFakes({ phone: "555-1212", website: "alliance.com" });
    users.set("u1", { id: "u1", email: "me@gym.com", displayName: "Me", role: "practitioner" } as never);
    await facade.submit("u1", "g1", { relationship: "owner", contact: "me@gym.com", message: "mine" });
    const views = await facade.listForAdminEnriched("pending");
    expect(views).toHaveLength(1);
    expect(views[0]?.gymName).toBe("Alliance");
    expect(views[0]?.gymPhone).toBe("555-1212");
    expect(views[0]?.claimantEmail).toBe("me@gym.com");
  });
});
