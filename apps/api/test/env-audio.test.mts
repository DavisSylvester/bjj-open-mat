import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

const base = {
  MONGODB_URI: "mongodb://localhost:27017", MONGODB_DB: "x",
  AUTH_BYPASS_SECRET: "s", DEMO_USER_ID: "d", DEMO_USER_ROLE: "practitioner", DEMO_USER_EMAIL: "d@d.dev",
};

describe("audio/openai env", () => {
  it("defaults audio settings when unset", () => {
    const env = loadEnv(base);
    expect(env.openaiApiKey).toBeUndefined();
    expect(env.audioBucket).toBeUndefined();
    expect(env.audioRegion).toBe("us-east-1");
  });
  it("reads audio settings when set", () => {
    const env = loadEnv({ ...base, OPENAI_API_KEY: "sk-1", AUDIO_BUCKET: "b", AUDIO_REGION: "us-west-2" });
    expect(env.openaiApiKey).toBe("sk-1");
    expect(env.audioBucket).toBe("b");
    expect(env.audioRegion).toBe("us-west-2");
  });
});
