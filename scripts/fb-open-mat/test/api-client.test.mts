import { describe, expect, it } from "bun:test";
import { ApiClient } from "../lib/api-client.mjs";
import type { CreateOpenMatBody } from "../lib/types.mjs";

type FetchArgs = { url: string; init?: RequestInit };

function fakeFetch(responses: Record<string, unknown>): { fn: typeof fetch; calls: FetchArgs[] } {
  const calls: FetchArgs[] = [];
  const fn = (async (url: string, init?: RequestInit) => {
    calls.push({ url, init });
    const key = Object.keys(responses).find((k) => url.includes(k)) ?? '';
    return { ok: true, status: 200, json: async () => responses[key] } as Response;
  }) as unknown as typeof fetch;
  return { fn, calls };
}

describe("ApiClient", () => {
  it("lists gyms near a point", async () => {
    const { fn, calls } = fakeFetch({ "/gyms/nearby": { data: [{ id: "g1", name: "Atos", location: { lat: 1, lng: 2 } }] } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const gyms = await api.gymsNear(32.5, -96.9, 5);
    expect(gyms[0].id).toBe("g1");
    expect(calls[0].url).toContain("lat=32.5");
    expect(calls[0].url).toContain("/gyms/nearby");
  });

  it("lists sessions for a gym", async () => {
    const { fn } = fakeFetch({ "/open-mats": { data: [{ id: "o1", gymId: "g1", dayOfWeek: 0, startTime: "10:00" }] } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const sessions = await api.sessionsForGym("g1");
    expect(sessions[0].startTime).toBe("10:00");
  });

  it("POSTs a session with bearer auth and returns the created record", async () => {
    const { fn, calls } = fakeFetch({ "/open-mats": { data: { id: "new1", verified: false } } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const body: CreateOpenMatBody = { title: "Open Mat", startTime: "10:00", endTime: "12:00", gymId: "g1" };
    const created = await api.createSession(body);
    expect(created.id).toBe("new1");
    expect(created.verified).toBe(false);
    const post = calls.find((c) => c.init?.method === "POST")!;
    expect((post.init!.headers as Record<string, string>)["authorization"]).toBe("Bearer tok");
  });
});
