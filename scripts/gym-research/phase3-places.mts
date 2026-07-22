/**
 * Phase 3 — Google Places tiled sweep of BJJ gyms within 300 mi of 75495.
 *
 * The workhorse: OSM/franchise cover a fraction; Places has near-complete US
 * business coverage with clean addresses, coordinates and a stable place_id
 * (the dedup key = Gym.googlePlaceId). Legacy Text Search, tiled across the
 * region's population centers, paginated, deduped, radius-filtered.
 *
 * Cost control: hard MAX_REQUESTS cap. Text Search bills ~$32 / 1000 requests.
 *
 * Run: bun run scripts/gym-research/phase3-places.mts
 */
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const CENTER = { lat: 33.42, lng: -96.58 } as const;
const OUT_DIR = join(import.meta.dir, 'data');
const MAX_REQUESTS = 450; // ~$14.40 ceiling; real usage far below
const TILE_RADIUS_M = 32000; // ~20 mi bias per tile
const QUERY = 'brazilian jiu jitsu';

const readKey = (): string => {
  const env = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
  const m = env.match(/^MAPS_API_KEY=(.*)$/m);
  const key = (m?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
  if (!key) throw new Error('MAPS_API_KEY not found in apps/api/.env');
  return key;
};
const KEY = readKey();

interface Tile { name: string; lat: number; lng: number; }
const TILES: readonly Tile[] = [
  // --- DFW + North TX ---
  { name: 'Van Alstyne', lat: 33.42, lng: -96.58 }, { name: 'Sherman', lat: 33.64, lng: -96.61 },
  { name: 'McKinney', lat: 33.20, lng: -96.63 }, { name: 'Frisco', lat: 33.15, lng: -96.82 },
  { name: 'Plano', lat: 33.02, lng: -96.70 }, { name: 'Denton', lat: 33.21, lng: -97.13 },
  { name: 'Dallas', lat: 32.78, lng: -96.80 }, { name: 'Addison', lat: 32.96, lng: -96.83 },
  { name: 'Mesquite', lat: 32.77, lng: -96.60 }, { name: 'Fort Worth', lat: 32.75, lng: -97.33 },
  { name: 'Arlington', lat: 32.74, lng: -97.11 }, { name: 'Southlake', lat: 32.93, lng: -97.14 },
  { name: 'Weatherford', lat: 32.76, lng: -97.80 }, { name: 'Waxahachie', lat: 32.39, lng: -96.85 },
  { name: 'Greenville', lat: 33.14, lng: -96.11 }, { name: 'Corsicana', lat: 32.10, lng: -96.47 },
  { name: 'Paris', lat: 33.66, lng: -95.56 }, { name: 'Wichita Falls', lat: 33.91, lng: -98.49 },
  // --- East TX ---
  { name: 'Tyler', lat: 32.35, lng: -95.30 }, { name: 'Longview', lat: 32.50, lng: -94.74 },
  { name: 'Marshall', lat: 32.54, lng: -94.37 }, { name: 'Texarkana', lat: 33.44, lng: -94.04 },
  { name: 'Lufkin', lat: 31.34, lng: -94.73 }, { name: 'Nacogdoches', lat: 31.60, lng: -94.65 },
  { name: 'Palestine', lat: 31.76, lng: -95.63 },
  // --- Central TX ---
  { name: 'Waco', lat: 31.55, lng: -97.15 }, { name: 'Temple', lat: 31.10, lng: -97.34 },
  { name: 'Killeen', lat: 31.12, lng: -97.73 }, { name: 'Austin', lat: 30.27, lng: -97.74 },
  { name: 'Round Rock', lat: 30.51, lng: -97.68 }, { name: 'Austin South', lat: 30.20, lng: -97.85 },
  { name: 'San Marcos', lat: 29.88, lng: -97.94 },
  // --- South-Central TX ---
  { name: 'San Antonio', lat: 29.42, lng: -98.49 }, { name: 'San Antonio North', lat: 29.60, lng: -98.50 },
  { name: 'New Braunfels', lat: 29.70, lng: -98.12 },
  // --- SE TX / Houston ---
  { name: 'Houston', lat: 29.76, lng: -95.36 }, { name: 'Cypress', lat: 29.97, lng: -95.66 },
  { name: 'Katy/Sugar Land', lat: 29.62, lng: -95.66 }, { name: 'The Woodlands', lat: 30.16, lng: -95.46 },
  { name: 'College Station', lat: 30.63, lng: -96.33 }, { name: 'Huntsville', lat: 30.72, lng: -95.55 },
  // --- West TX ---
  { name: 'Abilene', lat: 32.45, lng: -99.73 }, { name: 'Mineral Wells', lat: 32.81, lng: -98.11 },
  // --- Oklahoma ---
  { name: 'Oklahoma City', lat: 35.47, lng: -97.52 }, { name: 'Norman', lat: 35.22, lng: -97.44 },
  { name: 'Tulsa', lat: 36.15, lng: -95.99 }, { name: 'Broken Arrow', lat: 36.05, lng: -95.79 },
  { name: 'Lawton', lat: 34.61, lng: -98.39 }, { name: 'Stillwater', lat: 36.12, lng: -97.07 },
  { name: 'Ardmore', lat: 34.17, lng: -97.14 }, { name: 'Durant', lat: 33.99, lng: -96.40 },
  { name: 'Muskogee', lat: 35.75, lng: -95.37 },
  // --- Louisiana ---
  { name: 'Shreveport', lat: 32.53, lng: -93.75 }, { name: 'Monroe', lat: 32.51, lng: -92.12 },
  // --- Arkansas ---
  { name: 'Fort Smith', lat: 35.39, lng: -94.40 }, { name: 'Fayetteville', lat: 36.06, lng: -94.16 },
  { name: 'Hot Springs', lat: 34.50, lng: -93.05 }, { name: 'Little Rock', lat: 34.75, lng: -92.29 },
];

interface PlaceResult {
  readonly name: string;
  readonly formatted_address?: string;
  readonly place_id: string;
  readonly geometry?: { location?: { lat: number; lng: number } };
  readonly types?: string[];
  readonly business_status?: string;
  readonly rating?: number;
  readonly user_ratings_total?: number;
}
interface TextSearchResponse {
  readonly results: PlaceResult[];
  readonly status: string;
  readonly next_page_token?: string;
  readonly error_message?: string;
}

interface NormalizedGym {
  name: string;
  address: string;
  city: string | null;
  state: string | null;
  postalCode: string | null;
  country: null;
  geo: { type: 'Point'; coordinates: [number, number] };
  source: 'google-places';
  googlePlaceId: string;
  types: string[];
  rating: number | null;
  ratingCount: number | null;
  distanceMi: number;
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

const haversineMi = (aLat: number, aLng: number, bLat: number, bLng: number): number => {
  const R = 3958.7613;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s = Math.sin(dLat / 2) ** 2 + Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

const STATE_MAP: Record<string, string> = { texas: 'TX', oklahoma: 'OK', louisiana: 'LA', arkansas: 'AR', 'new mexico': 'NM' };
const parseUsAddress = (full: string): { address: string; city: string | null; state: string | null; zip: string | null } => {
  const clean = full.replace(/,?\s*(USA|United States(?: of America)?)\s*$/i, '').trim();
  const parts = clean.split(',').map((p) => p.trim()).filter(Boolean);
  let state: string | null = null, zip: string | null = null, city: string | null = null;
  if (parts.length) {
    const last = parts[parts.length - 1] ?? '';
    const zm = last.match(/(\d{5})(?:-\d{4})?$/);
    if (zm) {
      zip = zm[1] ?? null;
      const rest = last.replace(/(\d{5})(?:-\d{4})?$/, '').trim();
      if (rest === '') parts.pop(); else parts[parts.length - 1] = rest;
    }
  }
  if (parts.length) {
    const last = parts[parts.length - 1] ?? '';
    if (/^[A-Za-z]{2}$/.test(last)) { state = last.toUpperCase(); parts.pop(); }
    else if (STATE_MAP[last.toLowerCase()]) { state = STATE_MAP[last.toLowerCase()] ?? null; parts.pop(); }
    else {
      const m = last.match(/^(.*\S)\s+([A-Za-z]{2})$/);
      if (m && /^(TX|OK|LA|AR|NM)$/i.test(m[2] ?? '')) { state = (m[2] ?? '').toUpperCase(); parts[parts.length - 1] = (m[1] ?? '').trim(); }
    }
  }
  if (parts.length) city = parts.pop() ?? null;
  return { address: parts.join(', '), city, state, zip };
};

let requests = 0;
const textSearch = async (params: Record<string, string>): Promise<TextSearchResponse> => {
  const qs = new URLSearchParams({ ...params, key: KEY }).toString();
  requests++;
  const res = await fetch(`https://maps.googleapis.com/maps/api/place/textsearch/json?${qs}`);
  return (await res.json()) as TextSearchResponse;
};

const byId = new Map<string, NormalizedGym>();

const collect = (r: PlaceResult): void => {
  const loc = r.geometry?.location;
  if (!loc) return;
  if (r.business_status === 'CLOSED_PERMANENTLY') return;
  const distanceMi = haversineMi(CENTER.lat, CENTER.lng, loc.lat, loc.lng);
  if (distanceMi > 300) return;
  if (byId.has(r.place_id)) return;
  const p = parseUsAddress(r.formatted_address ?? '');
  byId.set(r.place_id, {
    name: r.name,
    address: p.address,
    city: p.city,
    state: p.state,
    postalCode: p.zip,
    country: null,
    geo: { type: 'Point', coordinates: [loc.lng, loc.lat] },
    source: 'google-places',
    googlePlaceId: r.place_id,
    types: r.types ?? [],
    rating: r.rating ?? null,
    ratingCount: r.user_ratings_total ?? null,
    distanceMi: Math.round(distanceMi * 10) / 10,
  });
};

const sweepTile = async (tile: Tile): Promise<number> => {
  const before = byId.size;
  let resp = await textSearch({ query: QUERY, location: `${tile.lat},${tile.lng}`, radius: String(TILE_RADIUS_M) });
  if (resp.status !== 'OK' && resp.status !== 'ZERO_RESULTS') {
     
    console.warn(`  ${tile.name}: status ${resp.status} ${resp.error_message ?? ''}`);
    if (resp.status === 'OVER_QUERY_LIMIT' || resp.status === 'REQUEST_DENIED') throw new Error(resp.status);
  }
  resp.results.forEach(collect);
  let page = 1;
  while (resp.next_page_token && page < 3 && requests < MAX_REQUESTS) {
    const token = resp.next_page_token;
    await sleep(2100); // token needs a moment to become valid
    resp = await textSearch({ pagetoken: token });
    if (resp.status === 'INVALID_REQUEST') {
      // token not ready yet — one retry with a longer wait, else give up on this tile's pages
      await sleep(2500);
      resp = await textSearch({ pagetoken: token });
      if (resp.status !== 'OK') break;
    }
    resp.results.forEach(collect);
    page++;
  }
  return byId.size - before;
};

const main = async (): Promise<void> => {
  mkdirSync(OUT_DIR, { recursive: true });
   
  console.log(`Sweeping ${TILES.length} tiles (cap ${MAX_REQUESTS} requests)...\n`);
  for (const tile of TILES) {
    if (requests >= MAX_REQUESTS) { console.warn(`Hit request cap at ${tile.name}`); break; }
    try {
      const added = await sweepTile(tile);
       
      console.log(`  ${tile.name.padEnd(18)} +${added.toString().padStart(3)}  (total ${byId.size}, req ${requests})`);
    } catch (err) {
       
      console.error(`  ${tile.name}: abort — ${String(err)}`);
      break;
    }
  }
  const gyms = [...byId.values()].sort((a, b) => a.distanceMi - b.distanceMi);
  writeFileSync(join(OUT_DIR, 'phase3-places.json'), JSON.stringify(gyms, null, 2));
  const cost = (requests / 1000) * 32;
  const states: Record<string, number> = {};
  for (const g of gyms) states[g.state ?? '??'] = (states[g.state ?? '??'] ?? 0) + 1;
   
  console.log(`\nUnique gyms in radius: ${gyms.length}`);
   
  console.log(`States: ${JSON.stringify(states)}`);
   
  console.log(`Requests: ${requests}  (est. cost ~$${cost.toFixed(2)})`);
   
  console.log(`Wrote ${join(OUT_DIR, 'phase3-places.json')}`);
};

await main();
