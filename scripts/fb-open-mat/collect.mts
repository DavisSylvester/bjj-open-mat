import { chromium, type BrowserContext } from 'playwright';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import type { GroupEntry, RawPost } from './lib/types.mjs';
import { CheckpointStore } from './lib/checkpoint.mjs';

const ROOT = join(import.meta.dir, '..', '..');
const OUT_DIR = join(ROOT, 'docs', 'open-mats');
const RAW_DIR = join(OUT_DIR, 'raw');
const XLSX_DIR = join(OUT_DIR, 'xlsx');
const SESSION = join(import.meta.dir, '.fb-session.json');
const INITIAL = process.argv.includes('--initial'); // ~1 year vs since-checkpoint
const ONE_YEAR_MS = 365 * 24 * 60 * 60 * 1000;

function today(): string { return new Date().toISOString().slice(0, 10); }
function slug(url: string): string { return url.replace(/[^a-z0-9]+/gi, '-').slice(0, 40); }

async function makeContext(): Promise<{ ctx: BrowserContext; headed: boolean }> {
  const hasSession = existsSync(SESSION);
  const browser = await chromium.launch({ headless: hasSession });
  const ctx = await browser.newContext(hasSession ? { storageState: SESSION } : {});
  return { ctx, headed: !hasSession };
}

async function ensureLoggedIn(ctx: BrowserContext): Promise<void> {
  const page = await ctx.newPage();
  await page.goto('https://www.facebook.com/');
  // If a saved session is invalid, the login form appears. Wait for the user
  // to complete login manually (headed), then persist the session.
  if (await page.locator('input[name="email"]').count() > 0) {
    console.log('Complete the Facebook login in the browser window…');
    await page.waitForURL((u) => !u.pathname.includes('login'), { timeout: 300000 });
    await ctx.storageState({ path: SESSION });
    console.log('Session saved.');
  }
  await page.close();
}

// Extracts top-level posts from a group. Validated against the live FB DOM
// (2026): posts are the children of `div[role="feed"]` (comments are nested
// `div[role="article"]` and are intentionally NOT matched here); post body is the
// longest `div[dir="auto"]`; the flyer is the largest content `<img>` (avatars /
// emoji / static chrome filtered out); the permalink is a best-effort `/posts/`
// or `/permalink/` anchor. FB virtualizes the feed (only a few posts in the DOM
// at once), so we accumulate across scroll passes, deduped by permalink/text/img.
//
// `_sinceMs` is the intended time floor; FB does not expose a reliable absolute
// post timestamp in the feed DOM, so the window is currently bounded by scroll
// depth (INITIAL vs daily) rather than a hard date cutoff.
async function collectGroup(ctx: BrowserContext, entry: GroupEntry, _sinceMs: number): Promise<RawPost[]> {
  const page = await ctx.newPage();
  await page.goto(entry.url, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);

  const seen = new Map<string, RawPost>();
  const grab = (): Promise<Array<{ text: string; img: string | null; permalink: string | null; author: string }>> =>
    page.evaluate(() => {
      const feed = document.querySelector('div[role="feed"]');
      if (!feed) return [];
      const out: Array<{ text: string; img: string | null; permalink: string | null; author: string }> = [];
      for (const c of Array.from(feed.children)) {
        const text = Array.from(c.querySelectorAll('div[dir="auto"]'))
          .map((e) => (e as HTMLElement).innerText)
          .filter(Boolean)
          .sort((a, b) => b.length - a.length)[0] || '';
        const img = Array.from(c.querySelectorAll('img'))
          .map((im) => ({ src: (im as HTMLImageElement).currentSrc || im.src, w: (im as HTMLImageElement).naturalWidth || im.width }))
          .filter((x) => x.src && x.src.startsWith('http') && x.w >= 130 && !/static\.xx|emoji|\/rsrc\.php/.test(x.src))
          .sort((a, b) => b.w - a.w)[0]?.src || null;
        const permalink = (Array.from(c.querySelectorAll('a[href]'))
          .map((a) => a.getAttribute('href'))
          .find((h) => /\/(posts|permalink)\//.test(h || '')) || '').split('?')[0] || null;
        const author = ((c.querySelector('h2 a, h3 a, h4 a, strong a') as HTMLElement | null)?.innerText || '').trim();
        if (text.length > 20 || img) out.push({ text: text.replace(/\s+/g, ' ').trim(), img, permalink, author });
      }
      return out;
    });

  let stagnant = 0;
  for (let i = 0; i < (INITIAL ? 300 : 40); i += 1) {
    const before = seen.size;
    for (const p of await grab()) {
      const key = p.permalink || p.text.slice(0, 100) || p.img || '';
      if (!key || seen.has(key)) continue;
      seen.set(key, {
        sourceUrl: p.permalink ? new URL(p.permalink, 'https://www.facebook.com').toString() : entry.url,
        groupUrl: entry.url, author: p.author, postedAt: new Date().toISOString(),
        text: p.text, imageUrl: p.img,
      });
    }
    stagnant = seen.size === before ? stagnant + 1 : 0;
    if (stagnant >= 4) break; // no new posts across several passes → end of feed
    await page.mouse.wheel(0, 2500);
    await page.waitForTimeout(1300 + Math.floor(Math.random() * 1200)); // throttle
  }
  await page.close();
  return [...seen.values()];
}

async function main(): Promise<void> {
  for (const d of [RAW_DIR, XLSX_DIR]) if (!existsSync(d)) mkdirSync(d, { recursive: true });
  const entries = JSON.parse(readFileSync(join(import.meta.dir, 'groups.json'), 'utf8')) as GroupEntry[];
  const checkpoints = new CheckpointStore(join(OUT_DIR, 'checkpoints.json'));
  const { ctx } = await makeContext();
  await ensureLoggedIn(ctx);

  for (const entry of entries) {
    const cpIso = checkpoints.get(entry.url);
    const sinceMs = INITIAL || !cpIso ? Date.now() - ONE_YEAR_MS : new Date(cpIso).getTime();
    console.log(`Collecting ${entry.url} (since ${new Date(sinceMs).toISOString()})…`);
    const posts = await collectGroup(ctx, entry, sinceMs);
    writeFileSync(join(RAW_DIR, `${slug(entry.url)}-${today()}.json`), JSON.stringify(posts, null, 2));
    checkpoints.set(entry.url, new Date().toISOString());
    console.log(`  ${posts.length} open-mat posts captured.`);
  }
  checkpoints.save();
  await ctx.browser()?.close();
  console.log(`Done. Raw posts in ${RAW_DIR}. Next: Stage 2 (parse) via the skill.`);
}

main().catch((e) => { console.error(e instanceof Error ? e.message : e); process.exit(1); });
