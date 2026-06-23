import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

describe("loadEnv", () => {
  it("parses a complete env object", () => {
    const env = loadEnv({
      PORT: "3100",
      MONGODB_URI: "mongodb://localhost:27017",
      MONGODB_DB: "bjj_test",
      AUTH0_DOMAIN: "t.us.auth0.com",
      AUTH0_AUDIENCE: "https://api",
      AUTH_BYPASS_SECRET: "secret",
      DEMO_USER_ID: "u-me",
      DEMO_USER_ROLE: "gym_owner",
      DEMO_USER_EMAIL: "demo@test.dev",
    });
    expect(env.port).toBe(3100);
    expect(env.mongoDb).toBe("bjj_test");
    expect(env.demoUser.role).toBe("gym_owner");
  });

  it("throws when MONGODB_URI is missing", () => {
    expect(() => loadEnv({ MONGODB_DB: "x" })).toThrow();
  });
});
