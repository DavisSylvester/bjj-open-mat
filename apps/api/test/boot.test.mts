import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_boot";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });

const env = {
  ...loadEnv({
    MONGODB_URI: uri,
    MONGODB_DB: TEST_DB,
    AUTH_BYPASS_SECRET: "TopFlightApiSecurity2026+",
    DEMO_USER_ID: "u-me",
    DEMO_USER_ROLE: "gym_owner",
    DEMO_USER_EMAIL: "demo@test.dev",
  }),
};

let app: ReturnType<typeof buildApp>;
let base: string;
const auth = { Authorization: "Bearer TopFlightApiSecurity2026+" };

beforeAll(async () => {
  await client.connect();
  const container = createContainer(client.db(TEST_DB), env);
  await container.ensureIndexes();
  app = buildApp(container).listen(0);
  base = `http://localhost:${app.server?.port}`;
});

afterAll(async () => {
  app.stop();
  await client.db(TEST_DB).dropDatabase();
  await client.close();
});

describe("API boot (MongoDB-backed)", () => {
  it("serves health, ready, openapi", async () => {
    expect((await fetch(`${base}/health`)).status).toBe(200);
    const ready = await fetch(`${base}/ready`);
    expect(ready.status).toBe(200);
    expect((await ready.json()).status).toBe("ready");
    const openapi = await fetch(`${base}/openapi.json`);
    expect((await openapi.json()).openapi).toBe("3.1.0");
  });

  it("requires auth on protected routes", async () => {
    expect((await fetch(`${base}/api/v1/users/me`)).status).toBe(401);
  });

  it("runs a full owner flow with the bypass token", async () => {
    // get-or-create the demo user
    const me = await fetch(`${base}/api/v1/auth/me`, { headers: auth });
    expect(me.status).toBe(200);

    // create gym
    const gymRes = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Atos", address: "9587 Distribution Ave", location: { lat: 32.901, lng: -117.213 } }),
    });
    expect(gymRes.status).toBe(200);
    const gymId = (await gymRes.json()).data.id;

    // create open mat
    const omRes = await fetch(`${base}/api/v1/open-mats`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ gymId, title: "Fri", startTime: "19:00", endTime: "21:00", dayOfWeek: 5, giType: "gi" }),
    });
    expect(omRes.status).toBe(200);
    const omId = (await omRes.json()).data.id;

    // list finds it
    const listRes = await fetch(`${base}/api/v1/open-mats?dayOfWeek=5`);
    expect((await listRes.json()).meta.total).toBeGreaterThan(0);

    // rsvp
    const rsvp = await fetch(`${base}/api/v1/open-mats/${omId}/rsvp`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ sessionDate: "2026-06-20" }),
    });
    expect((await rsvp.json()).data.attending).toBe(true);

    // nearby gyms
    const near = await fetch(`${base}/api/v1/gyms/nearby?lat=32.9&lng=-117.21&radiusKm=25`);
    expect((await near.json()).data.length).toBeGreaterThan(0);
  });

  it("derives role from the DB and supports role update", async () => {
    // demo user starts as gym_owner (env DEMO_USER_ROLE); demote then verify owner route blocked
    const demote = await fetch(`${base}/api/v1/users/me`, {
      method: "PUT",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "practitioner" }),
    });
    expect(demote.status).toBe(200);
    expect((await demote.json()).data.role).toBe("practitioner");

    const blocked = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "X", address: "Y" }),
    });
    expect(blocked.status).toBe(403);

    // promote back to gym_owner
    const promote = await fetch(`${base}/api/v1/users/me`, {
      method: "PUT",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "gym_owner" }),
    });
    expect((await promote.json()).data.role).toBe("gym_owner");
  });

  it("returns 404 for a missing open mat", async () => {
    expect((await fetch(`${base}/api/v1/open-mats/does-not-exist`)).status).toBe(404);
  });

  it("returns 400 with error envelope on bad body", async () => {
    const res = await fetch(`${base}/api/v1/gyms`, {
      method: "POST",
      headers: { ...auth, "Content-Type": "application/json" },
      body: JSON.stringify({ name: "" }),
    });
    expect(res.status).toBe(400);
    expect((await res.json()).error.code).toBe("bad_request");
  });
});
