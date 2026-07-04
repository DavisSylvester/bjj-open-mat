import { describe, expect, it } from "bun:test";
import { JwtVerifier } from "../src/auth/jwt-verifier.mts";

const verifier = new JwtVerifier({
  bypassSecret: "SECRET",
  demoUser: { id: "u-me", role: "gym_owner", email: "demo@test.dev" },
  auth0Domain: undefined,
  auth0Audience: undefined,
});

describe("JwtVerifier", () => {
  it("resolves the demo identity for the bypass secret", async () => {
    const id = await verifier.verify("SECRET");
    expect(id).toEqual({ userId: "u-me", role: "gym_owner", email: "demo@test.dev", viaBypass: true });
  });

  it("returns null for a missing token", async () => {
    expect(await verifier.verify(undefined)).toBeNull();
  });

  it("throws for a malformed non-bypass token when Auth0 is configured-less", async () => {
    await expect(verifier.verify("not-a-jwt")).rejects.toBeDefined();
  });
});
