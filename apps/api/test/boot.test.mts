import { describe, expect, it } from "bun:test";
import { buildApp } from "../src/app.mts";

// Socket-bound boot test: proves the app actually starts and serves its
// liveness, readiness, OpenAPI, and core routes on a real port.
describe("API boot", () => {
  it("serves health, ready, openapi, and open-mats over a real socket", async () => {
    const app = buildApp().listen(0);
    const port = app.server?.port;
    expect(port).toBeDefined();
    const base = `http://localhost:${port}`;

    try {
      const health = await fetch(`${base}/health`);
      expect(health.status).toBe(200);
      expect((await health.json()).status).toBe("ok");

      const ready = await fetch(`${base}/ready`);
      expect(ready.status).toBe(200);

      const openapi = await fetch(`${base}/openapi.json`);
      expect(openapi.status).toBe(200);
      expect((await openapi.json()).openapi).toBe("3.1.0");

      const list = await fetch(`${base}/api/v1/open-mats?dayOfWeek=5`);
      expect(list.status).toBe(200);
      const listBody = await list.json();
      expect(listBody.count).toBeGreaterThan(0);

      const detail = await fetch(`${base}/api/v1/open-mats/om-atos-fri`);
      expect(detail.status).toBe(200);
      expect((await detail.json()).address).toBeDefined();

      const missing = await fetch(`${base}/api/v1/open-mats/does-not-exist`);
      expect(missing.status).toBe(404);

      const rsvp = await fetch(`${base}/api/v1/open-mats/om-10p-sat/rsvp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionDate: "2026-06-20" }),
      });
      expect(rsvp.status).toBe(200);
      expect((await rsvp.json()).attending).toBe(true);
    } finally {
      app.stop();
    }
  });
});
