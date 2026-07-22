/**
 * Phase 5a — Build the Mongo seed from the merged dataset.
 *
 * Emits gyms.seed.json: an array of `gyms`-collection documents (GymDoc shape:
 * _id + geo GeoJSON[lng,lat] + Gym-contract fields only). Provenance (sources,
 * brand) is NOT stored as loose keys — brand is folded into `description` — so
 * documents stay valid against the Gym TypeBox contract when read back.
 *
 * Run: bun run scripts/gym-research/phase5-build-seed.mts
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const NOW = new Date().toISOString();

interface Geo { type: 'Point'; coordinates: [number, number]; }
interface Merged {
  id: string; name: string; address: string; city: string | null; state: string | null;
  postalCode: string | null; geo: Geo; googlePlaceId: string | null; website: string | null;
  phone: string | null; brand: string | null; rating: number | null; ratingCount: number | null;
}

interface GymDoc {
  _id: string;
  name: string;
  description?: string;
  address: string;
  city?: string;
  state?: string;
  country: string | null;
  postalCode?: string;
  geo: Geo;
  googlePlaceId?: string;
  phone?: string;
  website?: string;
  amenities: string[];
  isVerified: boolean;
  rating?: number;
  ratingCount?: number;
  createdAt: string;
}

const merged = JSON.parse(readFileSync(join(DATA, 'phase4-merged.json'), 'utf8')) as Merged[];

// US state/territory codes — records in these get country "US"; anything else stays null.
const US_STATES = new Set(['AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC', 'PR']);

const docs: GymDoc[] = merged.map((m) => {
  const d: GymDoc = {
    _id: m.id,
    name: m.name,
    address: m.address,
    country: m.state && US_STATES.has(m.state) ? 'US' : null,
    geo: m.geo,
    amenities: [],
    isVerified: false,
    createdAt: NOW,
  };
  if (m.brand) d.description = `${m.brand} affiliate`;
  if (m.city) d.city = m.city;
  if (m.state) d.state = m.state;
  if (m.postalCode) d.postalCode = m.postalCode;
  if (m.googlePlaceId) d.googlePlaceId = m.googlePlaceId;
  if (m.phone) d.phone = m.phone;
  if (m.website) d.website = m.website;
  if (typeof m.rating === 'number') d.rating = m.rating;
  if (typeof m.ratingCount === 'number') d.ratingCount = m.ratingCount;
  return d;
});

// integrity checks
const ids = new Set(docs.map((d) => d._id));
if (ids.size !== docs.length) throw new Error('duplicate _id in seed');
const badGeo = docs.filter((d) => {
  const [lng, lat] = d.geo.coordinates;
  return !(lng >= -104 && lng <= -89 && lat >= 28 && lat <= 38); // sanity box for the region
});

writeFileSync(join(DATA, 'gyms.seed.json'), JSON.stringify(docs, null, 2));
 
console.log(`Wrote ${docs.length} gym docs -> data/gyms.seed.json`);
 
console.log(`  unique _id: ${ids.size} | with googlePlaceId: ${docs.filter((d) => d.googlePlaceId).length} | with website: ${docs.filter((d) => d.website).length}`);
 
console.log(`  geo outside region sanity-box: ${badGeo.length}${badGeo.length ? ' -> ' + badGeo.slice(0, 3).map((d) => d.name).join(', ') : ''}`);
