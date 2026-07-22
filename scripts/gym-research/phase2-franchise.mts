/**
 * Phase 2 — Franchise / affiliation locators within 300 mi of 75495.
 *
 * These networks expose structured locator data (name + address + coordinates),
 * so they give authoritative brand affiliation to merge against OSM/Places.
 * Currently implemented: Gracie Barra (largest regional footprint, clean API).
 * Extend `SOURCES` as other brands are reverse-engineered.
 *
 * Run: bun run scripts/gym-research/phase2-franchise.mts
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const CENTER = { lat: 33.42, lng: -96.58 } as const;
const OUT_DIR = join(import.meta.dir, 'data');
const UA = 'Mozilla/5.0 (bjj-open-mat-research)';

interface NormalizedGym {
  name: string;
  address: string;
  city: string | null;
  state: string | null;
  postalCode: string | null;
  country: null;
  geo: { type: 'Point'; coordinates: [number, number] };
  source: string;
  brand: string;
  website: string | null;
  distanceMi: number;
}

const haversineMi = (aLat: number, aLng: number, bLat: number, bLng: number): number => {
  const R = 3958.7613;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

const STATE_RE = /\b(TX|OK|LA|AR|NM|Texas|Oklahoma|Louisiana|Arkansas|New Mexico)\b/i;

const STATE_MAP: Record<string, string> = {
  texas: 'TX', oklahoma: 'OK', louisiana: 'LA', arkansas: 'AR', 'new mexico': 'NM',
};

/** Parse a messy US "street, [suite,] city, ST[, ]ZIP" string. Coordinates remain the
 *  source of truth; Phase 4 reverse-geocodes to canonicalize these fields. */
const parseUsAddress = (full: string): { address: string; city: string | null; state: string | null; zip: string | null } => {
  const clean = full.replace(/,?\s*(USA|United States(?: of America)?)\s*$/i, '').trim();
  const parts = clean.split(',').map((p) => p.trim()).filter(Boolean);
  let state: string | null = null;
  let zip: string | null = null;
  let city: string | null = null;

  // trailing ZIP — may be its own segment ("75070") or fused ("TX 75070")
  if (parts.length) {
    const last = parts[parts.length - 1] ?? '';
    const zm = last.match(/(\d{5})(?:-\d{4})?$/);
    if (zm) {
      zip = zm[1] ?? null;
      const rest = last.replace(/(\d{5})(?:-\d{4})?$/, '').trim().replace(/,$/, '');
      if (rest === '') parts.pop();
      else parts[parts.length - 1] = rest;
    }
  }
  // trailing state — 2-letter, full name, or fused into "City ST"
  if (parts.length) {
    const last = parts[parts.length - 1] ?? '';
    if (/^[A-Za-z]{2}$/.test(last)) {
      state = last.toUpperCase();
      parts.pop();
    } else if (STATE_MAP[last.toLowerCase()]) {
      state = STATE_MAP[last.toLowerCase()] ?? null;
      parts.pop();
    } else {
      const m = last.match(/^(.*\S)\s+([A-Za-z]{2})$/);
      if (m && /^(TX|OK|LA|AR|NM)$/i.test(m[2] ?? '')) {
        state = (m[2] ?? '').toUpperCase();
        parts[parts.length - 1] = (m[1] ?? '').trim();
      }
    }
  }
  if (parts.length) city = parts.pop() ?? null;
  return { address: parts.join(', '), city, state, zip };
};

const fetchText = async (url: string, init?: RequestInit): Promise<string> => {
  const res = await fetch(url, { ...init, headers: { 'User-Agent': UA, ...(init?.headers ?? {}) } });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.text();
};

interface GbSchool {
  readonly title: string;
  readonly lat: string;
  readonly lng: string;
  readonly siteurl?: string;
  readonly fullAddress?: string;
}

const fetchGracieBarra = async (): Promise<NormalizedGym[]> => {
  // Scrape a fresh nonce from the locator page, then hit its admin-ajax endpoint.
  const page = await fetchText('https://graciebarra.com/find-a-school/');
  const nonce = page.match(/nonce":"([a-f0-9]+)"/i)?.[1] ?? '';
  const body = `action=GB_sl_get_schools&offset=0&limit=5000&lat=${CENTER.lat}&lng=${CENTER.lng}&nonce=${nonce}`;
  const raw = await fetchText('https://graciebarra.com/wp-admin/admin-ajax.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const schools = JSON.parse(raw) as GbSchool[];
  const out: NormalizedGym[] = [];
  for (const s of schools) {
    const lat = parseFloat(s.lat);
    const lng = parseFloat(s.lng);
    if (Number.isNaN(lat) || Number.isNaN(lng)) continue;
    const distanceMi = haversineMi(CENTER.lat, CENTER.lng, lat, lng);
    if (distanceMi > 300) continue;
    const p = parseUsAddress(s.fullAddress ?? '');
    out.push({
      name: s.title.trim(),
      address: p.address,
      city: p.city,
      state: p.state,
      postalCode: p.zip,
      country: null,
      geo: { type: 'Point', coordinates: [lng, lat] },
      source: 'gracie-barra',
      brand: 'Gracie Barra',
      website: s.siteurl?.trim() || null,
      distanceMi: Math.round(distanceMi * 10) / 10,
    });
  }
  return out;
};

const SOURCES: ReadonlyArray<{ name: string; fetch: () => Promise<NormalizedGym[]> }> = [
  { name: 'Gracie Barra', fetch: fetchGracieBarra },
];

const main = async (): Promise<void> => {
  mkdirSync(OUT_DIR, { recursive: true });
  const all: NormalizedGym[] = [];
  for (const src of SOURCES) {
    try {
      const gyms = await src.fetch();
       
      console.log(`${src.name}: ${gyms.length} in radius`);
      all.push(...gyms);
    } catch (err) {
       
      console.warn(`${src.name}: FAILED — ${String(err)}`);
    }
  }
  all.sort((a, b) => a.distanceMi - b.distanceMi);
  writeFileSync(join(OUT_DIR, 'phase2-franchise.json'), JSON.stringify(all, null, 2));
  const noAddr = all.filter((g) => !STATE_RE.test(`${g.state} ${g.address}`)).length;
   
  console.log(`\nTotal franchise gyms in radius: ${all.length}`);
   
  console.log(`  (parse-check: ${noAddr} without a recognizable region state — review)`);
   
  console.log(`Wrote ${join(OUT_DIR, 'phase2-franchise.json')}`);
};

await main();
