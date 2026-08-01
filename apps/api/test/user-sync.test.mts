import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function facade(store: Map<string, User>): UserFacade {
  const repo: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert"> = {
    findById: async (id: string) => store.get(id) ?? null,
    upsertByAuth0Id: async () => { throw new Error("unused"); },
    insert: async (u): Promise<User> => { const full = { ...u } as User; store.set(full.id, full); return full; },
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = store.get(id); if (!cur) return null; const next = { ...cur, ...patch }; store.set(id, next); return next;
    },
  };
  const memberships = { ensureHome: async (): Promise<void> => {} };
  return new UserFacade(repo, memberships);
}

const googleId: AuthIdentity = { userId: "google-oauth2|9", email: "old@x.io", role: "practitioner", viaBypass: false };

describe("syncFromProvider", () => {
  it("social user: applies provider name/email/avatar", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    await f.getOrCreate(googleId);
    const out = await f.syncFromProvider(googleId, { displayName: "Ada Lovelace", email: "ada@x.io", avatarUrl: "https://x/a.png" });
    expect(out.displayName).toBe("Ada Lovelace");
    expect(out.email).toBe("ada@x.io");
    expect(out.avatarUrl).toBe("https://x/a.png");
  });

  it("social user: captures first/last name and derives displayName when name is blank", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    await f.getOrCreate(googleId);
    const out = await f.syncFromProvider(googleId, { firstName: "Grace", lastName: "Hopper" });
    expect(out.firstName).toBe("Grace");
    expect(out.lastName).toBe("Hopper");
    expect(out.displayName).toBe("Grace Hopper");
  });

  it("prefers an explicit provider displayName over the derived first/last", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    await f.getOrCreate(googleId);
    const out = await f.syncFromProvider(googleId, { displayName: "G. Hopper", firstName: "Grace", lastName: "Hopper" });
    expect(out.displayName).toBe("G. Hopper");
    expect(out.firstName).toBe("Grace");
  });

  it("non-social user: fills the placeholder displayName from provider claims", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    const email = "db@x.io";
    const dbId: AuthIdentity = { userId: "auth0|5", email, role: "practitioner", viaBypass: false };
    await f.getOrCreate(dbId);
    const out = await f.syncFromProvider(dbId, { displayName: "Real Name" });
    expect(out.displayName).toBe("Real Name");
  });

  it("non-social user: does not overwrite a user-set displayName", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    const dbId: AuthIdentity = { userId: "auth0|6", email: "db2@x.io", role: "practitioner", viaBypass: false };
    await f.getOrCreate(dbId);
    await f.updateProfile("auth0|6", { displayName: "User Set Name" });
    const out = await f.syncFromProvider(dbId, { displayName: "Should Not Apply" });
    expect(out.displayName).toBe("User Set Name");
  });
});
