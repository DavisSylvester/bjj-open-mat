/**
 * Phase 4 — Merge, dedupe, clean, brand-tag and reverse-geocode.
 *
 * Master set = Google Places (has stable place_id + clean data). OSM and franchise
 * records are merged in: matched to a Places record by proximity + fuzzy name
 * (enriching brand/website/phone), or appended if unique. Non-BJJ false positives
 * are dropped (kept in a review file). Records missing address components are
 * reverse-geocoded from their reliable coordinates.
 *
 * Run: bun run scripts/gym-research/phase4-merge.mts
 */
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const KEY = ((): string => {
  const env = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
  return (env.match(/^MAPS_API_KEY=(.*)$/m)?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
})();

interface Geo { type: 'Point'; coordinates: [number, number]; }
interface Merged {
  id: string;
  name: string;
  address: string;
  city: string | null;
  state: string | null;
  postalCode: string | null;
  country: null;
  geo: Geo;
  googlePlaceId: string | null;
  website: string | null;
  phone: string | null;
  brand: string | null;
  rating: number | null;
  ratingCount: number | null;
  sources: string[];
  distanceMi: number;
}

const read = <T>(f: string): T[] => {
  try { return JSON.parse(readFileSync(join(DATA, f), 'utf8')) as T[]; } catch { return []; }
};

const lat = (g: Geo): number => g.coordinates[1];
const lng = (g: Geo): number => g.coordinates[0];
const haversineM = (aLat: number, aLng: number, bLat: number, bLng: number): number => {
  const R = 6371000;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s = Math.sin(dLat / 2) ** 2 + Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

const slug = (s: string): string => s.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60);
const norm = (s: string): Set<string> =>
  new Set(
    s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ')
      .split(/\s+/)
      .filter((w) => w && !['jiu', 'jitsu', 'jiujitsu', 'bjj', 'academy', 'brazilian', 'the', 'martial', 'arts', 'mma', 'gym', 'and', 'of', 'llc'].includes(w)),
  );
const nameOverlap = (a: string, b: string): number => {
  const A = norm(a), B = norm(b);
  if (!A.size || !B.size) return 0;
  let hit = 0;
  for (const w of A) if (B.has(w)) hit++;
  return hit / Math.min(A.size, B.size);
};

// Non-BJJ arts: drop only when the name shows NO BJJ signal.
const NON_BJJ = /tae ?kwon|taekwondo|\bkarate\b|krav\s*maga|\bjudo\b|aikido|kung ?fu|\bboxing\b|kickbox|capoeira|sidekick|\bdance\b|ballet|\byoga\b|crossfit|zumba|muay thai only/i;
const BJJ_SIGNAL = /jiu|jitsu|\bbjj\b|grappl|gracie|10th planet|checkmat|atos|carlson|renzo|rilion|machado|soul fighters|caio terra|marcelo|nova uniao|alliance|zenith|brasa|gf team/i;

const BRANDS: ReadonlyArray<[RegExp, string]> = [
  [/gracie\s*barra/i, 'Gracie Barra'],
  [/10th\s*planet/i, '10th Planet'],
  [/\balliance\b/i, 'Alliance'],
  [/\batos\b/i, 'Atos'],
  [/checkmat/i, 'Checkmat'],
  [/carlson\s*gracie/i, 'Carlson Gracie'],
  [/renzo\s*gracie/i, 'Renzo Gracie'],
  [/rilion\s*gracie/i, 'Rilion Gracie'],
  [/gracie\s*humaita/i, 'Gracie Humaita'],
  [/relson\s*gracie/i, 'Relson Gracie'],
  [/(machado)/i, 'Machado'],
  [/soul\s*fighters/i, 'Soul Fighters'],
  [/caio\s*terra/i, 'Caio Terra'],
  [/zenith/i, 'Zenith'],
  [/brasa/i, 'Brasa'],
  [/gf\s*team/i, 'GF Team'],
  [/gracie/i, 'Gracie (affiliate)'],
];
const detectBrand = (name: string): string | null => {
  for (const [re, b] of BRANDS) if (re.test(name)) return b;
  return null;
};

interface PlaceRec { name: string; address: string; city: string | null; state: string | null; postalCode: string | null; geo: Geo; googlePlaceId: string; website?: string | null; phone?: string | null; rating: number | null; ratingCount: number | null; distanceMi: number; }
interface SrcRec { name: string; address: string; city: string | null; state: string | null; postalCode: string | null; geo: Geo; website?: string | null; phone?: string | null; distanceMi?: number; }

const reverseGeocode = async (g: Geo): Promise<{ address: string; city: string | null; state: string | null; zip: string | null } | null> => {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat(g)},${lng(g)}&key=${KEY}`;
  const res = await fetch(url);
  const j = (await res.json()) as { status: string; results: { formatted_address: string; address_components: { long_name: string; short_name: string; types: string[] }[] }[] };
  const r = j.results?.[0];
  if (!r) return null;
  const c = r.address_components;
  const get = (t: string, short = false): string | null => {
    const m = c.find((x) => x.types.includes(t));
    return m ? (short ? m.short_name : m.long_name) : null;
  };
  const num = get('street_number'); const route = get('route');
  return {
    address: [num, route].filter(Boolean).join(' '),
    city: get('locality') ?? get('sublocality') ?? get('administrative_area_level_2'),
    state: get('administrative_area_level_1', true),
    zip: get('postal_code'),
  };
};

const main = async (): Promise<void> => {
  mkdirSync(DATA, { recursive: true });
  const places = [...read<PlaceRec>('phase3-places.json'), ...read<PlaceRec>('phase3b-places.json')];
  const gb = read<SrcRec>('phase2-franchise.json');
  const osm = read<SrcRec>('phase1-osm.json');

  const master: Merged[] = [];
  const dropped: { name: string; reason: string; city: string | null }[] = [];

  // seed from Places (drop obvious non-BJJ)
  const seenPlace = new Set<string>();
  for (const p of places) {
    if (seenPlace.has(p.googlePlaceId)) continue;
    seenPlace.add(p.googlePlaceId);
    if (NON_BJJ.test(p.name) && !BJJ_SIGNAL.test(p.name)) {
      dropped.push({ name: p.name, reason: 'non-bjj', city: p.city });
      continue;
    }
    master.push({
      id: `gpl-${p.googlePlaceId}`,
      name: p.name, address: p.address, city: p.city, state: p.state, postalCode: p.postalCode, country: null,
      geo: p.geo, googlePlaceId: p.googlePlaceId, website: p.website ?? null, phone: p.phone ?? null,
      brand: detectBrand(p.name), rating: p.rating, ratingCount: p.ratingCount, sources: ['google-places'], distanceMi: p.distanceMi,
    });
  }

  const findMatch = (rec: SrcRec): Merged | null => {
    let best: Merged | null = null;
    let bestD = Infinity;
    for (const m of master) {
      const d = haversineM(lat(rec.geo), lng(rec.geo), lat(m.geo), lng(m.geo));
      if (d < bestD) { bestD = d; best = m; }
    }
    if (best && (bestD < 120 || (bestD < 300 && nameOverlap(rec.name, best.name) >= 0.34))) return best;
    return null;
  };

  const mergeIn = (rec: SrcRec, source: string, brand: string | null): void => {
    const m = findMatch(rec);
    if (m) {
      if (!m.sources.includes(source)) m.sources.push(source);
      if (brand && !m.brand) m.brand = brand;
      m.website ??= rec.website ?? null;
      m.phone ??= rec.phone ?? null;
      if (!m.address && rec.address) { m.address = rec.address; m.city ??= rec.city; m.state ??= rec.state; m.postalCode ??= rec.postalCode; }
      return;
    }
    if (NON_BJJ.test(rec.name) && !BJJ_SIGNAL.test(rec.name)) { dropped.push({ name: rec.name, reason: 'non-bjj', city: rec.city }); return; }
    master.push({
      id: `${source}-${slug(rec.name)}`,
      name: rec.name, address: rec.address, city: rec.city, state: rec.state, postalCode: rec.postalCode, country: null,
      geo: rec.geo, googlePlaceId: null, website: rec.website ?? null, phone: rec.phone ?? null,
      brand: brand ?? detectBrand(rec.name), rating: null, ratingCount: null, sources: [source], distanceMi: rec.distanceMi ?? 0,
    });
  };

  for (const r of gb) mergeIn(r, 'gracie-barra', 'Gracie Barra');
  for (const r of osm) mergeIn(r, 'osm', null);

  // reverse-geocode records missing address/state/zip
  let rg = 0;
  for (const m of master) {
    if (m.address && m.state && m.postalCode) continue;
    if (rg >= 80) break;
    try {
      const info = await reverseGeocode(m.geo);
      rg++;
      if (info) {
        if (!m.address) m.address = info.address;
        m.city ??= info.city;
        m.state ??= info.state;
        m.postalCode ??= info.zip;
      }
    } catch { /* leave as-is */ }
  }

  master.sort((a, b) => a.distanceMi - b.distanceMi);
  writeFileSync(join(DATA, 'phase4-merged.json'), JSON.stringify(master, null, 2));
  writeFileSync(join(DATA, 'phase4-dropped.json'), JSON.stringify(dropped, null, 2));

  const branded = master.filter((m) => m.brand).length;
  const multi = master.filter((m) => m.sources.length > 1).length;
  const states: Record<string, number> = {};
  for (const m of master) states[m.state ?? '??'] = (states[m.state ?? '??'] ?? 0) + 1;
   
  console.log(`Merged gyms: ${master.length}`);
   
  console.log(`  branded/affiliated: ${branded} | multi-source: ${multi} | reverse-geocoded: ${rg}`);
   
  console.log(`  dropped non-BJJ: ${dropped.length}`);
   
  console.log(`  states: ${JSON.stringify(states)}`);
   
  console.log(`  missing address/state/zip: ${master.filter((m) => !m.address || !m.state || !m.postalCode).length}`);
   
  console.log(`Wrote phase4-merged.json (+ phase4-dropped.json for review)`);
};

await main();
