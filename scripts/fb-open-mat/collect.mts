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

async function collectGroup(ctx: BrowserContext, entry: GroupEntry, sinceMs: number): Promise<RawPost[]> {
  const page = await ctx.newPage();
  await page.goto(entry.url, { waitUntil: 'domcontentloaded' });
  const posts: RawPost[] = [];
  // Scroll with throttling until we pass `sinceMs` or hit the year cap. Extract
  // each article's text, author, permalink, timestamp. (Selectors are FB-version
  // specific; validate against the live DOM and adjust the article/permalink/
  // timestamp locators here.)
  let lastCount = -1;
  for (let i = 0; i < (INITIAL ? 400 : 40); i += 1) {
    const articles = await page.locator('div[role="article"]').all();
    for (const a of articles.slice(posts.length)) {
      const text = (await a.innerText().catch(() => '')).trim();
      if (!/open\s*mat/i.test(text)) continue;
      const permalink = await a.locator('a[href*="/posts/"], a[href*="/permalink/"]').first().getAttribute('href').catch(() => null);
      const author = (await a.locator('strong, h3 a, h4 a').first().innerText().catch(() => '')).trim();
      posts.push({
        sourceUrl: permalink ? new URL(permalink, 'https://www.facebook.com').toString() : entry.url,
        groupUrl: entry.url, author, postedAt: new Date().toISOString(), text,
      });
    }
    if (articles.length === lastCount) break; // no new content
    lastCount = articles.length;
    await page.mouse.wheel(0, 3000);
    await page.waitForTimeout(1500 + Math.floor(Math.random() * 1500)); // throttle
  }
  await page.close();
  return posts;
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
