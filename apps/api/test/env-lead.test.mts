import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

const base = {
  MONGODB_URI: "mongodb://localhost:27017",
  MONGODB_DB: "bjj",
  AUTH_BYPASS_SECRET: "s",
  DEMO_USER_ID: "u",
  DEMO_USER_ROLE: "gym_owner",
  DEMO_USER_EMAIL: "d@e.f",
};

describe("loadEnv lead/SES fields", () => {
  it("defaults website origins and leaves SES undefined when unset", () => {
    const env = loadEnv(base);
    expect(env.sesFrom).toBeUndefined();
    expect(env.websiteOrigins).toContain("http://localhost:4200");
  });

  it("reads SES + admin + origins when set", () => {
    const env = loadEnv({
      ...base,
      SES_FROM: "no-reply@dsylvester.ai",
      ADMIN_EMAIL: "admin@x.com",
      WEBSITE_ORIGIN: "https://bjj-open-mat.dsylvester.ai",
    });
    expect(env.sesFrom).toBe("no-reply@dsylvester.ai");
    expect(env.adminEmail).toBe("admin@x.com");
    expect(env.websiteOrigins).toContain("https://bjj-open-mat.dsylvester.ai");
  });
});
