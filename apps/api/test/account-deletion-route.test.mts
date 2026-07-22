import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_account_deletion_route";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({
  MONGODB_URI: uri,
  MONGODB_DB: TEST_DB,
  AUTH_BYPASS_SECRET: "secret-x",
  DEMO_USER_ID: "demo-delete-me",
  DEMO_USER_ROLE: "practitioner",
  DEMO_USER_EMAIL: "demo-delete@d.dev",
});
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>;
let base: string;

beforeAll(async () => {
  await client.connect();
  const c = createContainer(client.db(TEST_DB), env);
  await c.ensureIndexes();
  app = buildApp(c).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("DELETE /api/v1/users/me", () => {
  it("requires authentication", async () => {
    const res = await fetch(`${base}/api/v1/users/me`, { method: "DELETE" });
    expect(res.status).toBe(401);
  });

  it("deletes the authenticated user's account", async () => {
    await fetch(`${base}/api/v1/auth/me`, { headers: auth });
    expect((await (await fetch(`${base}/api/v1/users/me`, { headers: auth })).json()).data.id).toBe("demo-delete-me");

    const del = await fetch(`${base}/api/v1/users/me`, { method: "DELETE", headers: auth });
    expect(del.status).toBe(200);

    const after = await fetch(`${base}/api/v1/users/me`, { headers: auth });
    expect(after.status).toBe(404);
  });
});
