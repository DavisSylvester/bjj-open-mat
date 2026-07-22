/**
 * Phase 1 — OpenStreetMap / Overpass pull of BJJ academies within 300 mi of 75495.
 *
 * OSM records carry name + address + coordinates directly, so this is the
 * geocoded backbone of the dataset. Output is normalized toward the app's Gym
 * Mongo document (geo = GeoJSON [lng, lat]).
 *
 * Run: bun run scripts/gym-research/phase1-overpass.mts
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const CENTER = { lat: 33.42, lng: -96.58 } as const; // 75495, Van Alstyne TX
const RADIUS_M = 482803; // 300 miles
const OUT_DIR = join(import.meta.dir, 'data');
const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
] as const;
const UA = 'bjj-open-mat-research/1.0 (contact: dsylvesteriii@gmail.com)';
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

interface OverpassEl {
  readonly type: 'node' | 'way' | 'relation';
  readonly id: number;
  readonly lat?: number;
  readonly lon?: number;
  readonly center?: { lat: number; lon: number };
  readonly tags?: Record<string, string>;
}

interface NormalizedGym {
  name: string;
  address: string;
  city: string | null;
  state: string | null;
  postalCode: string | null;
  country: null;
  geo: { type: 'Point'; coordinates: [number, number] };
  source: 'osm';
  osmType: string;
  osmId: number;
  phone: string | null;
  website: string | null;
}

const AROUND = `around:${RADIUS_M},${CENTER.lat},${CENTER.lng}`;
// Indexed-key clauses only (name regex over a 300mi radius is un-indexed and times out).
const QUERY = `[out:json][timeout:300];
(
  nwr["sport"="brazilian_jiu_jitsu"](${AROUND});
  nwr["martial_art"](${AROUND});
  nwr["sport"="martial_arts"](${AROUND});
  nwr["shop"="martial_arts"](${AROUND});
  nwr["leisure"="fitness_centre"]["sport"~"martial",i](${AROUND});
);
out center tags;`;

// BJJ identification is done client-side over the martial-arts candidate set.
const BJJ_NAME = /jiu.?jitsu|jujitsu|ju.jitsu|\bbjj\b|gracie|10th planet|atos|checkmat|carlson|renzo|rilion|soul fighters|zenith|alliance jiu|caio terra|marcelo garcia/i;
const isBjj = (t: Record<string, string>): boolean => {
  if (t['sport'] === 'brazilian_jiu_jitsu') return true;
  const ma = (t['martial_art'] ?? '').toLowerCase();
  if (/brazilian|jiu|bjj|gracie/.test(ma)) return true;
  return BJJ_NAME.test(t['name'] ?? '');
};

const haversineMi = (aLat: number, aLng: number, bLat: number, bLng: number): number => {
  const R = 3958.7613;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

const buildAddress = (t: Record<string, string>): string => {
  const parts = [
    [t['addr:housenumber'], t['addr:street']].filter(Boolean).join(' '),
    t['addr:unit'] ? `Unit ${t['addr:unit']}` : '',
  ].filter(Boolean);
  return parts.join(', ').trim();
};

const fetchOverpass = async (): Promise<OverpassEl[]> => {
  let lastErr: unknown = null;
  for (const url of ENDPOINTS) {
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
         
        console.log(`Querying ${url} (attempt ${attempt}) ...`);
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': UA,
            Accept: 'application/json',
          },
          body: `data=${encodeURIComponent(QUERY)}`,
        });
        if (res.status === 429 || res.status === 504) throw new Error(`HTTP ${res.status} (retryable)`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = (await res.json()) as { elements: OverpassEl[]; remark?: string };
        if (json.remark && json.elements.length === 0) throw new Error(`remark: ${json.remark}`);
        return json.elements;
      } catch (err) {
        lastErr = err;
         
        console.warn(`  failed: ${String(err)}`);
        if (attempt < 3) await sleep(attempt * 8000);
      }
    }
  }
  throw new Error(`All Overpass endpoints failed: ${String(lastErr)}`);
};

const main = async (): Promise<void> => {
  mkdirSync(OUT_DIR, { recursive: true });
  const els = await fetchOverpass();
  const seen = new Set<string>();
  const gyms: NormalizedGym[] = [];
  const candidates: NormalizedGym[] = [];

  for (const el of els) {
    const t = el.tags ?? {};
    const name = t['name'];
    if (!name) continue;
    const lat = el.lat ?? el.center?.lat;
    const lon = el.lon ?? el.center?.lon;
    if (lat === undefined || lon === undefined) continue;
    if (haversineMi(CENTER.lat, CENTER.lng, lat, lon) > 300) continue;

    const key = `${name.toLowerCase()}|${lat.toFixed(3)}|${lon.toFixed(3)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const gym: NormalizedGym = {
      name,
      address: buildAddress(t),
      city: t['addr:city'] ?? null,
      state: t['addr:state'] ?? null,
      postalCode: t['addr:postcode'] ?? null,
      country: null,
      geo: { type: 'Point', coordinates: [lon, lat] },
      source: 'osm',
      osmType: el.type,
      osmId: el.id,
      phone: t['phone'] ?? t['contact:phone'] ?? null,
      website: t['website'] ?? t['contact:website'] ?? null,
    };
    if (isBjj(t)) gyms.push(gym);
    else candidates.push(gym);
  }

  gyms.sort((a, b) => a.name.localeCompare(b.name));
  candidates.sort((a, b) => a.name.localeCompare(b.name));
  writeFileSync(join(OUT_DIR, 'osm-raw.json'), JSON.stringify(els, null, 2));
  writeFileSync(join(OUT_DIR, 'phase1-osm.json'), JSON.stringify(gyms, null, 2));
  writeFileSync(join(OUT_DIR, 'phase1-osm-candidates.json'), JSON.stringify(candidates, null, 2));

  const withAddr = gyms.filter((g) => g.address).length;
   
  console.log(`\nOSM elements returned: ${els.length}`);
   
  console.log(`Confirmed BJJ in radius: ${gyms.length} (with street address: ${withAddr})`);
   
  console.log(`Martial-arts candidates (for review/cross-check): ${candidates.length}`);
   
  console.log(`Wrote phase1-osm.json + phase1-osm-candidates.json`);
};

await main();
