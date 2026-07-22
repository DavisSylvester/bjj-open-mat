/**
 * Transform Decodo-discovered open-mat gyms into OpenMat documents.
 *
 * Re-fetches each open-mat gym through Decodo, parses the open-mat day + time
 * range + gi type, scrapes a street address, and geocodes it via OSM Nominatim
 * (free, not Google). Emits documents matching the app's OpenMat interface.
 *
 * Run: bun run scripts/gym-research/decodo-openmats.mts
 */
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';

const DATA = join(import.meta.dir, 'data');
const PROXY = (readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8').match(/^DECODO_PROXY_URL=(.*)$/m)?.[1] ?? '').trim();
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';

interface Discovered { name: string; website: string; domain: string; city: string; openMat: { hosts: boolean } }

interface OpenMatDoc {
  _id: string; id: string; gymId: string; hostId: string | null;
  title: string; description: string;
  dayOfWeek: number | null; startTime: string | null; endTime: string | null;
  isRecurring: boolean; specificDate: null;
  maxParticipants: number | null; skillLevel: string; giType: string;
  isCancelled: boolean; verified: boolean; status: string; feeCents: number; attendeeCount: number;
  gymName: string; latitude: number | null; longitude: number | null;
  address: string | null; city: string; state: 'TX'; postalCode: string | null;
  gymRating: null; createdAt: string; gymOwnerId: null;
  geo: { type: 'Point'; coordinates: [number, number] } | null;
}

const DAY_NUM: Record<string, number> = { sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6 };
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
const decodeEntities = (s: string): string => s.replace(/&#8211;|&#8212;/g, '-').replace(/&amp;/g, '&').replace(/&#39;|&#8217;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();

const pfetch = async (url: string): Promise<string | null> => {
  try {
    const r = await fetch(url, { proxy: PROXY, headers: { 'User-Agent': UA }, redirect: 'follow', signal: AbortSignal.timeout(20000) } as RequestInit);
    if (!r.ok) return null;
    return await r.text();
  } catch { return null; }
};

/** "8:30pm" | "11:00am" | "1PM" -> "HH:MM" (24h). */
const toHHMM = (raw: string): string | null => {
  const m = raw.trim().match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?/i);
  if (!m) return null;
  let h = parseInt(m[1] ?? '', 10);
  const min = m[2] ?? '00';
  const ap = (m[3] ?? '').toLowerCase();
  if (ap.startsWith('p') && h < 12) h += 12;
  if (ap.startsWith('a') && h === 12) h = 0;
  if (h > 23) return null;
  return `${String(h).padStart(2, '0')}:${min}`;
};

const toMin = (t: string): number => { const [h, m] = t.split(':').map(Number); return (h ?? 0) * 60 + (m ?? 0); };
/** Drop an implausible end (<= start, or a >5h span => likely a mis-parse). */
const clampRange = (start: string | null, end: string | null): { start: string | null; end: string | null } => {
  if (start && end) { const d = toMin(end) - toMin(start); if (d <= 0 || d > 300) return { start, end: null }; }
  return { start, end };
};

/**
 * Parse a time range like "11:00am – 12:30pm". In strict mode (prose text) an am/pm
 * marker is REQUIRED so bare digits from phone numbers / addresses aren't mistaken
 * for times. Structured schedule strings ("11:00am – 12:30pm") use lenient mode.
 */
const parseRange = (win: string, strict = false): { start: string | null; end: string | null } => {
  const ap = '(?:am|pm|a\\.m\\.|p\\.m\\.)';
  const t = strict ? `\\d{1,2}(?::\\d{2})?\\s*${ap}` : `\\d{1,2}(?::\\d{2})?\\s*${ap}?`;
  const rm = win.match(new RegExp(`(${t})\\s*(?:-|–|—|to)\\s*(${t})`, 'i'));
  if (rm) {
    let a = rm[1] ?? ''; const b = rm[2] ?? '';
    if (!/[ap]\.?m/i.test(a) && /[ap]\.?m/i.test(b)) a += b.match(/(am|pm|a\.m\.|p\.m\.)/i)?.[0] ?? '';
    return clampRange(toHHMM(a), toHHMM(b));
  }
  const one = win.match(new RegExp(strict ? `\\d{1,2}(?::\\d{2})?\\s*${ap}` : `\\d{1,2}(?::\\d{2})?\\s*${ap}`, 'i'));
  return { start: one ? toHHMM(one[0]) : null, end: null };
};

const dayOf = (win: string): number | null => {
  const m = win.match(/\b(sun|mon|tue|wed|thu|fri|sat)/i);
  return m ? (DAY_NUM[(m[1] ?? '').toLowerCase()] ?? null) : null;
};

/** Extract the best open-mat day+time. Tries structured schedule blocks first, then prose. */
const parseOpenMat = (html: string): { day: number | null; start: string | null; end: string | null; gi: string; daily: boolean } => {
  // structured: "saturday:[ { time:"11:00am – 12:30pm", name:"Open Mat", type:"openmat" } ]"
  const struct = html.match(/(sun|mon|tues?|wed(?:nes)?|thu(?:rs)?|fri|sat(?:ur)?)[a-z]*\s*:\s*\[[^\]]*?time:\s*"([^"]+)"[^\]]*?open\s?mat/i)
    ?? html.match(/open\s?mat[^\]]*?time:\s*"([^"]+)"/i);
  const text = decodeEntities(html.replace(/<[^>]+>/g, ' '));
  const idx = text.search(/open[\s-]?mat/i);
  const win = idx >= 0 ? text.slice(Math.max(0, idx - 90), idx + 130) : '';
  // Default assumption: most open mats run both gi & no-gi. Only narrow when the
  // site is explicit (e.g. "No-Gi Open Mat" with no gi mention, or vice versa).
  const hasNoGi = /no[\s-]?gi/i.test(win);
  const hasGi = /(?<!no[\s-])\bgi\b/i.test(win);
  const gi = hasNoGi && !hasGi ? 'nogi' : hasGi && !hasNoGi ? 'gi' : 'both';
  const daily = /open[\s-]?mat[^.]{0,30}daily|daily[^.]{0,20}open[\s-]?mat/i.test(text);
  if (struct) {
    const day = struct[1] ? (DAY_NUM[struct[1].slice(0, 3).toLowerCase()] ?? null) : null;
    const r = parseRange(struct[2] ?? struct[1] ?? '');
    return { day, start: r.start, end: r.end, gi, daily };
  }
  const r = parseRange(win, true); // strict: prose times must carry am/pm
  return { day: dayOf(win), start: r.start, end: r.end, gi, daily };
};

const ADDR = /(\d{1,6}\s+[A-Za-z0-9.'#\- ]{3,40}),?\s+([A-Za-z .]{3,25}),?\s+(TX|Texas)\s+(\d{5})/;
const scrapeAddress = (html: string): { address: string; city: string; postalCode: string } | null => {
  const t = decodeEntities(html.replace(/<[^>]+>/g, ' '));
  const m = t.match(ADDR);
  if (!m) return null;
  return { address: decodeEntities(m[1] ?? '').replace(/\s*,\s*$/, ''), city: (m[2] ?? '').trim(), postalCode: m[4] ?? '' };
};

const geocodeOne = async (q: string): Promise<{ lat: number; lng: number } | null> => {
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=us&q=${encodeURIComponent(q)}`, { headers: { 'User-Agent': 'bjj-open-mat-research/1.0 (dsylvesteriii@gmail.com)' } });
    const j = (await r.json()) as { lat: string; lon: string }[];
    if (!j[0]) return null;
    return { lat: parseFloat(j[0].lat), lng: parseFloat(j[0].lon) };
  } catch { return null; }
};

/** Try full address, then city+ZIP, then gym name + city — Nominatim rate limit ~1/s. */
const geocodeBest = async (queries: string[]): Promise<{ lat: number; lng: number } | null> => {
  for (const q of queries.filter(Boolean)) {
    const hit = await geocodeOne(q);
    await sleep(1100);
    if (hit) return hit;
  }
  return null;
};

const cleanName = (n: string): string => decodeEntities(n).split(/\s[-–—|]\s/)[0]?.trim() || n;

const main = async (): Promise<void> => {
  mkdirSync(DATA, { recursive: true });
  const gyms = (JSON.parse(readFileSync(join(DATA, 'tx-bjj-decodo.json'), 'utf8')) as Discovered[]).filter((g) => g.openMat.hosts);
  const docs: OpenMatDoc[] = [];
  const now = new Date().toISOString();

  for (const g of gyms) {
    const html = (await pfetch(g.website)) ?? '';
    let extra = '';
    for (const p of ['schedule', 'classes', 'open-mat', 'schedules', 'contact']) {
      if (/open[\s-]?mat/i.test(html) && ADDR.test(html)) break;
      const h = await pfetch(new URL('/' + p, g.website).href);
      if (h) extra += ' ' + h;
      await sleep(200);
    }
    const full = html + extra;
    const om = parseOpenMat(full);
    const addr = scrapeAddress(full);
    let lat: number | null = null, lng: number | null = null;
    const gc = await geocodeBest([
      addr ? `${addr.address}, ${addr.city}, TX ${addr.postalCode}` : '',
      addr ? `${addr.city}, TX ${addr.postalCode}` : '',
      `${cleanName(g.name)}, ${addr?.city ?? g.city}, TX`,
    ]);
    if (gc) { lat = gc.lat; lng = gc.lng; }
    const gymId = randomUUID();
    const title = om.gi === 'nogi' ? 'No-Gi Open Mat' : om.gi === 'gi' ? 'Gi Open Mat' : 'Open Mat';
    // Specific day found -> one doc. Otherwise assume daily -> one recurring doc per weekday.
    const assumedDaily = om.day === null;
    const days = assumedDaily ? [0, 1, 2, 3, 4, 5, 6] : [om.day as number];
    for (const dow of days) {
      const id = randomUUID();
      docs.push({
        _id: id, id, gymId, hostId: null,
        title,
        description: assumedDaily ? 'Open mat (assumed daily — confirm times with the gym).' : 'Open mat — visitors welcome; confirm details with the gym.',
        dayOfWeek: dow, startTime: om.start, endTime: om.end,
        isRecurring: true, specificDate: null, maxParticipants: null, skillLevel: 'all', giType: om.gi,
        isCancelled: false, verified: false, status: 'live', feeCents: 0, attendeeCount: 0,
        gymName: cleanName(g.name), latitude: lat, longitude: lng,
        address: addr?.address ?? null, city: addr?.city ?? g.city, state: 'TX', postalCode: addr?.postalCode ?? null,
        gymRating: null, createdAt: now, gymOwnerId: null,
        geo: lat !== null && lng !== null ? { type: 'Point', coordinates: [lng, lat] } : null,
      });
    }
     
    console.log(`  ${cleanName(g.name).slice(0, 30).padEnd(30)} day=${assumedDaily ? 'DAILY' : om.day} ${om.start ?? '?'}-${om.end ?? '?'} gi=${om.gi} geo=${lat !== null}`);
    await sleep(150);
  }

  writeFileSync(join(DATA, 'tx-openmats.json'), JSON.stringify(docs, null, 2));
  const wDay = docs.filter((d) => d.dayOfWeek !== null).length;
  const wTime = docs.filter((d) => d.startTime).length;
  const wGeo = docs.filter((d) => d.geo).length;
   
  console.log(`\nOpenMat docs: ${docs.length} | with day: ${wDay} | with time: ${wTime} | geocoded: ${wGeo}`);
   
  console.log(`Wrote ${join(DATA, 'tx-openmats.json')}`);
};

await main();
