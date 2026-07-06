import { describe, expect, it } from "bun:test";
import { isSocial } from "../src/auth/is-social.mts";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";

describe("isSocial", () => {
  it("classifies subjects", () => {
    expect(isSocial("google-oauth2|123")).toBe(true);
    expect(isSocial("apple|123")).toBe(true);
    expect(isSocial("auth0|123")).toBe(false); // email-password db
    expect(isSocial("test-user@local.priv")).toBe(false); // dev-bypass
  });
});

describe("updateProfile edit restriction", () => {
  function facadeWith(captured: { patch?: Partial<User> }): UserFacade {
    const base: User = { id: "google-oauth2|1", email: "g@x.io", displayName: "Google Name" };
    const repo: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert"> = {
      findById: async () => base,
      upsertByAuth0Id: async () => base,
      insert: async () => base,
      update: async (_id: string, patch: Partial<User>): Promise<User> => { captured.patch = patch; return { ...base, ...patch }; },
    };
    return new UserFacade(repo);
  }

  it("social user: strips identity/other fields, keeps birthday/belt/homeGym", async () => {
    const cap: { patch?: Partial<User> } = {};
    await facadeWith(cap).updateProfile("google-oauth2|1", {
      displayName: "Hacker", bio: "x", weight: "170", birthday: "1990-01-05", beltRank: "purple", beltStripes: 2, homeGymId: "g-1",
    }, true);
    expect(cap.patch).toEqual({ birthday: "1990-01-05", beltRank: "purple", beltStripes: 2, homeGymId: "g-1" });
  });

  it("non-social user: passes the full patch through", async () => {
    const cap: { patch?: Partial<User> } = {};
    await facadeWith(cap).updateProfile("auth0|1", { displayName: "New Name", birthday: "1991-02-02" }, false);
    expect(cap.patch).toEqual({ displayName: "New Name", birthday: "1991-02-02" });
  });
});
