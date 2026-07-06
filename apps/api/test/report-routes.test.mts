import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_report_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
// No GITHUB_TOKEN -> container wires a null issue service -> Mongo-only, no network.
const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: TEST_DB, AUTH_BYPASS_SECRET: "secret-x", DEMO_USER_ID: "demo", DEMO_USER_ROLE: "practitioner", DEMO_USER_EMAIL: "d@d.dev" });
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>; let base: string;

beforeAll(async () => { await client.connect(); const c = createContainer(client.db(TEST_DB), env); await c.ensureIndexes(); app = buildApp(c).listen(0); base = `http://localhost:${app.server?.port}`; });
afterAll(async () => { app.stop(); await client.db(TEST_DB).dropDatabase(); await client.close(); });

describe("report routes", () => {
  it("rejects a title shorter than 3 chars with 400", async () => {
    const res = await fetch(`${base}/api/v1/reports`, { method: "POST", headers: auth, body: JSON.stringify({ type: "bug", title: "no", description: "This description is long enough." }) });
    expect(res.status).toBe(400);
  });

  it("creates a report (Mongo-only, no GitHub) and returns data.id", async () => {
    const res = await fetch(`${base}/api/v1/reports`, { method: "POST", headers: auth, body: JSON.stringify({ type: "feature", title: "Add dark mode", description: "Please add a dark theme to the app." }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.id).toBeTruthy();
    expect(json.data.status).toBe("open");
    expect(json.data.githubIssueNumber).toBeUndefined();
  });

  it("lists the caller's reports", async () => {
    const res = await fetch(`${base}/api/v1/reports?mine`, { headers: auth });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(Array.isArray(json.data)).toBe(true);
    expect(json.data.length).toBeGreaterThanOrEqual(1);
  });
});
