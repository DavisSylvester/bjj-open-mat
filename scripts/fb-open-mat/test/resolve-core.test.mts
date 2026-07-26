import { describe, expect, it } from "bun:test";
import { resolveCandidates, type ResolveApi } from "../lib/resolve-core.mjs";
import type { Candidate } from "../lib/types.mjs";

const base: Candidate = {
  sourceUrl: "u", author: "a", gymName: "Atos Jiu Jitsu", city: "Frisco", state: "TX", postalCode: "75034",
  dayOfWeek: 0, isRecurring: true, startTime: "10:00", endTime: "12:00",
  giType: "both", skillLevel: "all", feeCents: 0, confidence: 0.9, rawSnippet: "",
};

function api(over: Partial<ResolveApi>): ResolveApi {
  return {
    geocodeZip: async () => ({ lat: 33.15, lng: -96.82 }),
    gymsNear: async () => [{ id: "g1", name: "Atos Jiu Jitsu", location: { lat: 33.15, lng: -96.82 } }],
    sessionsForGym: async () => [],
    ...over,
  };
}

describe("resolveCandidates", () => {
  it("attaches gymId when a gym matches and keeps the new session", async () => {
    const out = await resolveCandidates([base], api({}));
    expect(out).toHaveLength(1);
    expect(out[0].gymId).toBe("g1");
    expect(out[0].newGym).toBeUndefined();
  });

  it("flags newGym when no gym matches", async () => {
    const out = await resolveCandidates([base], api({ gymsNear: async () => [] }));
    expect(out[0].gymId).toBeUndefined();
    expect(out[0].newGym?.name).toBe("Atos Jiu Jitsu");
  });

  it("drops a session that already exists at the gym (same day+start)", async () => {
    const out = await resolveCandidates([base], api({
      sessionsForGym: async () => [{ id: "o1", gymId: "g1", dayOfWeek: 0, startTime: "10:00" }],
    }));
    expect(out).toHaveLength(0);
  });

  it("skips candidates that fail the US filter", async () => {
    const nonUs: Candidate = { ...base, state: "ON", postalCode: undefined };
    const out = await resolveCandidates([nonUs], api({}));
    expect(out).toHaveLength(0);
  });
});
