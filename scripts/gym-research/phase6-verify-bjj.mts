/**
 * Phase 6 — Website precision check (Place Details for URLs + Decodo for fetch).
 *
 * The recall pass (3b) let in non-BJJ schools (e.g. "Rogers Martial Arts" =
 * karate only). For every ambiguous gym (name lacks a jiu-jitsu/brand signal):
 *   1. get its website URL via Google Place Details (field=website), and
 *   2. fetch that site — direct first, Decodo residential proxy on failure
 *      (Cloudflare / anti-bot) — then scan for BJJ evidence.
 *
 * Classifies bjj / not-bjj / unknown. Resumable: checkpoints each gym.
 * Run: bun run scripts/gym-research/phase6-verify-bjj.mts
 */
import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
const OUT = join(DATA, 'bjj-verify.json');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';
const envFile = readFileSync(join(import.meta.dir, '..', '..', 'apps', 'api', '.env'), 'utf8');
const envVal = (k: string): string => (envFile.match(new RegExp(`^${k}=(.*)$`, 'm'))?.[1] ?? '').trim().replace(/^["']|["']$/g, '');
const KEY = envVal('MAPS_API_KEY');
const PROXY = envVal('DECODO_PROXY_URL');

const SIGNAL = /jiu|jitsu|\bbjj\b|grappl|gracie|10th planet|checkmat|atos|carlson|renzo|rilion|machado|soul fighters|caio terra|marcelo|nova uniao|alliance|zenith|brasa|gf team|caveirinha|progresso/i;
const BJJ_TERMS = /jiu[\s-]?jitsu|\bbjj\b|grappling|gracie|no[\s-]?gi|brazilian jiu|submission grappling/i;
const OTHER_ART = /tae ?kwon|taekwondo|\bkarate\b|krav maga|\bjudo\b|aikido|kung ?fu|\bboxing\b/i;
const HIGHRISK = /black belt|tae ?kwon|taekwondo|\bkarate\b|\bkung ?fu\b|little ninja|tiny tigers|\bata\b/i;
const LIKELY = /\bmma\b|mixed martial|fight|combat|submission|wrestl|\bteam\b|muay|striking/i;

interface Gym { _id: string; name: string; city?: string; state?: string; website?: string; googlePlaceId?: string; }
interface Verdict { _id: string; name: string; city: string; url: string | null; verdict: 'bjj' | 'not-bjj' | 'unknown'; prior: 'high-risk' | 'likely' | 'plain'; note: string; }

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
const prior = (n: string): Verdict['prior'] => (HIGHRISK.test(n) ? 'high-risk' : LIKELY.test(n) ? 'likely' : 'plain');

const websiteFor = async (placeId: string): Promise<string | null> => {
  try {
    const res = await fetch(`https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=website&key=${KEY}`);
    const j = (await res.json()) as { result?: { website?: string } };
    return j.result?.website ?? null;
  } catch { return null; }
};

const fetchText = async (url: string): Promise<string | null> => {
  const opts: RequestInit = { headers: { 'User-Agent': UA }, redirect: 'follow', signal: AbortSignal.timeout(15000) };
  try {
    const r = await fetch(url, opts);
    if (r.ok) return (await r.text());
  } catch { /* fall through to proxy */ }
  try {
    const r = await fetch(url, { ...opts, proxy: PROXY } as RequestInit);
    if (r.ok) return (await r.text());
  } catch { /* give up */ }
  return null;
};

const scan = (html: string): 'bjj' | 'not-bjj' | 'unknown' => {
  const text = html.replace(/<[^>]+>/g, ' ');
  if (BJJ_TERMS.test(text)) return 'bjj';
  if (OTHER_ART.test(text)) return 'not-bjj';
  return 'unknown';
};

const main = async (): Promise<void> => {
  mkdirSync(DATA, { recursive: true });
  const gyms = JSON.parse(readFileSync(join(DATA, 'gyms.seed.json'), 'utf8')) as Gym[];
  const ambiguous = gyms.filter((g) => !SIGNAL.test(g.name));

  const done = new Map<string, Verdict>();
  if (existsSync(OUT)) for (const v of JSON.parse(readFileSync(OUT, 'utf8')) as Verdict[]) done.set(v._id, v);

  let n = 0, details = 0;
  for (const g of ambiguous) {
    if (done.has(g._id)) continue;
    n++;
    let url: string | null = g.website ?? null;
    if (!url && g.googlePlaceId) { url = await websiteFor(g.googlePlaceId); details++; }
    let verdict: Verdict['verdict'] = 'unknown';
    let note = '';
    if (url) { const html = await fetchText(url); if (html) verdict = scan(html); else note = 'fetch failed'; }
    else note = 'no website on google';
    done.set(g._id, { _id: g._id, name: g.name, city: g.city ?? '', url, verdict, prior: prior(g.name), note });
    if (n % 5 === 0) {
      writeFileSync(OUT, JSON.stringify([...done.values()], null, 2));
       
      console.log(`[${done.size}/${ambiguous.length}] ${g.name.slice(0, 32).padEnd(32)} -> ${verdict}${note ? ' (' + note + ')' : ''}`);
    }
    await sleep(200);
  }
  writeFileSync(OUT, JSON.stringify([...done.values()], null, 2));
  const all = [...done.values()];
  const c = (v: string): number => all.filter((x) => x.verdict === v).length;
   
  console.log(`\nDONE ${all.length}. bjj:${c('bjj')} not-bjj:${c('not-bjj')} unknown:${c('unknown')} | place-details calls:${details} (~$${(details * 17 / 1000).toFixed(2)})`);
};

await main();
