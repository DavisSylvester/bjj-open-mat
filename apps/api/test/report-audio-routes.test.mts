import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_report_audio_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: TEST_DB, AUTH_BYPASS_SECRET: "secret-x",
  DEMO_USER_ID: "demo", DEMO_USER_ROLE: "practitioner", DEMO_USER_EMAIL: "d@d.dev" });
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>; let base: string;

beforeAll(async () => {
  await client.connect();
  const c = createContainer(client.db(TEST_DB), env);
  await c.ensureIndexes();
  app = buildApp(c).listen(0);
  base = `http://localhost:${app.server?.port}`;
});
afterAll(async () => { app.stop(); await client.db(TEST_DB).dropDatabase(); await client.close(); });

describe("report audio routes", () => {
  it("persists audioKeys on create", async () => {
    const res = await fetch(`${base}/api/v1/reports`, { method: "POST", headers: auth,
      body: JSON.stringify({ type: "bug", title: "Map crash", description: "Crashes when I open the map.", audioKeys: ["reports/audio/demo/a.m4a"] }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.audioKeys).toEqual(["reports/audio/demo/a.m4a"]);
  });

  it("audio-upload-url returns 503 when AUDIO_BUCKET is unset", async () => {
    const res = await fetch(`${base}/api/v1/reports/audio-upload-url`, { method: "POST", headers: auth,
      body: JSON.stringify({ contentType: "audio/mp4" }) });
    // Unconfigured audio storage -> AppError service_unavailable
    expect(res.status).toBe(503);
  });
});
