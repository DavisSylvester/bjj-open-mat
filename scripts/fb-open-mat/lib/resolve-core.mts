import type { Candidate, CreateOpenMatBody } from './types.mjs';
import type { GymRef, MatchInput } from './geo-match.mjs';
import { bestGymMatch } from './geo-match.mjs';
import { isUsCandidate } from './us-filter.mjs';
import type { SessionRef } from './api-client.mjs';

export interface ResolveApi {
  geocodeZip(zip: string): Promise<{ lat: number; lng: number } | null>;
  gymsNear(lat: number, lng: number, radiusKm: number): Promise<GymRef[]>;
  sessionsForGym(gymId: string): Promise<SessionRef[]>;
}

// A candidate ready to POST: title + schedule + either gymId or newGym.
export type ResolvedSession = CreateOpenMatBody & { sourceUrl: string; gymNameForLog: string };

function sessionExists(candidate: Candidate, existing: SessionRef[]): boolean {
  return existing.some((s) =>
    s.startTime === candidate.startTime &&
    (candidate.specificDate ? s.specificDate === candidate.specificDate : s.dayOfWeek === candidate.dayOfWeek),
  );
}

export async function resolveCandidates(candidates: Candidate[], api: ResolveApi): Promise<ResolvedSession[]> {
  const out: ResolvedSession[] = [];
  for (const c of candidates) {
    if (!isUsCandidate(c)) continue;

    const geo = c.postalCode ? await api.geocodeZip(c.postalCode) : null;
    let gymId: string | undefined;

    if (geo) {
      const gyms = await api.gymsNear(geo.lat, geo.lng, 5);
      const match: MatchInput = { gymName: c.gymName, lat: geo.lat, lng: geo.lng };
      const found = bestGymMatch(match, gyms);
      if (found) {
        const existing = await api.sessionsForGym(found.id);
        if (sessionExists(c, existing)) continue; // duplicate — drop
        gymId = found.id;
      }
    }

    const common = {
      title: `${c.gymName} Open Mat`,
      startTime: c.startTime, endTime: c.endTime,
      dayOfWeek: c.dayOfWeek, specificDate: c.specificDate, isRecurring: c.isRecurring,
      giType: c.giType, skillLevel: c.skillLevel, feeCents: c.feeCents,
      sourceUrl: c.sourceUrl, gymNameForLog: c.gymName,
    };
    out.push(gymId
      ? { ...common, gymId }
      : { ...common, newGym: { name: c.gymName, address: c.address ?? c.city ?? c.gymName, city: c.city, state: c.state, postalCode: c.postalCode, country: 'US' } });
  }
  return out;
}
