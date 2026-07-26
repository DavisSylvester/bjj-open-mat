export interface GymRef {
  readonly id: string;
  readonly name: string;
  readonly location?: { lat: number; lng: number };
}

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const toRad = (d: number): number => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function tokens(name: string): Set<string> {
  const stop = new Set(['jiu', 'jitsu', 'bjj', 'academy', 'brazilian', 'the', 'and', 'hq', 'mma']);
  return new Set(
    name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((t) => t && !stop.has(t)),
  );
}

// Jaccard overlap of significant tokens (generic BJJ words removed).
export function nameOverlap(a: string, b: string): number {
  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter += 1;
  const union = new Set([...ta, ...tb]).size;
  return inter / union;
}

export interface MatchInput {
  readonly gymName: string;
  readonly lat: number;
  readonly lng: number;
}

// Returns the best gym with name overlap >= 0.5 AND within 3 km, else null.
export function bestGymMatch(input: MatchInput, gyms: readonly GymRef[]): GymRef | null {
  let best: GymRef | null = null;
  let bestScore = 0;
  for (const g of gyms) {
    const overlap = nameOverlap(input.gymName, g.name);
    if (overlap < 0.5) continue;
    if (g.location) {
      const dist = haversineKm(input.lat, input.lng, g.location.lat, g.location.lng);
      if (dist > 3) continue;
    }
    if (overlap > bestScore) {
      bestScore = overlap;
      best = g;
    }
  }
  return best;
}
