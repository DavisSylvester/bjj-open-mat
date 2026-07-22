/**
 * Phase 8 — Ensure every gym has a website.
 *
 * For each doc still missing `website`:
 *   - with googlePlaceId -> Google Place Details (fields=website,url); use the real
 *     website if present, else the Google Maps listing URL as a guaranteed link.
 *   - without googlePlaceId -> a Google Maps search URL built from name + location.
 *
 * Idempotent: skips docs that already have a website. Checkpoints the seed.
 * Run: bun run scripts/gym-research/phase8-backfill-websites.mts
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const SEED = join(DATA, 'gyms.seed.json');
const envFile = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
const KEY = (envFile.match(/^MAPS_API_KEY=(.*)$/m)?.[1] ?? '').trim().replace(/^["']|["']$/g, '');

interface Gym { _id: string; name: string; city?: string; state?: string; website?: string; googlePlaceId?: string; [k: string]: unknown; }

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

const detailsUrl = async (placeId: string): Promise<{ website?: string; url?: string }> => {
  try {
    const res = await fetch(`https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=website,url&key=${KEY}`);
    const j = (await res.json()) as { result?: { website?: string; url?: string } };
    return j.result ?? {};
  } catch { return {}; }
};

const mapsSearch = (g: Gym): string =>
  `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${g.name} ${g.city ?? ''} ${g.state ?? ''}`.trim())}`;

const siteRoot = (u: string): string => { try { return new URL(u).origin + '/'; } catch { return u; } };

const main = async (): Promise<void> => {
  const gyms = JSON.parse(readFileSync(SEED, 'utf8')) as Gym[];
  let real = 0, mapsListing = 0, searchFallback = 0, calls = 0, done = 0;

  for (const g of gyms) {
    if (g.website) continue;
    if (g.googlePlaceId) {
      const d = await detailsUrl(g.googlePlaceId);
      calls++;
      if (d.website) { g.website = siteRoot(d.website); real++; }
      else if (d.url) { g.website = d.url; mapsListing++; }
      else { g.website = mapsSearch(g); searchFallback++; }
      await sleep(60);
    } else {
      g.website = mapsSearch(g);
      searchFallback++;
    }
    done++;
    if (done % 25 === 0) { writeFileSync(SEED, JSON.stringify(gyms, null, 2)); process.stdout.write(`\r  backfilled ${done} (calls ${calls}) ...`); }
  }
  writeFileSync(SEED, JSON.stringify(gyms, null, 2));
  const withSite = gyms.filter((x) => x.website).length;
   
  console.log(`\nDONE. real websites: ${real} | maps-listing fallback: ${mapsListing} | search fallback: ${searchFallback}`);
   
  console.log(`Place Details calls: ${calls} (~$${(calls * 17 / 1000).toFixed(2)})`);
   
  console.log(`Coverage: ${withSite}/${gyms.length} have a website (${gyms.length - withSite} missing)`);
};

await main();
