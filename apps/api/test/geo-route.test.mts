import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { geoRoutes } from "../src/routes/geo.routes.mts";
import { ZipcodesGeocoder } from "../src/services/geocoder.mts";

describe("GET /api/v1/geo/reverse", () => {
  const app = new Elysia().use(
    geoRoutes({ geocoder: new ZipcodesGeocoder() } as never),
  );

  it("returns a city/state label for coordinates", async () => {
    const res = await app.handle(
      new Request("http://localhost/api/v1/geo/reverse?lat=30.2672&lng=-97.7431"),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { data: { state: string; label: string } };
    expect(body.data.state).toBe("TX");
    expect(body.data.label).toContain("TX");
  });
});
