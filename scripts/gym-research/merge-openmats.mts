/**
 * Merge Decodo-scraped open-mat schedules onto the 842-gym Places seed.
 *
 * Matches each open-mat gym to its seed counterpart by website domain (reliable),
 * or by name + geo proximity (<3km) as a guarded fallback — never name-only
 * (avoids matching "BTT Irving" to "BTT North Dallas"). Emits OpenMat documents
 * that carry the scraped SCHEDULE but the seed's AUTHORITATIVE gym location
 * (address, geo, place id), linked via gymId = seed._id.
 *
 * Run: bun run scripts/gym-research/merge-openmats.mts
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';

const DATA = join(import.meta.dir, 'data');
const read = <T>(f: string): T => JSON.parse(readFileSync(join(DATA, f), 'utf8')) as T;

interface SeedGym { _id: string; name: string; address?: string; city?: string; state?: string; postalCode?: string; website?: string; rating?: number; geo: { type: 'Point'; coordinates: [number, number] } }
interface DecodoGym { name: string; website: string; city: string; openMat: { hosts: boolean } }
interface OpenMatDoc { gymName: string; dayOfWeek: number | null; startTime: string | null; endTime: string | null; giType: string; title: string; description: string; [k: string]: unknown }

const seed = read<SeedGym[]>('gyms.seed.json');
const decodo = read<DecodoGym[]>('tx-bjj-decodo.json').filter((g) => g.openMat.hosts);
const openmats = read<OpenMatDoc[]>('tx-openmats.json');

const cleanName = (n: string): string => n.replace(/&#8211;|&#8212;/g, '-').replace(/&amp;/g, '&').split(/\s[-–—|]\s/)[0]?.trim() || n;
const reg = (h: string): string => { try { return new URL(h.startsWith('http') ? h : 'http://' + h).hostname.replace(/^www\./, '').split('.').slice(-2).join('.'); } catch { return ''; } };
const norm = (n: string): Set<string> => new Set(n.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').split(/\s+/).filter((w) => w && !['jiu', 'jitsu', 'bjj', 'academy', 'brazilian', 'the', 'martial', 'arts', 'mma', 'gym'].includes(w)));
const overlap = (a: string, b: string): number => { const A = norm(a), B = norm(b); if (!A.size || !B.size) return 0; let h = 0; for (const w of A) if (B.has(w)) h++; return h / Math.min(A.size, B.size); };
const km = (aLat: number, aLng: number, bLat: number, bLng: number): number => {
  const R = 6371, r = (x: number): number => (x * Math.PI) / 180;
  const s = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

const seedByDom = new Map<string, SeedGym>();
for (const s of seed) if (s.website) { const d = reg(s.website); if (d && !seedByDom.has(d)) seedByDom.set(d, s); }

// geo of a decodo open-mat gym (from its emitted OpenMat docs, if geocoded)
const decodoGeo = (gymName: string): { lat: number; lng: number } | null => {
  const d = openmats.find((o) => o.gymName === gymName && o['latitude'] != null);
  return d ? { lat: d['latitude'] as number, lng: d['longitude'] as number } : null;
};

const matched: { decodo: string; seed: SeedGym; how: string }[] = [];
const unmatched: string[] = [];

for (const g of decodo) {
  const nm = cleanName(g.name);
  let s = seedByDom.get(reg(g.website));
  let how = s ? 'domain' : '';
  if (!s) {
    const gg = decodoGeo(nm);
    let best: SeedGym | null = null, bs = 0;
    for (const cand of seed) {
      if (cand.state !== 'TX') continue;
      const o = overlap(nm, cand.name);
      if (o < 0.5) continue;
      // name fallback REQUIRES geo confirmation (< 3km) to avoid franchise/SEO false matches
      if (!gg) continue;
      const d = km(gg.lat, gg.lng, cand.geo.coordinates[1], cand.geo.coordinates[0]);
      if (d < 3 && o > bs) { bs = o; best = cand; }
    }
    if (best) { s = best; how = `name+geo ${bs.toFixed(2)}`; }
  }
  if (s) matched.push({ decodo: nm, seed: s, how }); else unmatched.push(nm);
}

// build OpenMat docs anchored to the seed gym
const now = new Date().toISOString();
const docs = matched.flatMap(({ decodo: dname, seed: s }) => {
  const sched = openmats.filter((o) => o.gymName === dname);
  return sched.map((o) => {
    const id = randomUUID();
    const [lng, lat] = s.geo.coordinates;
    return {
      _id: id, id, gymId: s._id, hostId: null,
      title: o.title, description: o.description,
      dayOfWeek: o.dayOfWeek, startTime: o.startTime, endTime: o.endTime,
      isRecurring: true, specificDate: null, maxParticipants: null, skillLevel: 'all', giType: o.giType,
      isCancelled: false, verified: false, status: 'live', feeCents: 0, attendeeCount: 0,
      gymName: s.name, latitude: lat, longitude: lng,
      address: s.address ?? null, city: s.city ?? null, state: s.state ?? 'TX', postalCode: s.postalCode ?? null,
      gymRating: s.rating ?? null, createdAt: now, gymOwnerId: null,
      geo: { type: 'Point' as const, coordinates: [lng, lat] as [number, number] },
    };
  });
});

writeFileSync(join(DATA, 'openmats-merged.json'), JSON.stringify(docs, null, 2));
 
console.log(`Open-mat gyms: ${decodo.length} | matched to 842 seed: ${matched.length} | unmatched: ${unmatched.length}`);
for (const m of matched) console.log(`  ✓ ${m.decodo}  ->  ${m.seed.name}  [${m.how}]`);
for (const u of unmatched) console.log(`  ✗ ${u}  (not in seed / no geo confirm)`);
 
console.log(`\nWrote ${docs.length} OpenMat docs (anchored to seed gymId + geo) -> data/openmats-merged.json`);
