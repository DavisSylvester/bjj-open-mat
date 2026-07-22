/**
 * Phase 7 — Prune the seed using website verification (phase 6).
 *
 * Decisions:
 *   - name clearly signals BJJ (not in the ambiguous set) -> KEEP
 *   - website verdict 'bjj'      -> KEEP
 *   - website verdict 'not-bjj'  -> REMOVE (confirmed non-BJJ, e.g. karate)
 *   - website verdict 'unknown'  -> REMOVE if name prior is 'high-risk'
 *                                   (black belt/karate/TKD/ATA), else KEEP + flag
 *
 * Rewrites data/gyms.seed.json (pruned) and writes removed + review lists.
 * Run: bun run scripts/gym-research/phase7-prune.mts
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DATA = join(import.meta.dir, 'data');
interface Gym { _id: string; name: string; city?: string; state?: string; [k: string]: unknown; }
interface Verdict { _id: string; verdict: 'bjj' | 'not-bjj' | 'unknown'; prior: 'high-risk' | 'likely' | 'plain'; url: string | null; }

const seed = JSON.parse(readFileSync(join(DATA, 'gyms.seed.json'), 'utf8')) as Gym[];
const verds = new Map<string, Verdict>();
for (const v of JSON.parse(readFileSync(join(DATA, 'bjj-verify.json'), 'utf8')) as Verdict[]) verds.set(v._id, v);

const kept: Gym[] = [];
const removed: { name: string; city: string; reason: string; url: string | null }[] = [];
const review: { name: string; city: string; prior: string; url: string | null }[] = [];

// Backfill the website discovered during verification (Place Details), normalized
// to the site root, when the seed doc doesn't already have one.
const siteRoot = (u: string | null): string | undefined => {
  if (!u) return undefined;
  try { return new URL(u).origin + '/'; } catch { return undefined; }
};

let backfilled = 0;
for (const g of seed) {
  const v = verds.get(g._id);
  if (!v) { kept.push(g); continue; } // clear-BJJ by name — keep
  if (v.verdict === 'not-bjj') { removed.push({ name: g.name, city: g.city ?? '', reason: 'website: non-BJJ', url: v.url }); continue; }
  if (v.verdict === 'unknown' && v.prior === 'high-risk') { removed.push({ name: g.name, city: g.city ?? '', reason: 'unknown + high-risk name', url: v.url }); continue; }
  // kept (bjj, or non-high-risk unknown) — backfill website if missing
  if (!g['website'] && v.url) { const root = siteRoot(v.url); if (root) { g['website'] = root; backfilled++; } }
  kept.push(g);
  if (v.verdict === 'unknown') review.push({ name: g.name, city: g.city ?? '', prior: v.prior, url: v.url });
}

writeFileSync(join(DATA, 'gyms.seed.json'), JSON.stringify(kept, null, 2));
writeFileSync(join(DATA, 'phase7-removed.json'), JSON.stringify(removed, null, 2));
writeFileSync(join(DATA, 'phase7-review.json'), JSON.stringify(review, null, 2));

const states: Record<string, number> = {};
for (const g of kept) states[(g.state as string) ?? '??'] = (states[(g.state as string) ?? '??'] ?? 0) + 1;
 
console.log(`Before: ${seed.length} | removed: ${removed.length} | kept: ${kept.length} | websites backfilled: ${backfilled}`);
 
console.log(`  removed = ${removed.filter((r) => r.reason.startsWith('website')).length} confirmed non-BJJ + ${removed.filter((r) => !r.reason.startsWith('website')).length} high-risk unknowns`);
 
console.log(`  kept-but-flagged for review (unknown, non-high-risk): ${review.length}`);
 
console.log(`  states: ${JSON.stringify(states)}`);
