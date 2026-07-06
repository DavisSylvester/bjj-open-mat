import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { UpdateUserRequest, AuthSyncRequest } from "@bjj/contract";

describe("contract: birthday + auth sync", () => {
  it("UpdateUserRequest accepts an ISO birthday", () => {
    expect(Value.Check(UpdateUserRequest, { birthday: "1990-01-05" })).toBe(true);
  });
  it("AuthSyncRequest accepts provider identity claims", () => {
    expect(Value.Check(AuthSyncRequest, { displayName: "Ada", email: "a@x.io", avatarUrl: "https://x/i.png" })).toBe(true);
    expect(Value.Check(AuthSyncRequest, {})).toBe(true);
  });
});
