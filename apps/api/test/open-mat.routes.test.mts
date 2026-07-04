import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { loadEnv } from "../src/config/env.mts";
import { createContainer } from "../src/container.mts";
import { buildApp } from "../src/app.mts";

const TEST_DB = "bjj_test_om_routes";
const uri = process.env["MONGODB_URI"] ?? "mongodb://localhost:27017";
const client = new MongoClient(uri, { timeoutMS: 5000 });
const env = loadEnv({ MONGODB_URI: uri, MONGODB_DB: TEST_DB, AUTH_BYPASS_SECRET: "secret-x", DEMO_USER_ID: "demo", DEMO_USER_ROLE: "gym_owner", DEMO_USER_EMAIL: "d@d.dev" });
const auth = { "Content-Type": "application/json", Authorization: "Bearer secret-x" };
let app: ReturnType<typeof buildApp>; let base: string;

beforeAll(async () => { await client.connect(); const c = createContainer(client.db(TEST_DB), env); await c.ensureIndexes(); app = buildApp(c).listen(0); base = `http://localhost:${app.server?.port}`; });
afterAll(async () => { app.stop(); await client.db(TEST_DB).dropDatabase(); await client.close(); });

describe("open-mat routes: community submissions", () => {
  it("any authed user creates via newGym -> live + unverified; non-owner cannot verify/hide", async () => {
    const res = await fetch(`${base}/api/v1/open-mats`, { method: "POST", headers: auth, body: JSON.stringify({ newGym: { name: "Routes Gym", address: "1 A St" }, title: "OM", startTime: "19:00", endTime: "21:00" }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.status).toBe("live");
    expect(json.data.verified).toBe(false);
    const id = json.data.id;

    const listed = await (await fetch(`${base}/api/v1/open-mats`, { headers: auth })).json();
    expect(listed.data.some((m: { id: string }) => m.id === id)).toBe(true);

    expect((await fetch(`${base}/api/v1/open-mats/${id}/verify`, { method: "POST", headers: auth })).status).toBe(403);
    expect((await fetch(`${base}/api/v1/open-mats/${id}/hide`, { method: "POST", headers: auth })).status).toBe(403);
  });
});

describe("open-mat routes: check-in", () => {
  it("check-in stores GPS, flag, and gym snapshot", async () => {
    const created = await (await fetch(`${base}/api/v1/open-mats`, { method: "POST", headers: auth, body: JSON.stringify({ newGym: { name: "CheckinGym", address: "1 A St" }, title: "OM", startTime: "19:00", endTime: "21:00" }) })).json();
    const id = created.data.id;
    const res = await fetch(`${base}/api/v1/open-mats/${id}/checkin`, { method: "POST", headers: auth, body: JSON.stringify({ sessionDate: "2026-06-22", latitude: 32.9, longitude: -117.2, note: "rolled", rounds: 4, intensity: 3 }) });
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.data.gymName).toBe("CheckinGym");
    expect(json.data.openMatTitle).toBe("OM");
    expect(json.data.note).toBe("rolled");
    expect(json.data.rounds).toBe(4);
    expect(json.data.locationStatus).toBe("no_location"); // newGym has no coordinates
    expect(json.data.latitude).toBe(32.9);
  });
});

describe("open-mat routes: search filters", () => {
  it("search filters by zip (geocoded) and free", async () => {
    const created = await (await fetch(`${base}/api/v1/open-mats`, {
      method: "POST", headers: auth,
      body: JSON.stringify({ newGym: { name: "NT BJJ", address: "1 Main St", postalCode: "75495" }, title: "Sat Rolls", startTime: "11:00", endTime: "13:00", dayOfWeek: 6, giType: "nogi", feeCents: 0 }),
    })).json();
    expect(created.data.id).toBeTruthy();
    expect(created.data.latitude).toBeGreaterThan(30); // 75495 geocoded to TX coords
    const res = await fetch(`${base}/api/v1/open-mats?zip=75495&radiusKm=25&free=true`, { headers: auth });
    const json = await res.json();
    expect(res.status).toBe(200);
    const ids = (json.data as { id: string }[]).map((o) => o.id);
    expect(ids).toContain(created.data.id);
  });

  it("search excludes far results by radius", async () => {
    const res = await fetch(`${base}/api/v1/open-mats?lat=40.7&lng=-74.0&radiusKm=5`, { headers: auth });
    const json = await res.json();
    expect((json.data as { gymName?: string }[]).some((o) => o.gymName === "NT BJJ")).toBe(false);
  });

  it("giType=both returns only sessions marked both", async () => {
    const both = await (await fetch(`${base}/api/v1/open-mats`, {
      method: "POST", headers: auth,
      body: JSON.stringify({ newGym: { name: "Both Gym", address: "1 B St" }, title: "Both Session", startTime: "10:00", endTime: "12:00", giType: "both" }),
    })).json();
    const giOnly = await (await fetch(`${base}/api/v1/open-mats`, {
      method: "POST", headers: auth,
      body: JSON.stringify({ newGym: { name: "Gi Gym", address: "1 G St" }, title: "Gi Session", startTime: "10:00", endTime: "12:00", giType: "gi" }),
    })).json();
    expect(both.data.id).toBeTruthy();
    expect(giOnly.data.id).toBeTruthy();

    const res = await fetch(`${base}/api/v1/open-mats?giType=both`, { headers: auth });
    const json = await res.json();
    expect(res.status).toBe(200);
    const items = json.data as { id: string; giType: string }[];
    expect(items.every((o) => o.giType === "both")).toBe(true);
    expect(items.some((o) => o.id === both.data.id)).toBe(true);
    expect(items.some((o) => o.id === giOnly.data.id)).toBe(false);
  });
});

describe("open-mat routes: security - status filter", () => {
  it("non-admin passing ?status=hidden gets the same live results as the default call", async () => {
    // Create a live session as the demo user (gym_owner, non-admin)
    const createRes = await fetch(`${base}/api/v1/open-mats`, {
      method: "POST",
      headers: auth,
      body: JSON.stringify({ newGym: { name: "Security Test Gym", address: "2 B St" }, title: "Security OM", startTime: "10:00", endTime: "12:00" }),
    });
    expect(createRes.status).toBe(200);
    const created = (await createRes.json()).data as { id: string };

    // Default list (no status param) - should include our live session
    const defaultRes = await fetch(`${base}/api/v1/open-mats`, { headers: auth });
    const defaultJson = await defaultRes.json();
    expect(defaultJson.data.some((m: { id: string }) => m.id === created.id)).toBe(true);

    // Non-admin passes ?status=hidden — should be forced to live, so result equals default
    const hiddenRes = await fetch(`${base}/api/v1/open-mats?status=hidden`, { headers: auth });
    const hiddenJson = await hiddenRes.json();

    // The live session must still appear (status=hidden was ignored, forced to live)
    expect(hiddenJson.data.some((m: { id: string }) => m.id === created.id)).toBe(true);
    // Both calls should return the same count (no hidden sessions leaked in)
    expect(hiddenJson.data.length).toBe(defaultJson.data.length);
  });
});
