/**
 * Build the FULL open-mat set (all discovered gyms) as OpenMat docs, guaranteeing
 * geo on every doc. Matched-to-seed gyms are anchored to the seed (real gymId +
 * authoritative geo/address/rating); unmatched gyms are kept standalone with their
 * scraped coords, geocoded via OSM Nominatim (not Google) when missing.
 *
 * Deterministic _id / gymId => idempotent seeding. Output: data/openmats-full.json
 * Run: bun run scripts/gym-research/openmats-full.mts
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const read = <T>(f: string): T => JSON.parse(readFileSync(join(DATA, f), 'utf8')) as T;

interface Geo { type: 'Point'; coordinates: [number, number] }
interface SeedGym { _id: string; name: string; address?: string; city?: string; state?: string; postalCode?: string; website?: string; rating?: number; geo: Geo }
interface DecodoGym { name: string; website: string; city: string; openMat: { hosts: boolean } }
interface OmDoc { gymName: string; dayOfWeek: number | null; startTime: string | null; endTime: string | null; giType: string; title: string; description: string; address?: string | null; city?: string | null; state?: string; postalCode?: string | null; latitude?: number | null; longitude?: number | null; geo?: Geo | null; [k: string]: unknown }

const seed = read<SeedGym[]>('gyms.seed.json');
const decodo = read<DecodoGym[]>('tx-bjj-decodo.json').filter((g) => g.openMat.hosts);
const openmats = read<OmDoc[]>('tx-openmats.json');

const cleanName = (n: string): string => n.replace(/&#8211;|&#8212;/g, '-').replace(/&amp;/g, '&').split(/\s[-–—|]\s/)[0]?.trim() || n;
const slug = (n: string): string => cleanName(n).toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48);
const reg = (h: string): string => { try { return new URL(h.startsWith('http') ? h : 'http://' + h).hostname.replace(/^www\./, '').split('.').slice(-2).join('.'); } catch { return ''; } };
const norm = (n: string): Set<string> => new Set(n.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').split(/\s+/).filter((w) => w && !['jiu', 'jitsu', 'bjj', 'academy', 'brazilian', 'the', 'martial', 'arts', 'mma', 'gym'].includes(w)));
const overlap = (a: string, b: string): number => { const A = norm(a), B = norm(b); if (!A.size || !B.size) return 0; let h = 0; for (const w of A) if (B.has(w)) h++; return h / Math.min(A.size, B.size); };
const km = (aLat: number, aLng: number, bLat: number, bLng: number): number => { const R = 6371, r = (x: number): number => (x * Math.PI) / 180; const s = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(s)); };
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

const geocodeOne = async (q: string): Promise<Geo | null> => {
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=us&q=${encodeURIComponent(q)}`, { headers: { 'User-Agent': 'bjj-open-mat-research/1.0 (dsylvesteriii@gmail.com)' } });
    const j = (await r.json()) as { lat: string; lon: string }[];
    if (!j[0]) return null;
    return { type: 'Point', coordinates: [parseFloat(j[0].lon), parseFloat(j[0].lat)] };
  } catch { return null; }
};
const geocodeBest = async (qs: string[]): Promise<Geo | null> => { for (const q of qs.filter(Boolean)) { const g = await geocodeOne(q); await sleep(1100); if (g) return g; } return null; };

const seedByDom = new Map<string, SeedGym>();
for (const s of seed) if (s.website) { const d = reg(s.website); if (d && !seedByDom.has(d)) seedByDom.set(d, s); }

const decodoGeo = (gymName: string): Geo | null => { const d = openmats.find((o) => o.gymName === gymName && o.geo); return d?.geo ?? null; };
const matchSeed = (g: DecodoGym): SeedGym | null => {
  const s = seedByDom.get(reg(g.website));
  if (s) return s;
  const gg = decodoGeo(cleanName(g.name));
  if (!gg) return null;
  let best: SeedGym | null = null, bs = 0;
  for (const c of seed) { if (c.state !== 'TX') continue; const o = overlap(cleanName(g.name), c.name); if (o >= 0.5 && o > bs) { const d = km(gg.coordinates[1], gg.coordinates[0], c.geo.coordinates[1], c.geo.coordinates[0]); if (d < 3) { bs = o; best = c; } } }
  return best;
};

const main = async (): Promise<void> => {
  const docs: Record<string, unknown>[] = [];
  let matched = 0, standalone = 0, geocoded = 0, noGeo = 0;
  const now = new Date().toISOString();

  for (const g of decodo) {
    const nm = cleanName(g.name);
    const sched = openmats.filter((o) => o.gymName === nm);
    if (!sched.length) continue;
    const s = matchSeed(g);
    let geo: Geo | null;
    let gymId: string, gymName: string, address: string | null, city: string | null, state: string, postalCode: string | null, gymRating: number | null;

    if (s) {
      matched++;
      geo = s.geo; gymId = s._id; gymName = s.name;
      address = s.address ?? null; city = s.city ?? null; state = s.state ?? 'TX'; postalCode = s.postalCode ?? null; gymRating = s.rating ?? null;
    } else {
      standalone++;
      gymId = `omgym-${slug(g.name)}`; gymName = nm;
      const first = sched[0];
      address = first?.address ?? null; city = first?.city ?? g.city; state = first?.state ?? 'TX'; postalCode = first?.postalCode ?? null; gymRating = null;
      geo = sched.find((o) => o.geo)?.geo ?? null;
      if (!geo) {
        geo = await geocodeBest([[address, city, state, postalCode].filter(Boolean).join(', '), `${gymName}, ${city}, TX`, `${city}, TX`]);
        if (geo) geocoded++;
      }
    }
    if (!geo) { noGeo++; console.warn(`  no geo: ${gymName}`); continue; }
    const [lng, lat] = geo.coordinates;

    for (const o of sched) {
      const id = `om-${gymId}-${o.dayOfWeek}`;
      docs.push({
        _id: id, id, gymId, hostId: null,
        title: o.title, description: o.description,
        dayOfWeek: o.dayOfWeek, startTime: o.startTime, endTime: o.endTime,
        isRecurring: true, specificDate: null, maxParticipants: null, skillLevel: 'all', giType: o.giType,
        isCancelled: false, verified: false, status: 'live', feeCents: 0, attendeeCount: 0,
        gymName, latitude: lat, longitude: lng, address, city, state, postalCode,
        gymRating, createdAt: now, gymOwnerId: null, geo,
      });
    }
  }

  // dedup _id (daily gyms already unique per day; guard anyway)
  const seen = new Set<string>();
  const final = docs.filter((d) => (seen.has(d['_id'] as string) ? false : (seen.add(d['_id'] as string), true)));
  writeFileSync(join(DATA, 'openmats-full.json'), JSON.stringify(final, null, 2));
  console.log(`Gyms: ${decodo.length} (matched-to-seed ${matched}, standalone ${standalone}) | geocoded ${geocoded} | dropped no-geo ${noGeo}`);
  console.log(`OpenMat docs: ${final.length} | all have geo: ${final.every((d) => d['geo'])}`);
  console.log(`Wrote data/openmats-full.json`);
};

await main();
