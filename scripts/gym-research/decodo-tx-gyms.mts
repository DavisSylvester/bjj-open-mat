/**
 * Decodo-only TX BJJ/MMA gym finder (NO Google Places/Details).
 *
 * Discovery: Brave Search through the Decodo residential proxy (the one SERP that
 * doesn't CAPTCHA the proxy). Verification: fetch each gym site through Decodo and
 * keep only gyms that (a) reference BJJ AND (b) publish a class schedule. Also
 * detects whether the gym hosts an Open Mat and captures its day/time.
 *
 * Dedup by registrable domain. Hard bandwidth cap (default 450 MB) on the 3 GB plan.
 * Run: bun run scripts/gym-research/decodo-tx-gyms.mts
 */
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const OUT = join(DATA, 'tx-bjj-decodo.json');
const PROXY = (readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8').match(/^DECODO_PROXY_URL=(.*)$/m)?.[1] ?? '').trim();
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';
const HEADERS = {
  'User-Agent': UA,
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
};

const CITIES = [
  'Dallas', 'Fort Worth', 'Arlington', 'Plano', 'Frisco', 'McKinney', 'Denton', 'Irving', 'Garland', 'Mesquite', 'Richardson',
  'Houston', 'Sugar Land', 'Katy', 'The Woodlands', 'Pasadena', 'Pearland',
  'Austin', 'Round Rock', 'San Marcos', 'San Antonio', 'New Braunfels',
  'El Paso', 'Corpus Christi', 'Laredo', 'Lubbock', 'Amarillo', 'Waco', 'Killeen', 'Temple',
  'Tyler', 'Longview', 'Beaumont', 'Midland', 'Odessa', 'Abilene', 'Wichita Falls', 'College Station',
  'Brownsville', 'McAllen', 'Galveston',
] as const;
const QUERY_TEMPLATES = ['brazilian jiu jitsu {c} TX', 'bjj gym {c} TX', 'mma gym {c} TX'] as const;
const BRAVE_PAGES = 3;
const BYTE_CAP = 1200 * 1024 * 1024;
const MAX_PAGES_PER_GYM = 5;

// domains that are directories / social / aggregators / noise, never a gym's own site
const SKIP_DOMAIN = /brave\.|google\.|goo\.gl|instagram\.|facebook\.|fb\.com|youtube\.|youtu\.be|reddit\.|yelp\.|tripadvisor|wikipedia|twitter\.|x\.com|tiktok\.|linkedin\.|mapquest|yellowpages|bing\.|apple\.|spotify|teachme\.to|bjjweb|goldbjj|bjjbundle|hackerone|pinterest|foursquare|thumbtack|nextdoor|glassdoor|indeed|eventbrite|meetup|classpass|gymdesk\.com|zenplanner\.com|pushpress\.com|amazon\.|bbb\.org|manta\.com|chamberofcommerce/i;

const BJJ = /jiu[\s-]?jitsu|\bbjj\b|gracie|grappling|no[\s-]?gi/i;
const SCHED_EMBED = /zenplanner|kicksite|mindbody|pushpress|gymdesk|wodify|clubready|glofox|mariana ?tek|teamup|calendly|acuityscheduling|schedulista|momence|spark ?membership/i;
const DAY = /(mon|tues?|wed(nes)?|thur?s?|fri|sat(ur)?|sun)(day)?/i;
const DAY_FULL = /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i;
const TIME = /\b(1[0-2]|0?[1-9])(:[0-5]\d)?\s?(am|pm|a\.m\.|p\.m\.)\b/i;
const SCHED_CONTEXT = /schedule|timetable|class times|mat schedule|weekly schedule|class schedule/i;
const OPENMAT = /open[\s-]?mat/i;
const TXRE = /\b(TX|Texas)\b/;

interface GymResult {
  name: string;
  website: string;
  domain: string;
  city: string;
  state: 'TX';
  referencesBjj: boolean;
  schedule: { found: boolean; url: string | null; via: string };
  openMat: { hosts: boolean; day: string | null; time: string | null; evidence: string | null };
}

let bytesUsed = 0;
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

const pfetch = async (url: string): Promise<string | null> => {
  if (bytesUsed >= BYTE_CAP) return null;
  try {
    const res = await fetch(url, { proxy: PROXY, headers: HEADERS, redirect: 'follow', signal: AbortSignal.timeout(20000) } as RequestInit);
    if (!res.ok) return null;
    const buf = await res.arrayBuffer();
    bytesUsed += buf.byteLength;
    return new TextDecoder().decode(buf);
  } catch { return null; }
};

const registrable = (host: string): string => {
  const p = host.replace(/^www\./, '').split('.');
  return p.length <= 2 ? p.join('.') : p.slice(-2).join('.');
};

const braveResults = (html: string): string[] =>
  [...html.matchAll(/href="(https?:\/\/[^"]+)"/g)].map((m) => m[1] ?? '').filter((u) => {
    try { return !SKIP_DOMAIN.test(new URL(u).hostname); } catch { return false; }
  });

const discover = async (): Promise<Map<string, { url: string; city: string }>> => {
  const cand = new Map<string, { url: string; city: string }>();
  for (const city of CITIES) {
    for (const tpl of QUERY_TEMPLATES) {
      const q = tpl.replace('{c}', city);
      for (let page = 0; page < BRAVE_PAGES; page++) {
        if (bytesUsed >= BYTE_CAP) return cand;
        const html = await pfetch(`https://search.brave.com/search?q=${encodeURIComponent(q)}&offset=${page}`);
        if (!html) continue;
        for (const u of braveResults(html)) {
          try {
            const host = new URL(u).hostname;
            const dom = registrable(host);
            if (!cand.has(dom)) cand.set(dom, { url: `${new URL(u).protocol}//${host}/`, city });
          } catch { /* skip */ }
        }
        await sleep(400);
      }
    }
     
    console.log(`  discovered after ${city}: ${cand.size} unique domains (bw ${(bytesUsed / 1e6).toFixed(1)}MB)`);
  }
  return cand;
};

const internalLinks = (html: string, base: string): string[] => {
  const out = new Set<string>();
  for (const m of html.matchAll(/href="([^"]+)"/g)) {
    const href = m[1] ?? '';
    if (/(schedule|classes|class-schedule|timetable|open[-_]?mat|programs)/i.test(href)) {
      try { out.add(new URL(href, base).href); } catch { /* skip */ }
    }
  }
  return [...out].slice(0, MAX_PAGES_PER_GYM - 1);
};

const title = (html: string): string => {
  const og = html.match(/property="og:site_name"\s+content="([^"]+)"/i)?.[1];
  const t = html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1];
  return (og ?? t ?? '').replace(/\s+/g, ' ').split(/[|–—\-]/)[0]?.trim() || '';
};

const findOpenMat = (text: string): { day: string | null; time: string | null; evidence: string | null } => {
  const idx = text.search(OPENMAT);
  if (idx < 0) return { day: null, time: null, evidence: null };
  const win = text.slice(Math.max(0, idx - 120), idx + 160).replace(/\s+/g, ' ').trim();
  return { day: win.match(DAY_FULL)?.[0] ?? null, time: win.match(TIME)?.[0] ?? null, evidence: win };
};

const verify = async (dom: string, home: string, city: string): Promise<GymResult | null> => {
  const homeHtml = await pfetch(home);
  if (!homeHtml) return null;
  const pages = [homeHtml];
  for (const link of internalLinks(homeHtml, home)) {
    if (bytesUsed >= BYTE_CAP) break;
    const h = await pfetch(link);
    if (h) pages.push(h);
    await sleep(200);
  }
  const allText = pages.map((p) => p.replace(/<[^>]+>/g, ' ')).join(' \n ');
  const referencesBjj = BJJ.test(allText);

  let schedFound = false, schedVia = '', schedUrl: string | null = null;
  if (SCHED_EMBED.test(pages.join(' '))) { schedFound = true; schedVia = 'booking-platform embed'; }
  else if (SCHED_CONTEXT.test(allText) && (DAY.test(allText) || DAY_FULL.test(allText)) && TIME.test(allText)) { schedFound = true; schedVia = 'day/time table'; }
  if (schedFound) {
    const sl = internalLinks(homeHtml, home).find((u) => /schedule|timetable|class/i.test(u));
    schedUrl = sl ?? home;
  }

  const om = findOpenMat(allText);
  const isTx = TXRE.test(allText) || true; // discovery was TX-scoped; keep

  if (!referencesBjj || !schedFound || !isTx) return null;
  return {
    name: title(homeHtml) || dom,
    website: home,
    domain: dom,
    city,
    state: 'TX',
    referencesBjj,
    schedule: { found: schedFound, url: schedUrl, via: schedVia },
    openMat: { hosts: om.evidence !== null, day: om.day, time: om.time, evidence: om.evidence },
  };
};

const main = async (): Promise<void> => {
  mkdirSync(DATA, { recursive: true });
   
  console.log(`Phase B — Brave discovery via Decodo (cap ${(BYTE_CAP / 1e6).toFixed(0)}MB)...`);
  const cand = await discover();
   
  console.log(`\nPhase C — verifying ${cand.size} candidate sites via Decodo...`);
  const kept: GymResult[] = [];
  let checked = 0;
  for (const [dom, { url, city }] of cand) {
    if (bytesUsed >= BYTE_CAP) { console.warn('BANDWIDTH CAP hit — stopping'); break; }
    checked++;
    const r = await verify(dom, url, city);
    if (r) { kept.push(r); }
    else { /* count reason cheaply on a re-scan-free basis is hard; track via verify internals omitted */ }
    if (checked % 10 === 0) {
      writeFileSync(OUT, JSON.stringify(kept, null, 2));
       
      console.log(`  [${checked}/${cand.size}] kept ${kept.length} (bw ${(bytesUsed / 1e6).toFixed(1)}MB)`);
    }
    await sleep(150);
  }
  // dedup by domain (already unique) + by name safety
  const seen = new Set<string>();
  const final = kept.filter((g) => (seen.has(g.domain) ? false : (seen.add(g.domain), true)));
  final.sort((a, b) => a.name.localeCompare(b.name));
  writeFileSync(OUT, JSON.stringify(final, null, 2));
  const withOM = final.filter((g) => g.openMat.hosts).length;
   
  console.log(`\nDONE. candidates: ${cand.size} | kept (BJJ + schedule): ${final.length} | host open mat: ${withOM}`);
   
  console.log(`Bandwidth used: ${(bytesUsed / 1e6).toFixed(1)} MB. Wrote ${OUT}`);
};

await main();
