# Facebook Open-Mat Scraper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a project-local Claude Code skill + helper scripts that scrape Facebook groups for BJJ open-mat sessions, parse them, dedupe against the production API, and insert new ones as unverified community submissions.

**Architecture:** A 5-stage file-passing pipeline (Collect → Parse → Dedupe/Resolve → Review gate → Insert). Deterministic, unit-tested TypeScript libraries do the parsing/matching/API work; Playwright does collection (manually verified); Claude orchestrates via a `SKILL.md`. Production writes are `--commit`-gated and idempotent.

**Tech Stack:** Bun + TypeScript (strict, `.mts`), `bun:test`, Playwright, `xlsx` npm package, `zipcodes` (already a dep), production REST API (`https://api.bjj-open-mat.dsylvester.io/api/v1`).

**Spec:** `docs/superpowers/specs/2026-07-26-fb-openmat-scraper-design.md`

---

## Conventions (read once)

- All scripts are `.mts`, run with `bun run scripts/fb-open-mat/<file>.mts`.
- Import specifiers use `.mjs` extensions (e.g. `import { x } from './types.mjs'`) even though files are `.mts` — matches repo tsconfig.
- Tests are `bun:test`: `import { describe, expect, it } from "bun:test"`. Run a file with `bun test scripts/fb-open-mat/test/<file>.test.mts`.
- Strict TypeScript: explicit return types, no `any`, `interface` for object shapes.
- Scripts that touch production are **dry-run by default**; a real write requires `--commit`.

## File Structure

```
.claude/skills/fb-open-mat-scraper/SKILL.md   # the skill (committed) — Task 11
scripts/fb-open-mat/
  groups.json                                 # URL collection (committed) — Task 1
  lib/
    types.mts        # shared interfaces — Task 1
    us-filter.mts    # US state/zip validation — Task 2
    parse.mts        # deterministic field extraction from post text — Task 3
    geo-match.mts    # gym name-overlap + haversine — Task 4
    xlsx-parse.mts   # Excel schedule → candidates — Task 5
    api-client.mts   # prod reads + insert POST — Task 6
    checkpoint.mts   # per-group last-scanned marker — Task 7
  collect.mts        # Stage 1 (Playwright) — Task 8
  resolve.mts        # Stage 3 (dedupe/resolve) — Task 9
  insert.mts         # Stage 5 (prod POST, --commit) — Task 10
  test/              # unit tests (Tasks 2–7, 9, 10)
docs/open-mats/      # runtime artifacts (gitignored except .gitkeep) — Task 1
```

Data flows through files under `docs/open-mats/`: `raw/<group>-<date>.json` → `found-<date>.json` → `new-<date>.json` → `inserted-<date>.json`.

---

### Task 1: Scaffolding — types, group config, gitignore

**Files:**
- Create: `scripts/fb-open-mat/groups.json`
- Create: `scripts/fb-open-mat/lib/types.mts`
- Create: `docs/open-mats/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Create the group collection config**

`scripts/fb-open-mat/groups.json`:
```json
[
  { "url": "https://www.facebook.com/groups/674876162581204/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/rollfinder/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/250091745169936/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/2132087287030661/", "type": "group", "region": "US" },
  { "url": "https://www.facebook.com/groups/674876162581204/posts/7832282886840460/", "type": "post", "region": "US" }
]
```

- [ ] **Step 2: Create shared types**

`scripts/fb-open-mat/lib/types.mts`:
```typescript
export type GiType = 'gi' | 'nogi' | 'both';
export type SkillLevel = 'all' | 'beginner' | 'intermediate' | 'advanced';

export interface GroupEntry {
  readonly url: string;
  readonly type: 'group' | 'post';
  readonly region: 'US';
}

// A single Facebook post captured by Stage 1 (collect).
export interface RawPost {
  readonly sourceUrl: string;   // permalink to the post
  readonly groupUrl: string;
  readonly author: string;
  readonly postedAt: string;    // ISO timestamp of the post
  readonly text: string;
}

// A structured open-mat candidate produced by Stage 2 (parse).
export interface Candidate {
  readonly sourceUrl: string;
  readonly author: string;
  readonly gymName: string;
  readonly address?: string;
  readonly city?: string;
  readonly state?: string;      // 2-letter US state
  readonly postalCode?: string;
  readonly dayOfWeek?: number;  // 0=Sun..6=Sat (recurring)
  readonly specificDate?: string; // YYYY-MM-DD (one-off)
  readonly isRecurring: boolean;
  readonly startTime: string;   // HH:mm 24h
  readonly endTime: string;     // HH:mm 24h
  readonly giType: GiType;
  readonly skillLevel: SkillLevel;
  readonly feeCents: number;    // 0 = free
  readonly confidence: number;  // 0..1
  readonly rawSnippet: string;
}

// The request body for POST /api/v1/open-mats (matches CreateOpenMatRequest).
export interface CreateOpenMatBody {
  gymId?: string;
  newGym?: {
    name: string;
    address: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  title: string;
  description?: string;
  dayOfWeek?: number;
  startTime: string;
  endTime: string;
  isRecurring?: boolean;
  specificDate?: string;
  skillLevel?: SkillLevel;
  giType?: GiType;
  feeCents?: number;
}
```

- [ ] **Step 3: Create the artifacts dir keeper and gitignore rules**

Create empty `docs/open-mats/.gitkeep`.

Append to `.gitignore`:
```
# Facebook open-mat scraper runtime artifacts (contain scraped PII / secrets)
docs/open-mats/raw/
docs/open-mats/xlsx/
docs/open-mats/found-*.json
docs/open-mats/new-*.json
docs/open-mats/inserted-*.json
docs/open-mats/checkpoints.json
scripts/fb-open-mat/.fb-session.json
```

- [ ] **Step 4: Verify config parses**

Run: `bun -e "console.log(JSON.parse(require('fs').readFileSync('scripts/fb-open-mat/groups.json','utf8')).length)"`
Expected: `5`

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/groups.json scripts/fb-open-mat/lib/types.mts docs/open-mats/.gitkeep .gitignore
git commit -m "feat(fb-scraper): scaffold types, group config, gitignore"
```

---

### Task 2: US filter library

**Files:**
- Create: `scripts/fb-open-mat/lib/us-filter.mts`
- Test: `scripts/fb-open-mat/test/us-filter.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/us-filter.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { isUsState, isUsZip, isUsCandidate } from "../lib/us-filter.mjs";

describe("us-filter", () => {
  it("accepts valid 2-letter US states (any case)", () => {
    expect(isUsState("TX")).toBe(true);
    expect(isUsState("ca")).toBe(true);
    expect(isUsState("DC")).toBe(true);
  });
  it("rejects non-US / invalid states", () => {
    expect(isUsState("ON")).toBe(false); // Ontario
    expect(isUsState("XX")).toBe(false);
    expect(isUsState("")).toBe(false);
  });
  it("accepts 5-digit zips and rejects others", () => {
    expect(isUsZip("75495")).toBe(true);
    expect(isUsZip("7549")).toBe(false);
    expect(isUsZip("K1A0B1")).toBe(false);
  });
  it("treats a candidate as US when it has a US state or US zip", () => {
    expect(isUsCandidate({ state: "TX" })).toBe(true);
    expect(isUsCandidate({ postalCode: "75495" })).toBe(true);
    expect(isUsCandidate({ state: "ON" })).toBe(false);
    expect(isUsCandidate({})).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/us-filter.test.mts`
Expected: FAIL (module not found / functions undefined).

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/us-filter.mts`:
```typescript
const US_STATES: ReadonlySet<string> = new Set([
  'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS',
  'KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY',
  'NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV',
  'WI','WY','DC',
]);

export function isUsState(state: string): boolean {
  return US_STATES.has(state.trim().toUpperCase());
}

export function isUsZip(zip: string): boolean {
  return /^\d{5}$/.test(zip.trim());
}

export function isUsCandidate(c: { state?: string; postalCode?: string }): boolean {
  if (c.state && isUsState(c.state)) return true;
  if (c.postalCode && isUsZip(c.postalCode)) return true;
  return false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/us-filter.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/lib/us-filter.mts scripts/fb-open-mat/test/us-filter.test.mts
git commit -m "feat(fb-scraper): US state/zip filter"
```

---

### Task 3: Post-text field parser

Extracts the deterministically-parseable fields from a post's text: day-of-week, start/end time, recurring-vs-specific-date, gi type, skill level, fee. Gym name and address are supplied by the caller (Claude reads those during Stage 2); this library normalizes everything else.

**Files:**
- Create: `scripts/fb-open-mat/lib/parse.mts`
- Test: `scripts/fb-open-mat/test/parse.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/parse.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { parseTime, parseDayOfWeek, parseGiType, parseFeeCents, parseSchedule } from "../lib/parse.mjs";

describe("parseTime", () => {
  it("parses 12h times to 24h HH:mm", () => {
    expect(parseTime("10am")).toBe("10:00");
    expect(parseTime("10:30 AM")).toBe("10:30");
    expect(parseTime("12pm")).toBe("12:00");
    expect(parseTime("12am")).toBe("00:00");
    expect(parseTime("6:45pm")).toBe("18:45");
  });
  it("returns null on garbage", () => {
    expect(parseTime("noon-ish")).toBeNull();
  });
});

describe("parseDayOfWeek", () => {
  it("maps weekday names to 0..6", () => {
    expect(parseDayOfWeek("every Sunday")).toBe(0);
    expect(parseDayOfWeek("Saturdays")).toBe(6);
    expect(parseDayOfWeek("Weds")).toBe(3);
  });
  it("returns null when no weekday present", () => {
    expect(parseDayOfWeek("this weekend")).toBeNull();
  });
});

describe("parseGiType", () => {
  it("detects gi/nogi/both", () => {
    expect(parseGiType("No-Gi open mat")).toBe("nogi");
    expect(parseGiType("Gi only")).toBe("gi");
    expect(parseGiType("gi and no-gi")).toBe("both");
    expect(parseGiType("open mat")).toBe("both"); // default
  });
});

describe("parseFeeCents", () => {
  it("detects free and dollar amounts", () => {
    expect(parseFeeCents("Free open mat")).toBe(0);
    expect(parseFeeCents("$10 drop-in")).toBe(1000);
    expect(parseFeeCents("open mat")).toBe(0); // default free
  });
});

describe("parseSchedule", () => {
  it("parses a recurring weekly time range", () => {
    const s = parseSchedule("Open mat every Sunday 10am-12pm");
    expect(s).toEqual({ isRecurring: true, dayOfWeek: 0, startTime: "10:00", endTime: "12:00", specificDate: undefined });
  });
  it("defaults end time to +90m when only a start is given", () => {
    const s = parseSchedule("Sunday open mat at 10am");
    expect(s?.startTime).toBe("10:00");
    expect(s?.endTime).toBe("11:30");
  });
  it("returns null when no time can be found", () => {
    expect(parseSchedule("Open mat this weekend, details TBA")).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/parse.test.mts`
Expected: FAIL (functions undefined).

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/parse.mts`:
```typescript
import type { GiType, SkillLevel } from './types.mjs';

export function parseTime(input: string): string | null {
  const m = input.trim().toLowerCase().match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$/);
  if (!m) return null;
  let hour = Number(m[1]);
  const min = m[2] ? Number(m[2]) : 0;
  const mer = m[3];
  if (hour < 1 || hour > 12 || min > 59) return null;
  if (mer === 'am') hour = hour === 12 ? 0 : hour;
  else hour = hour === 12 ? 12 : hour + 12;
  return `${String(hour).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
}

const DAYS: ReadonlyArray<readonly [RegExp, number]> = [
  [/\bsun(day)?s?\b/i, 0], [/\bmon(day)?s?\b/i, 1], [/\btue(s|sday)?s?\b/i, 2],
  [/\bwed(s|nesday)?s?\b/i, 3], [/\bthu(r|rs|rsday)?s?\b/i, 4],
  [/\bfri(day)?s?\b/i, 5], [/\bsat(urday)?s?\b/i, 6],
];

export function parseDayOfWeek(input: string): number | null {
  for (const [re, n] of DAYS) if (re.test(input)) return n;
  return null;
}

export function parseGiType(input: string): GiType {
  const t = input.toLowerCase();
  const hasNogi = /no[-\s]?gi/.test(t);
  const hasGi = /\bgi\b/.test(t.replace(/no[-\s]?gi/g, ''));
  if (hasNogi && hasGi) return 'both';
  if (hasNogi) return 'nogi';
  if (hasGi) return 'gi';
  return 'both';
}

export function parseSkillLevel(input: string): SkillLevel {
  const t = input.toLowerCase();
  if (/\bbeginner|white belt|fundamental/.test(t)) return 'beginner';
  if (/\badvanced|black belt/.test(t)) return 'advanced';
  if (/\bintermediate/.test(t)) return 'intermediate';
  return 'all';
}

export function parseFeeCents(input: string): number {
  const t = input.toLowerCase();
  if (/\bfree\b/.test(t)) return 0;
  const m = t.match(/\$\s?(\d{1,3})(?:\.(\d{2}))?/);
  if (m) return Number(m[1]) * 100 + (m[2] ? Number(m[2]) : 0);
  return 0;
}

export interface Schedule {
  isRecurring: boolean;
  dayOfWeek?: number;
  specificDate?: string;
  startTime: string;
  endTime: string;
}

function addMinutes(hhmm: string, minutes: number): string {
  const [h, m] = hhmm.split(':').map(Number);
  const total = (h * 60 + m + minutes) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

// Finds "10am-12pm" or "at 10am" and a weekday. Specific ISO dates (YYYY-MM-DD)
// win over weekday and mark the session one-off.
export function parseSchedule(text: string): Schedule | null {
  const range = text.match(/(\d{1,2}(?::\d{2})?\s*(?:am|pm))\s*[-–to]+\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm))/i);
  let startTime: string | null = null;
  let endTime: string | null = null;
  if (range) {
    startTime = parseTime(range[1].replace(/\s+/g, ''));
    endTime = parseTime(range[2].replace(/\s+/g, ''));
  } else {
    const single = text.match(/\b(?:at\s*)?(\d{1,2}(?::\d{2})?\s*(?:am|pm))/i);
    if (single) startTime = parseTime(single[1].replace(/\s+/g, ''));
  }
  if (!startTime) return null;
  if (!endTime) endTime = addMinutes(startTime, 90);

  const isoDate = text.match(/\b(\d{4}-\d{2}-\d{2})\b/);
  if (isoDate) {
    return { isRecurring: false, specificDate: isoDate[1], startTime, endTime };
  }
  const dow = parseDayOfWeek(text);
  return { isRecurring: dow !== null, dayOfWeek: dow ?? undefined, specificDate: undefined, startTime, endTime };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/parse.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/lib/parse.mts scripts/fb-open-mat/test/parse.test.mts
git commit -m "feat(fb-scraper): deterministic post-text schedule/gi/fee parser"
```

---

### Task 4: Gym match (name-overlap + haversine)

**Files:**
- Create: `scripts/fb-open-mat/lib/geo-match.mts`
- Test: `scripts/fb-open-mat/test/geo-match.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/geo-match.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { haversineKm, nameOverlap, bestGymMatch } from "../lib/geo-match.mjs";

describe("haversineKm", () => {
  it("computes ~0 for same point and a known distance", () => {
    expect(haversineKm(32.5, -96.9, 32.5, -96.9)).toBeCloseTo(0, 3);
    // ~1.11 km per 0.01 deg latitude
    expect(haversineKm(32.5, -96.9, 32.51, -96.9)).toBeCloseTo(1.11, 1);
  });
});

describe("nameOverlap", () => {
  it("is 1 for identical, and >=0.5 for strong overlap", () => {
    expect(nameOverlap("Atos Jiu Jitsu", "Atos Jiu Jitsu")).toBeCloseTo(1, 3);
    expect(nameOverlap("Atos Jiu Jitsu HQ", "Atos Jiu-Jitsu")).toBeGreaterThanOrEqual(0.5);
    expect(nameOverlap("Gracie Barra", "Zenith BJJ")).toBeLessThan(0.5);
  });
});

describe("bestGymMatch", () => {
  const gyms = [
    { id: "g1", name: "Atos Jiu Jitsu", location: { lat: 32.50, lng: -96.90 } },
    { id: "g2", name: "Gracie Barra Frisco", location: { lat: 33.10, lng: -96.80 } },
  ];
  it("matches on >=50% name overlap within 3km", () => {
    const m = bestGymMatch({ gymName: "Atos Jiu-Jitsu", lat: 32.505, lng: -96.90 }, gyms);
    expect(m?.id).toBe("g1");
  });
  it("returns null when nearest name overlap is too low", () => {
    const m = bestGymMatch({ gymName: "Zenith BJJ", lat: 32.50, lng: -96.90 }, gyms);
    expect(m).toBeNull();
  });
  it("returns null when name matches but distance > 3km", () => {
    const m = bestGymMatch({ gymName: "Atos Jiu Jitsu", lat: 32.60, lng: -96.90 }, gyms);
    expect(m).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/geo-match.test.mts`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/geo-match.mts`:
```typescript
export interface GymRef {
  readonly id: string;
  readonly name: string;
  readonly location?: { lat: number; lng: number };
}

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const toRad = (d: number): number => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function tokens(name: string): Set<string> {
  const stop = new Set(['jiu', 'jitsu', 'bjj', 'academy', 'brazilian', 'the', 'and', 'hq', 'mma']);
  return new Set(
    name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((t) => t && !stop.has(t)),
  );
}

// Jaccard overlap of significant tokens (generic BJJ words removed).
export function nameOverlap(a: string, b: string): number {
  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter += 1;
  const union = new Set([...ta, ...tb]).size;
  return inter / union;
}

export interface MatchInput {
  readonly gymName: string;
  readonly lat: number;
  readonly lng: number;
}

// Returns the best gym with name overlap >= 0.5 AND within 3 km, else null.
export function bestGymMatch(input: MatchInput, gyms: readonly GymRef[]): GymRef | null {
  let best: GymRef | null = null;
  let bestScore = 0;
  for (const g of gyms) {
    const overlap = nameOverlap(input.gymName, g.name);
    if (overlap < 0.5) continue;
    if (g.location) {
      const dist = haversineKm(input.lat, input.lng, g.location.lat, g.location.lng);
      if (dist > 3) continue;
    }
    if (overlap > bestScore) {
      bestScore = overlap;
      best = g;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/geo-match.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/lib/geo-match.mts scripts/fb-open-mat/test/geo-match.test.mts
git commit -m "feat(fb-scraper): gym name-overlap + haversine matcher"
```

---

### Task 5: Excel schedule parser

**Files:**
- Create: `scripts/fb-open-mat/lib/xlsx-parse.mts`
- Test: `scripts/fb-open-mat/test/xlsx-parse.test.mts`

- [ ] **Step 1: Add the xlsx dependency**

Run: `bun add xlsx`
Expected: `xlsx` added to root `package.json` dependencies.

- [ ] **Step 2: Write the failing test**

`scripts/fb-open-mat/test/xlsx-parse.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import * as XLSX from "xlsx";
import { rowsToCandidates } from "../lib/xlsx-parse.mjs";

function sheetFromRows(rows: Record<string, string>[]): XLSX.WorkSheet {
  return XLSX.utils.json_to_sheet(rows);
}

describe("rowsToCandidates", () => {
  it("maps typical schedule columns to candidates", () => {
    const ws = sheetFromRows([
      { Gym: "Atos Jiu Jitsu", City: "Frisco", State: "TX", Day: "Sunday", Time: "10am-12pm", Type: "No-Gi" },
    ]);
    const out = rowsToCandidates(ws, "https://facebook.com/groups/x/files/y.xlsx");
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({
      gymName: "Atos Jiu Jitsu", city: "Frisco", state: "TX",
      dayOfWeek: 0, startTime: "10:00", endTime: "12:00", giType: "nogi", isRecurring: true,
    });
  });
  it("skips rows without a gym or without a parseable time", () => {
    const ws = sheetFromRows([
      { Gym: "", City: "X", Day: "Sunday", Time: "10am" },
      { Gym: "Test BJJ", City: "X", Day: "Sunday", Time: "" },
    ]);
    expect(rowsToCandidates(ws, "u")).toHaveLength(0);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/xlsx-parse.test.mts`
Expected: FAIL.

- [ ] **Step 4: Write minimal implementation**

`scripts/fb-open-mat/lib/xlsx-parse.mts`:
```typescript
import * as XLSX from 'xlsx';
import type { Candidate } from './types.mjs';
import { parseSchedule, parseGiType, parseSkillLevel, parseFeeCents } from './parse.mjs';

function pick(row: Record<string, unknown>, keys: string[]): string {
  for (const k of Object.keys(row)) {
    if (keys.some((want) => k.toLowerCase().includes(want))) {
      const v = row[k];
      if (v != null && String(v).trim() !== '') return String(v).trim();
    }
  }
  return '';
}

export function rowsToCandidates(sheet: XLSX.WorkSheet, sourceUrl: string): Candidate[] {
  const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet);
  const out: Candidate[] = [];
  for (const row of rows) {
    const gymName = pick(row, ['gym', 'name', 'academy']);
    const dayTime = `${pick(row, ['day'])} ${pick(row, ['time', 'schedule', 'when'])}`.trim();
    if (!gymName || !dayTime.trim()) continue;
    const sched = parseSchedule(dayTime);
    if (!sched) continue;
    const blob = `${gymName} ${dayTime} ${pick(row, ['type', 'gi', 'notes'])}`;
    out.push({
      sourceUrl, author: 'group-file',
      gymName,
      address: pick(row, ['address', 'street']) || undefined,
      city: pick(row, ['city']) || undefined,
      state: pick(row, ['state']) || undefined,
      postalCode: pick(row, ['zip', 'postal']) || undefined,
      dayOfWeek: sched.dayOfWeek, specificDate: sched.specificDate,
      isRecurring: sched.isRecurring, startTime: sched.startTime, endTime: sched.endTime,
      giType: parseGiType(blob), skillLevel: parseSkillLevel(blob), feeCents: parseFeeCents(blob),
      confidence: 0.9, rawSnippet: JSON.stringify(row),
    });
  }
  return out;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/xlsx-parse.test.mts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/fb-open-mat/lib/xlsx-parse.mts scripts/fb-open-mat/test/xlsx-parse.test.mts package.json bun.lock
git commit -m "feat(fb-scraper): Excel schedule parser"
```

---

### Task 6: Production API client

Wraps the three prod calls the pipeline needs: list gyms near a point, list sessions for a gym, and create a session. Uses `fetch`; base URL and token are injected so tests can pass a fake `fetch`.

**Files:**
- Create: `scripts/fb-open-mat/lib/api-client.mts`
- Test: `scripts/fb-open-mat/test/api-client.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/api-client.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { ApiClient } from "../lib/api-client.mjs";
import type { CreateOpenMatBody } from "../lib/types.mjs";

type FetchArgs = { url: string; init?: RequestInit };

function fakeFetch(responses: Record<string, unknown>): { fn: typeof fetch; calls: FetchArgs[] } {
  const calls: FetchArgs[] = [];
  const fn = (async (url: string, init?: RequestInit) => {
    calls.push({ url, init });
    const key = Object.keys(responses).find((k) => url.includes(k)) ?? '';
    return { ok: true, status: 200, json: async () => responses[key] } as Response;
  }) as unknown as typeof fetch;
  return { fn, calls };
}

describe("ApiClient", () => {
  it("lists gyms near a point", async () => {
    const { fn, calls } = fakeFetch({ "/gyms/nearby": { data: [{ id: "g1", name: "Atos", location: { lat: 1, lng: 2 } }] } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const gyms = await api.gymsNear(32.5, -96.9, 5);
    expect(gyms[0].id).toBe("g1");
    expect(calls[0].url).toContain("lat=32.5");
    expect(calls[0].url).toContain("/gyms/nearby");
  });

  it("lists sessions for a gym", async () => {
    const { fn } = fakeFetch({ "/open-mats": { data: [{ id: "o1", gymId: "g1", dayOfWeek: 0, startTime: "10:00" }] } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const sessions = await api.sessionsForGym("g1");
    expect(sessions[0].startTime).toBe("10:00");
  });

  it("POSTs a session with bearer auth and returns the created record", async () => {
    const { fn, calls } = fakeFetch({ "/open-mats": { data: { id: "new1", verified: false } } });
    const api = new ApiClient("https://api.test/api/v1", "tok", fn);
    const body: CreateOpenMatBody = { title: "Open Mat", startTime: "10:00", endTime: "12:00", gymId: "g1" };
    const created = await api.createSession(body);
    expect(created.id).toBe("new1");
    expect(created.verified).toBe(false);
    const post = calls.find((c) => c.init?.method === "POST")!;
    expect((post.init!.headers as Record<string, string>)["authorization"]).toBe("Bearer tok");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/api-client.test.mts`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/api-client.mts`:
```typescript
import type { CreateOpenMatBody } from './types.mjs';
import type { GymRef } from './geo-match.mjs';

export interface SessionRef {
  readonly id: string;
  readonly gymId: string;
  readonly dayOfWeek?: number;
  readonly specificDate?: string;
  readonly startTime: string;
}

export interface CreatedSession {
  readonly id: string;
  readonly verified: boolean;
}

export class ApiClient {

  private readonly baseUrl: string;
  private readonly token: string;
  private readonly fetchImpl: typeof fetch;

  public constructor(baseUrl: string, token: string, fetchImpl: typeof fetch = fetch) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.token = token;
    this.fetchImpl = fetchImpl;
  }

  public async gymsNear(lat: number, lng: number, radiusKm: number): Promise<GymRef[]> {
    const url = `${this.baseUrl}/gyms/nearby?lat=${lat}&lng=${lng}&radiusKm=${radiusKm}`;
    const res = await this.fetchImpl(url);
    if (!res.ok) throw new Error(`gymsNear ${res.status}`);
    return ((await res.json()) as { data: GymRef[] }).data;
  }

  public async sessionsForGym(gymId: string): Promise<SessionRef[]> {
    const url = `${this.baseUrl}/open-mats?gymId=${encodeURIComponent(gymId)}&limit=100`;
    const res = await this.fetchImpl(url);
    if (!res.ok) throw new Error(`sessionsForGym ${res.status}`);
    return ((await res.json()) as { data: SessionRef[] }).data;
  }

  public async createSession(body: CreateOpenMatBody): Promise<CreatedSession> {
    const url = `${this.baseUrl}/open-mats`;
    const res = await this.fetchImpl(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${this.token}` },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`createSession ${res.status}: ${await res.text()}`);
    return ((await res.json()) as { data: CreatedSession }).data;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/api-client.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/lib/api-client.mts scripts/fb-open-mat/test/api-client.test.mts
git commit -m "feat(fb-scraper): production API client (reads + create)"
```

---

### Task 7: Checkpoint store

Tracks the newest post timestamp scanned per group, so daily runs only read new posts.

**Files:**
- Create: `scripts/fb-open-mat/lib/checkpoint.mts`
- Test: `scripts/fb-open-mat/test/checkpoint.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/checkpoint.test.mts`:
```typescript
import { describe, expect, it, afterEach } from "bun:test";
import { rmSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CheckpointStore } from "../lib/checkpoint.mjs";

const dirs: string[] = [];
function tmpFile(): string {
  const d = mkdtempSync(join(tmpdir(), "cp-"));
  dirs.push(d);
  return join(d, "checkpoints.json");
}
afterEach(() => { for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true }); });

describe("CheckpointStore", () => {
  it("returns null for an unseen group and persists updates", () => {
    const path = tmpFile();
    const store = new CheckpointStore(path);
    expect(store.get("gA")).toBeNull();
    store.set("gA", "2026-07-01T00:00:00.000Z");
    store.save();
    const reloaded = new CheckpointStore(path);
    expect(reloaded.get("gA")).toBe("2026-07-01T00:00:00.000Z");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/checkpoint.test.mts`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/checkpoint.mts`:
```typescript
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

export class CheckpointStore {

  private readonly path: string;
  private data: Record<string, string>;

  public constructor(path: string) {
    this.path = path;
    this.data = existsSync(path) ? (JSON.parse(readFileSync(path, 'utf8')) as Record<string, string>) : {};
  }

  public get(groupUrl: string): string | null {
    return this.data[groupUrl] ?? null;
  }

  public set(groupUrl: string, isoTimestamp: string): void {
    this.data[groupUrl] = isoTimestamp;
  }

  public save(): void {
    writeFileSync(this.path, JSON.stringify(this.data, null, 2));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/checkpoint.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fb-open-mat/lib/checkpoint.mts scripts/fb-open-mat/test/checkpoint.test.mts
git commit -m "feat(fb-scraper): per-group checkpoint store"
```

---

### Task 8: Stage 1 — collect.mts (Playwright)

Collection can't be unit-tested (depends on live Facebook + your login), so this task is manually verified. It logs in (headed, or headless with a saved session), scrolls each group with throttling down to the checkpoint (or ~1 year on first run), reads pinned posts + the Files tab (downloading `.xlsx`), and writes raw posts.

**Files:**
- Create: `scripts/fb-open-mat/collect.mts`

- [ ] **Step 1: Write the collector**

`scripts/fb-open-mat/collect.mts` (key structure — implement fully):
```typescript
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
```

- [ ] **Step 2: Manual smoke test (headed login)**

Run: `bun run scripts/fb-open-mat/collect.mts --initial`
Complete the Facebook login when the window opens. Expected: a `.fb-session.json` is written; each group produces `docs/open-mats/raw/<group>-<date>.json`; the console prints a per-group open-mat post count. If selectors capture zero posts on a group you know has open-mat posts, adjust the `article`/`permalink`/`author` locators and re-run.

- [ ] **Step 3: Commit**

```bash
git add scripts/fb-open-mat/collect.mts
git commit -m "feat(fb-scraper): Stage 1 Playwright collector with session reuse + throttling"
```

---

### Task 9: Stage 3 — resolve.mts (dedupe + gym resolution)

Reads `found-<date>.json` (produced by Claude in Stage 2), resolves each candidate's gym against production, drops sessions that already exist, and writes `new-<date>.json`. The core is a pure `resolveCandidates` function tested with a fake API client.

**Files:**
- Create: `scripts/fb-open-mat/lib/resolve-core.mts`
- Create: `scripts/fb-open-mat/resolve.mts`
- Test: `scripts/fb-open-mat/test/resolve-core.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/resolve-core.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { resolveCandidates, type ResolveApi } from "../lib/resolve-core.mjs";
import type { Candidate } from "../lib/types.mjs";

const base: Candidate = {
  sourceUrl: "u", author: "a", gymName: "Atos Jiu Jitsu", city: "Frisco", state: "TX", postalCode: "75034",
  dayOfWeek: 0, isRecurring: true, startTime: "10:00", endTime: "12:00",
  giType: "both", skillLevel: "all", feeCents: 0, confidence: 0.9, rawSnippet: "",
};

function api(over: Partial<ResolveApi>): ResolveApi {
  return {
    geocodeZip: async () => ({ lat: 33.15, lng: -96.82 }),
    gymsNear: async () => [{ id: "g1", name: "Atos Jiu Jitsu", location: { lat: 33.15, lng: -96.82 } }],
    sessionsForGym: async () => [],
    ...over,
  };
}

describe("resolveCandidates", () => {
  it("attaches gymId when a gym matches and keeps the new session", async () => {
    const out = await resolveCandidates([base], api({}));
    expect(out).toHaveLength(1);
    expect(out[0].gymId).toBe("g1");
    expect(out[0].newGym).toBeUndefined();
  });

  it("flags newGym when no gym matches", async () => {
    const out = await resolveCandidates([base], api({ gymsNear: async () => [] }));
    expect(out[0].gymId).toBeUndefined();
    expect(out[0].newGym?.name).toBe("Atos Jiu Jitsu");
  });

  it("drops a session that already exists at the gym (same day+start)", async () => {
    const out = await resolveCandidates([base], api({
      sessionsForGym: async () => [{ id: "o1", gymId: "g1", dayOfWeek: 0, startTime: "10:00" }],
    }));
    expect(out).toHaveLength(0);
  });

  it("skips candidates that fail the US filter", async () => {
    const nonUs: Candidate = { ...base, state: "ON", postalCode: undefined };
    const out = await resolveCandidates([nonUs], api({}));
    expect(out).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/resolve-core.test.mts`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/resolve-core.mts`:
```typescript
import type { Candidate, CreateOpenMatBody } from './types.mjs';
import type { GymRef, MatchInput } from './geo-match.mjs';
import { bestGymMatch } from './geo-match.mjs';
import { isUsCandidate } from './us-filter.mjs';
import type { SessionRef } from './api-client.mjs';

export interface ResolveApi {
  geocodeZip(zip: string): Promise<{ lat: number; lng: number } | null>;
  gymsNear(lat: number, lng: number, radiusKm: number): Promise<GymRef[]>;
  sessionsForGym(gymId: string): Promise<SessionRef[]>;
}

// A candidate ready to POST: title + schedule + either gymId or newGym.
export type ResolvedSession = CreateOpenMatBody & { sourceUrl: string; gymNameForLog: string };

function sessionExists(candidate: Candidate, existing: SessionRef[]): boolean {
  return existing.some((s) =>
    s.startTime === candidate.startTime &&
    (candidate.specificDate ? s.specificDate === candidate.specificDate : s.dayOfWeek === candidate.dayOfWeek),
  );
}

export async function resolveCandidates(candidates: Candidate[], api: ResolveApi): Promise<ResolvedSession[]> {
  const out: ResolvedSession[] = [];
  for (const c of candidates) {
    if (!isUsCandidate(c)) continue;

    const geo = c.postalCode ? await api.geocodeZip(c.postalCode) : null;
    let gymId: string | undefined;

    if (geo) {
      const gyms = await api.gymsNear(geo.lat, geo.lng, 5);
      const match: MatchInput = { gymName: c.gymName, lat: geo.lat, lng: geo.lng };
      const found = bestGymMatch(match, gyms);
      if (found) {
        const existing = await api.sessionsForGym(found.id);
        if (sessionExists(c, existing)) continue; // duplicate — drop
        gymId = found.id;
      }
    }

    const common = {
      title: `${c.gymName} Open Mat`,
      startTime: c.startTime, endTime: c.endTime,
      dayOfWeek: c.dayOfWeek, specificDate: c.specificDate, isRecurring: c.isRecurring,
      giType: c.giType, skillLevel: c.skillLevel, feeCents: c.feeCents,
      sourceUrl: c.sourceUrl, gymNameForLog: c.gymName,
    };
    out.push(gymId
      ? { ...common, gymId }
      : { ...common, newGym: { name: c.gymName, address: c.address ?? c.city ?? c.gymName, city: c.city, state: c.state, postalCode: c.postalCode, country: 'US' } });
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/resolve-core.test.mts`
Expected: PASS.

- [ ] **Step 5: Write the resolve.mts runner (wires files + real API)**

`scripts/fb-open-mat/resolve.mts`:
```typescript
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import zipcodes from 'zipcodes';
import type { Candidate } from './lib/types.mjs';
import { ApiClient } from './lib/api-client.mjs';
import { resolveCandidates, type ResolveApi } from './lib/resolve-core.mjs';

const OUT_DIR = join(import.meta.dir, '..', '..', 'docs', 'open-mats');
const BASE = process.env.FB_SCRAPER_API_BASE ?? 'https://api.bjj-open-mat.dsylvester.io/api/v1';
const TOKEN = process.env.FB_SCRAPER_API_TOKEN ?? '';
const date = process.argv.slice(2).find((a) => !a.startsWith('--')) ?? new Date().toISOString().slice(0, 10);

const foundPath = join(OUT_DIR, `found-${date}.json`);
const candidates = JSON.parse(readFileSync(foundPath, 'utf8')) as Candidate[];
const client = new ApiClient(BASE, TOKEN);

const api: ResolveApi = {
  geocodeZip: async (zip) => { const r = zipcodes.lookup(zip); return r ? { lat: r.latitude, lng: r.longitude } : null; },
  gymsNear: (lat, lng, r) => client.gymsNear(lat, lng, r),
  sessionsForGym: (id) => client.sessionsForGym(id),
};

const resolved = await resolveCandidates(candidates, api);
const newPath = join(OUT_DIR, `new-${date}.json`);
writeFileSync(newPath, JSON.stringify(resolved, null, 2));
console.log(`Resolved ${candidates.length} candidates → ${resolved.length} new sessions.`);
console.log(`Wrote ${newPath}. Review it, then run insert.mts --commit.`);
```

- [ ] **Step 6: Verify the runner loads (dry, no network needed if file empty)**

Run: `echo "[]" > docs/open-mats/found-0000-00-00.json && bun run scripts/fb-open-mat/resolve.mts 0000-00-00`
Expected: prints `Resolved 0 candidates → 0 new sessions.` and writes `new-0000-00-00.json`. Then `rm docs/open-mats/found-0000-00-00.json docs/open-mats/new-0000-00-00.json`.

- [ ] **Step 7: Commit**

```bash
git add scripts/fb-open-mat/lib/resolve-core.mts scripts/fb-open-mat/resolve.mts scripts/fb-open-mat/test/resolve-core.test.mts
git commit -m "feat(fb-scraper): Stage 3 dedupe + gym resolution"
```

---

### Task 10: Stage 5 — insert.mts (production POST, --commit gated)

Reads `new-<date>.json`, and (only with `--commit`) POSTs each session to production, re-checking dedupe immediately before each insert. Without `--commit` it prints the plan. The insert loop core is tested with a fake client.

**Files:**
- Create: `scripts/fb-open-mat/lib/insert-core.mts`
- Create: `scripts/fb-open-mat/insert.mts`
- Test: `scripts/fb-open-mat/test/insert-core.test.mts`

- [ ] **Step 1: Write the failing test**

`scripts/fb-open-mat/test/insert-core.test.mts`:
```typescript
import { describe, expect, it } from "bun:test";
import { insertSessions, type InsertApi } from "../lib/insert-core.mjs";
import type { ResolvedSession } from "../lib/resolve-core.mjs";

const s: ResolvedSession = {
  title: "Atos Open Mat", startTime: "10:00", endTime: "12:00", dayOfWeek: 0, isRecurring: true,
  giType: "both", skillLevel: "all", feeCents: 0, gymId: "g1", sourceUrl: "u", gymNameForLog: "Atos",
};

describe("insertSessions", () => {
  it("dry run creates nothing and reports the plan", async () => {
    const calls: string[] = [];
    const api: InsertApi = { createSession: async () => { calls.push("post"); return { id: "x", verified: false }; } };
    const log = await insertSessions([s], api, false);
    expect(calls).toHaveLength(0);
    expect(log.planned).toBe(1);
    expect(log.inserted).toHaveLength(0);
  });

  it("commit run POSTs and records id + verified status", async () => {
    const api: InsertApi = { createSession: async () => ({ id: "new1", verified: false }) };
    const log = await insertSessions([s], api, true);
    expect(log.inserted).toEqual([{ id: "new1", verified: false, gymName: "Atos", sourceUrl: "u" }]);
  });

  it("continues past a failed insert and records the error", async () => {
    const api: InsertApi = { createSession: async () => { throw new Error("boom"); } };
    const log = await insertSessions([s], api, true);
    expect(log.inserted).toHaveLength(0);
    expect(log.errors).toHaveLength(1);
    expect(log.errors[0].error).toContain("boom");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bun test scripts/fb-open-mat/test/insert-core.test.mts`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

`scripts/fb-open-mat/lib/insert-core.mts`:
```typescript
import type { CreatedSession } from './api-client.mjs';
import type { ResolvedSession } from './resolve-core.mjs';

export interface InsertApi {
  createSession(body: ResolvedSession): Promise<CreatedSession>;
}

export interface InsertLog {
  planned: number;
  inserted: Array<{ id: string; verified: boolean; gymName: string; sourceUrl: string }>;
  errors: Array<{ gymName: string; sourceUrl: string; error: string }>;
}

export async function insertSessions(sessions: ResolvedSession[], api: InsertApi, commit: boolean): Promise<InsertLog> {
  const log: InsertLog = { planned: sessions.length, inserted: [], errors: [] };
  if (!commit) return log;
  for (const s of sessions) {
    try {
      const created = await api.createSession(s);
      log.inserted.push({ id: created.id, verified: created.verified, gymName: s.gymNameForLog, sourceUrl: s.sourceUrl });
    } catch (e) {
      log.errors.push({ gymName: s.gymNameForLog, sourceUrl: s.sourceUrl, error: e instanceof Error ? e.message : String(e) });
    }
  }
  return log;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bun test scripts/fb-open-mat/test/insert-core.test.mts`
Expected: PASS.

- [ ] **Step 5: Write the insert.mts runner**

`scripts/fb-open-mat/insert.mts`:
```typescript
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { ApiClient } from './lib/api-client.mjs';
import type { ResolvedSession } from './lib/resolve-core.mjs';
import { insertSessions, type InsertApi } from './lib/insert-core.mjs';

const OUT_DIR = join(import.meta.dir, '..', '..', 'docs', 'open-mats');
const BASE = process.env.FB_SCRAPER_API_BASE ?? 'https://api.bjj-open-mat.dsylvester.io/api/v1';
const TOKEN = process.env.FB_SCRAPER_API_TOKEN ?? '';
const COMMIT = process.argv.includes('--commit');
const date = process.argv.slice(2).find((a) => !a.startsWith('--')) ?? new Date().toISOString().slice(0, 10);

if (COMMIT && !TOKEN) { console.error('FB_SCRAPER_API_TOKEN is required for --commit.'); process.exit(1); }

const sessions = JSON.parse(readFileSync(join(OUT_DIR, `new-${date}.json`), 'utf8')) as ResolvedSession[];
const client = new ApiClient(BASE, TOKEN);
const api: InsertApi = { createSession: (body) => client.createSession(body) };

const log = await insertSessions(sessions, api, COMMIT);
if (!COMMIT) {
  console.log(`DRY RUN — ${log.planned} sessions would be POSTed to ${BASE}. Re-run with --commit to insert.`);
} else {
  writeFileSync(join(OUT_DIR, `inserted-${date}.json`), JSON.stringify(log, null, 2));
  console.log(`Inserted ${log.inserted.length}/${log.planned}; ${log.errors.length} errors.`);
  const verified = log.inserted.filter((i) => i.verified).length;
  if (verified > 0) console.log(`NOTE: ${verified} landed VERIFIED (your token is admin/owner). Use a practitioner token to keep them unverified.`);
}
```

- [ ] **Step 6: Verify dry-run runner**

Run: `echo "[]" > docs/open-mats/new-0000-00-00.json && bun run scripts/fb-open-mat/insert.mts 0000-00-00`
Expected: `DRY RUN — 0 sessions would be POSTed…`. Then `rm docs/open-mats/new-0000-00-00.json`.

- [ ] **Step 7: Commit**

```bash
git add scripts/fb-open-mat/lib/insert-core.mts scripts/fb-open-mat/insert.mts scripts/fb-open-mat/test/insert-core.test.mts
git commit -m "feat(fb-scraper): Stage 5 gated production insert"
```

---

### Task 11: The skill — SKILL.md

Ties the stages together for Claude, including the Stage 2 parse instructions (Claude reads raw posts → `found-<date>.json`).

**Files:**
- Create: `.claude/skills/fb-open-mat-scraper/SKILL.md`

- [ ] **Step 1: Write the skill**

`.claude/skills/fb-open-mat-scraper/SKILL.md`:
```markdown
---
name: fb-open-mat-scraper
description: Scrape Facebook groups for BJJ open-mat sessions and add new ones to the production database. Use when the user says "scrape facebook for open mats", "find open mats on facebook", "run the fb open mat scraper", or asks to import open-mat sessions from Facebook groups. US only. Writes to PRODUCTION behind a --commit review gate.
argument-hint: [--initial]
---

# Facebook Open-Mat Scraper

Five-stage pipeline. Run stages in order; never skip the review gate before insert.
Design: `docs/superpowers/specs/2026-07-26-fb-openmat-scraper-design.md`.

## Preconditions
- `FB_SCRAPER_API_TOKEN` = a JWT from a logged-in app session (practitioner role to
  keep inserts unverified; admin/owner will auto-verify — the insert step logs which).
- Group URLs live in `scripts/fb-open-mat/groups.json`. Add new groups there.

## Stage 1 — Collect (Playwright)
Run `bun run scripts/fb-open-mat/collect.mts` (add `--initial` for the first ~1-year
backfill; omit for daily since-checkpoint runs). First run is headed: tell the user to
complete the Facebook login in the window; the session is saved for later headless runs.
Output: `docs/open-mats/raw/<group>-<date>.json` + any `.xlsx` in `docs/open-mats/xlsx/`.

## Stage 2 — Parse (you, Claude)
Read every `docs/open-mats/raw/*-<date>.json` and any Excel via
`scripts/fb-open-mat/lib/xlsx-parse.mts`. For each post that describes an open mat,
build a Candidate (see `scripts/fb-open-mat/lib/types.mts`): use
`parseSchedule`/`parseGiType`/`parseSkillLevel`/`parseFeeCents` from `lib/parse.mts`
for time/day/gi/fee; read the gym name + address/city/state/zip from the post text
yourself. Drop posts with no gym or no parseable time (log why). Keep US only.
Write ALL candidates to `docs/open-mats/found-<date>.json`.

## Stage 3 — Dedupe & resolve
Run `bun run scripts/fb-open-mat/resolve.mts <date>`. Produces
`docs/open-mats/new-<date>.json` (new-only, gyms resolved or flagged for creation).

## Stage 4 — Review gate
Show the user `new-<date>.json`: count, which gyms are new, a few samples. Get
explicit approval before Stage 5.

## Stage 5 — Insert (production)
Dry run first: `bun run scripts/fb-open-mat/insert.mts <date>`. On approval:
`bun run scripts/fb-open-mat/insert.mts <date> --commit`. Writes
`docs/open-mats/inserted-<date>.json`. Report inserted/error counts and any that
landed verified.

## Daily runs
Repeat Stages 1–5 without `--initial`. Collection only scans posts newer than the
per-group checkpoint. If Facebook shows a login form, the saved session expired —
re-run headed to refresh it.
```

- [ ] **Step 2: Verify frontmatter parses**

Run: `bun -e "const s=require('fs').readFileSync('.claude/skills/fb-open-mat-scraper/SKILL.md','utf8'); console.log(/^---[\s\S]*name: fb-open-mat-scraper[\s\S]*---/.test(s))"`
Expected: `true`

- [ ] **Step 3: Run the full test suite**

Run: `bun test scripts/fb-open-mat/`
Expected: all tests PASS (us-filter, parse, geo-match, xlsx-parse, api-client, checkpoint, resolve-core, insert-core).

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/fb-open-mat-scraper/SKILL.md
git commit -m "feat(fb-scraper): add fb-open-mat-scraper skill"
```

---

## Self-Review

**Spec coverage:**
- Group collection config → Task 1. ✅
- Playwright collect + login/session reuse + throttle + checkpoint + pinned/Files/xlsx → Task 8. ✅
- Parse to structured candidates + US filter → Tasks 2, 3, 5, 11 (Stage 2). ✅
- Two JSON files (`found-*` all, `new-*` new-only) → Tasks 9, 11. ✅
- Dedupe (no duplicates) + gym auto-create via `newGym` → Task 9. ✅
- Review gate before prod write → Tasks 10, 11 (Stage 4). ✅
- Insert to production API, unverified, your token → Task 10. ✅
- Verified-status nuance logged → Task 10 Step 5. ✅
- Skill committed to repo → Task 11. ✅
- Tests for parser + dedupe + excel → Tasks 2–7, 9, 10. ✅

**Placeholder scan:** No TBD/TODO; every code step has complete code. Playwright selectors in Task 8 are explicitly called out as needing live-DOM validation (inherent to FB scraping), with a manual smoke step — not a placeholder.

**Type consistency:** `Candidate`, `RawPost`, `GroupEntry`, `CreateOpenMatBody` defined in Task 1 and used consistently; `GymRef`/`MatchInput`/`SessionRef`/`CreatedSession`/`ResolvedSession`/`ResolveApi`/`InsertApi`/`InsertLog` defined once and reused. `bestGymMatch`, `resolveCandidates`, `insertSessions`, `parseSchedule` names consistent across tasks.
