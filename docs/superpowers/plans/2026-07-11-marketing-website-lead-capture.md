# Marketing Website + Lead Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pixel-perfect Angular landing page (`website/`) with two public lead-capture actions — join the founding list and claim a gym — backed by new public API endpoints that persist to MongoDB and send SES confirmation emails, deployed to `bjj-open-mat.dsylvester.ai`.

**Architecture:** Three phases following the existing API layering (contract → repository → facade → route). Phase 1 adds two public endpoints + an SES email service to `apps/api`. Phase 2 builds the Angular static site in `website/` and iterates to a pixel-perfect match against the Claude Design file using Playwright. Phase 3 provisions AWS hosting (S3/CloudFront) + SES + Hostinger DNS via CDK.

**Tech Stack:** Bun + Elysia + TypeBox + MongoDB (API), Angular v21 standalone/signals + SCSS + Playwright (website), AWS CDK + SES + S3/CloudFront + Hostinger DNS (infra).

**Spec:** `docs/superpowers/specs/2026-07-11-marketing-website-lead-capture-design.md`

---

## Conventions (read once)

- All API code is strict TypeScript, no `any`, explicit return types + access modifiers, `.mts` source with `.mjs` import specifiers, named exports, single quotes, TypeBox for validation.
- Run tests with `bun test` from repo root or `cd apps/api && bun test`.
- Run lint with `bun run lint` (ESLint) after each set of changes; fix before considering a task done.
- Commit with Conventional Commits (`feat:`, `fix:`, `docs:`, etc.). Never add Co-Authored-By lines.
- Health endpoints are `/health` and `/ready` — never `/healthz`.

---

## File Structure

**Phase 1 — API (`apps/api`, `packages/contract`)**
- Create `packages/contract/src/schemas/lead.mts` — `WaitlistLead`, `GymLead`, `Utm` domain schemas.
- Create `packages/contract/src/schemas/requests/lead-requests.mts` — request/response schemas.
- Modify `packages/contract/src/schemas/index.mts` and `.../requests/index.mts` — barrels.
- Create `apps/api/src/repositories/waitlist-lead.repository.mts`, `.../gym-lead.repository.mts`.
- Modify `apps/api/src/db/collections.mts` — add `waitlistLeads`, `gymLeads`.
- Create `apps/api/src/services/email.service.mts` — `EmailService` interface + `SesEmailService` + `UnconfiguredEmailService`.
- Create `apps/api/src/facades/lead.facade.mts` — orchestration.
- Create `apps/api/src/routes/lead.routes.mts` — public endpoints.
- Modify `apps/api/src/config/env.mts` — SES/website env.
- Modify `apps/api/src/container.mts` — wire repos, email, facade, indexes.
- Modify `apps/api/src/app.mts` — register routes + CORS origins.
- Tests under `apps/api/test/`.

**Phase 2 — Website (`website/`)**
- Angular app root: `website/` (`ng new` output).
- `website/src/app/core/lead-api.service.ts`, `website/src/app/core/models/`.
- `website/src/app/landing/` — `landing.component.*` + section components + `waitlist-form`, `gym-lead-form`.
- `website/src/environments/environment.ts` + `environment.development.ts`.
- `website/src/styles/_tokens.scss` — brand tokens.
- `website/tests/` — Playwright visual + E2E specs; `website/playwright.config.ts`.
- `website/reference/` — fetched design HTML + reference screenshots (gitignored except the HTML).

**Phase 3 — Infra (`infra/`)**
- Create `infra/lib/website-stack.ts` — S3 + CloudFront + ACM.
- Modify `infra/lib/api-stack.ts` — SES identity + grant + env.
- Modify `infra/bin/infra.ts` — instantiate `WebsiteStack`.
- DNS via the `hostinger-dns` agent (no repo file).

---

# PHASE 1 — API: public lead endpoints + SES email

### Task 1: Contract — UTM + domain schemas

**Files:**
- Create: `packages/contract/src/schemas/lead.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `apps/api/test/contract-lead.test.mts`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/contract-lead.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { WaitlistLead, GymLead } from "@bjj/contract";

describe("lead domain schemas", () => {
  it("accepts a valid waitlist lead", () => {
    const lead = {
      id: "w1",
      email: "a@b.com",
      status: "confirmed",
      utm: { source: "ig", medium: "social", campaign: "launch" },
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    expect(Value.Check(WaitlistLead, lead)).toBe(true);
  });

  it("accepts a valid gym lead with optional fields omitted", () => {
    const lead = {
      id: "g1",
      gymName: "Gracie Barra",
      ownerEmail: "coach@gym.com",
      status: "new",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    expect(Value.Check(GymLead, lead)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/contract-lead.test.mts`
Expected: FAIL — `WaitlistLead`/`GymLead` are not exported.

- [ ] **Step 3: Write the schemas**

```ts
// packages/contract/src/schemas/lead.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const Utm = t.Object(
  {
    source: t.Optional(t.String()),
    medium: t.Optional(t.String()),
    campaign: t.Optional(t.String()),
  },
  { $id: "Utm" },
);
export type Utm = Static<typeof Utm>;

export const WaitlistLeadStatus = t.Union([t.Literal("pending"), t.Literal("confirmed")], {
  $id: "WaitlistLeadStatus",
});
export type WaitlistLeadStatus = Static<typeof WaitlistLeadStatus>;

export const WaitlistLead = t.Object(
  {
    id: t.String(),
    email: t.String({ format: "email" }),
    status: WaitlistLeadStatus,
    source: t.Optional(t.String()),
    utm: t.Optional(Utm),
    createdAt: t.String(),
    confirmationSentAt: t.Optional(t.String()),
  },
  { $id: "WaitlistLead" },
);
export type WaitlistLead = Static<typeof WaitlistLead>;

export const GymLeadStatus = t.Union([t.Literal("new"), t.Literal("contacted")], { $id: "GymLeadStatus" });
export type GymLeadStatus = Static<typeof GymLeadStatus>;

export const GymLead = t.Object(
  {
    id: t.String(),
    gymName: t.String(),
    ownerName: t.Optional(t.String()),
    ownerEmail: t.String({ format: "email" }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    message: t.Optional(t.String()),
    status: GymLeadStatus,
    utm: t.Optional(Utm),
    createdAt: t.String(),
  },
  { $id: "GymLead" },
);
export type GymLead = Static<typeof GymLead>;
```

- [ ] **Step 4: Add to the schema barrel**

Add this line to `packages/contract/src/schemas/index.mts` (keep alphabetical-ish with the others):

```ts
export * from "./lead.mts";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/contract-lead.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/contract/src/schemas/lead.mts packages/contract/src/schemas/index.mts apps/api/test/contract-lead.test.mts
git commit -m "feat(contract): add waitlist + gym lead domain schemas"
```

---

### Task 2: Contract — request/response schemas

**Files:**
- Create: `packages/contract/src/schemas/requests/lead-requests.mts`
- Modify: `packages/contract/src/schemas/requests/index.mts`
- Test: `apps/api/test/contract-lead-requests.test.mts`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/contract-lead-requests.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { WaitlistLeadRequest, GymLeadRequest, LeadResponse } from "@bjj/contract";

describe("lead request schemas", () => {
  it("rejects a waitlist request with a bad email", () => {
    expect(Value.Check(WaitlistLeadRequest, { email: "nope" })).toBe(false);
  });

  it("accepts a waitlist request with utm + honeypot", () => {
    expect(
      Value.Check(WaitlistLeadRequest, { email: "a@b.com", utm: { source: "ig" }, hp: "" }),
    ).toBe(true);
  });

  it("requires gymName and ownerEmail on a gym request", () => {
    expect(Value.Check(GymLeadRequest, { ownerEmail: "a@b.com" })).toBe(false);
    expect(Value.Check(GymLeadRequest, { gymName: "GB", ownerEmail: "a@b.com" })).toBe(true);
  });

  it("shapes the lead response", () => {
    expect(Value.Check(LeadResponse, { status: "confirmed" })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/contract-lead-requests.test.mts`
Expected: FAIL — request schemas not exported.

- [ ] **Step 3: Write the request/response schemas**

```ts
// packages/contract/src/schemas/requests/lead-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { Utm } from "../lead.mts";

// `hp` is a honeypot: a hidden field real users never fill. Non-empty => bot.
export const WaitlistLeadRequest = t.Object(
  {
    email: t.String({ format: "email" }),
    source: t.Optional(t.String()),
    utm: t.Optional(Utm),
    hp: t.Optional(t.String()),
  },
  { $id: "WaitlistLeadRequest" },
);
export type WaitlistLeadRequest = Static<typeof WaitlistLeadRequest>;

export const GymLeadRequest = t.Object(
  {
    gymName: t.String({ minLength: 1 }),
    ownerName: t.Optional(t.String()),
    ownerEmail: t.String({ format: "email" }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    message: t.Optional(t.String()),
    utm: t.Optional(Utm),
    hp: t.Optional(t.String()),
  },
  { $id: "GymLeadRequest" },
);
export type GymLeadRequest = Static<typeof GymLeadRequest>;

export const LeadResponse = t.Object(
  {
    status: t.Union([t.Literal("confirmed"), t.Literal("new")]),
  },
  { $id: "LeadResponse" },
);
export type LeadResponse = Static<typeof LeadResponse>;
```

- [ ] **Step 4: Add to the requests barrel**

Add to `packages/contract/src/schemas/requests/index.mts`:

```ts
export * from "./lead-requests.mts";
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/contract-lead-requests.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/contract/src/schemas/requests/lead-requests.mts packages/contract/src/schemas/requests/index.mts apps/api/test/contract-lead-requests.test.mts
git commit -m "feat(contract): add waitlist + gym lead request schemas"
```

---

### Task 3: Collections + repositories

**Files:**
- Modify: `apps/api/src/db/collections.mts`
- Create: `apps/api/src/repositories/waitlist-lead.repository.mts`
- Create: `apps/api/src/repositories/gym-lead.repository.mts`
- Test: `apps/api/test/lead-repository.test.mts`

- [ ] **Step 1: Add the collection names**

Add two entries to the `COLLECTIONS` object in `apps/api/src/db/collections.mts`:

```ts
  waitlistLeads: "waitlistLeads",
  gymLeads: "gymLeads",
```

(Place them after `reports: "reports",` before the closing `} as const;`.)

- [ ] **Step 2: Write the failing test**

```ts
// apps/api/test/lead-repository.test.mts
import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { MongoClient, type Db } from "mongodb";
import { WaitlistLeadRepository } from "../src/repositories/waitlist-lead.repository.mts";
import { GymLeadRepository } from "../src/repositories/gym-lead.repository.mts";
import type { WaitlistLead, GymLead } from "@bjj/contract";

// Uses the local Mongo from docker-compose (MONGODB_URI or default localhost).
const URI = process.env.MONGODB_URI ?? "mongodb://localhost:27017";
let client: MongoClient;
let db: Db;

beforeAll(async () => {
  client = new MongoClient(URI);
  await client.connect();
  db = client.db("bjj_open_mat_test_leads");
});

afterAll(async () => {
  await db.dropDatabase();
  await client.close();
});

describe("WaitlistLeadRepository", () => {
  it("upserts idempotently on email (no duplicates)", async () => {
    const repo = new WaitlistLeadRepository(db);
    await repo.ensureIndexes();
    const base: WaitlistLead = {
      id: "w1",
      email: "dup@b.com",
      status: "confirmed",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    await repo.upsertByEmail(base);
    await repo.upsertByEmail({ ...base, id: "w2" });
    const count = await db.collection("waitlistLeads").countDocuments({ email: "dup@b.com" });
    expect(count).toBe(1);
  });
});

describe("GymLeadRepository", () => {
  it("inserts a gym lead", async () => {
    const repo = new GymLeadRepository(db);
    await repo.ensureIndexes();
    const lead: GymLead = {
      id: "g1",
      gymName: "GB",
      ownerEmail: "coach@gym.com",
      status: "new",
      createdAt: "2026-07-11T00:00:00.000Z",
    };
    await repo.insert(lead);
    const found = await db.collection("gymLeads").findOne({ id: "g1" });
    expect(found?.gymName).toBe("GB");
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apps/api && bun test test/lead-repository.test.mts`
Expected: FAIL — repositories not defined. (If Mongo isn't running, start it: `docker compose up -d` from repo root.)

- [ ] **Step 4: Write the repositories**

```ts
// apps/api/src/repositories/waitlist-lead.repository.mts
import type { Db } from "mongodb";
import type { WaitlistLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class WaitlistLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<WaitlistLead>(COLLECTIONS.waitlistLeads).createIndex({ email: 1 }, { unique: true });
  }

  // Idempotent: a re-submit of the same email inserts nothing new. Returns true
  // when this call created the record (first sign-up), false when it already existed.
  public async upsertByEmail(lead: WaitlistLead): Promise<boolean> {
    const res = await this.collection<WaitlistLead>(COLLECTIONS.waitlistLeads).updateOne(
      { email: lead.email },
      { $setOnInsert: lead },
      { upsert: true },
    );
    return res.upsertedCount === 1;
  }
}
```

```ts
// apps/api/src/repositories/gym-lead.repository.mts
import type { Db } from "mongodb";
import type { GymLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class GymLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<GymLead>(COLLECTIONS.gymLeads).createIndex({ createdAt: -1 });
  }

  public async insert(lead: GymLead): Promise<void> {
    await this.collection<GymLead>(COLLECTIONS.gymLeads).insertOne(lead);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/lead-repository.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add apps/api/src/db/collections.mts apps/api/src/repositories/waitlist-lead.repository.mts apps/api/src/repositories/gym-lead.repository.mts apps/api/test/lead-repository.test.mts
git commit -m "feat(api): add waitlist + gym lead repositories and collections"
```

---

### Task 4: SES email service

**Files:**
- Create: `apps/api/src/services/email.service.mts`
- Modify: `apps/api/package.json` (add `@aws-sdk/client-sesv2`)
- Test: `apps/api/test/email-service.test.mts`

- [ ] **Step 1: Add the SES SDK dependency**

Run: `cd apps/api && bun add @aws-sdk/client-sesv2`
Expected: `@aws-sdk/client-sesv2` appears under `dependencies` in `apps/api/package.json`.

- [ ] **Step 2: Write the failing test**

```ts
// apps/api/test/email-service.test.mts
import { describe, expect, it } from "bun:test";
import { SesEmailService, UnconfiguredEmailService } from "../src/services/email.service.mts";

// A fake SESv2 client capturing the last command input.
function fakeClient(): { sent: unknown[]; send(cmd: unknown): Promise<unknown> } {
  const sent: unknown[] = [];
  return {
    sent,
    async send(cmd: { input: unknown }): Promise<unknown> {
      sent.push(cmd.input);
      return { MessageId: "m1" };
    },
  };
}

describe("SesEmailService", () => {
  it("sends a waitlist confirmation from the configured sender", async () => {
    const client = fakeClient();
    // deno-fmt-ignore
    const svc = new SesEmailService(
      { from: "no-reply@dsylvester.ai", adminEmail: "admin@x.com" },
      client as never,
    );
    await svc.sendWaitlistConfirmation("user@x.com");
    const input = client.sent[0] as { FromEmailAddress: string; Destination: { ToAddresses: string[] } };
    expect(input.FromEmailAddress).toBe("no-reply@dsylvester.ai");
    expect(input.Destination.ToAddresses).toEqual(["user@x.com"]);
  });

  it("sends a gym-lead admin alert to the admin address", async () => {
    const client = fakeClient();
    const svc = new SesEmailService(
      { from: "no-reply@dsylvester.ai", adminEmail: "admin@x.com" },
      client as never,
    );
    await svc.sendGymLeadAdminAlert({ gymName: "GB", ownerEmail: "coach@gym.com" });
    const input = client.sent[0] as { Destination: { ToAddresses: string[] } };
    expect(input.Destination.ToAddresses).toEqual(["admin@x.com"]);
  });
});

describe("UnconfiguredEmailService", () => {
  it("no-ops without throwing", async () => {
    const svc = new UnconfiguredEmailService();
    await svc.sendWaitlistConfirmation("user@x.com");
    expect(true).toBe(true);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apps/api && bun test test/email-service.test.mts`
Expected: FAIL — service not defined.

- [ ] **Step 4: Write the email service**

```ts
// apps/api/src/services/email.service.mts
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";
import { logger } from "../config/logger.mts";

export interface GymLeadSummary {
  gymName: string;
  ownerName?: string;
  ownerEmail: string;
  city?: string;
  state?: string;
  message?: string;
}

export interface EmailService {
  sendWaitlistConfirmation(to: string): Promise<void>;
  sendGymLeadConfirmation(to: string, gymName: string): Promise<void>;
  sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void>;
}

export interface EmailConfig {
  from: string;
  adminEmail: string;
}

// Minimal structural type so tests can inject a fake without the real client.
interface SesLike {
  send(cmd: SendEmailCommand): Promise<unknown>;
}

// Sends transactional emails via Amazon SES v2. Bodies are intentionally plain
// and short; richer templates can be swapped in later without touching callers.
export class SesEmailService implements EmailService {

  private readonly client: SesLike;

  public constructor(
    private readonly config: EmailConfig,
    client?: SesLike,
    region: string = "us-east-1",
  ) {
    this.client = client ?? new SESv2Client({ region });
  }

  private async send(to: string, subject: string, text: string): Promise<void> {
    const cmd = new SendEmailCommand({
      FromEmailAddress: this.config.from,
      Destination: { ToAddresses: [to] },
      Content: { Simple: { Subject: { Data: subject }, Body: { Text: { Data: text } } } },
    });
    await this.client.send(cmd);
  }

  public async sendWaitlistConfirmation(to: string): Promise<void> {
    await this.send(
      to,
      "You're on the BJJ Open Mat founding list 🥋",
      "Thanks for joining! You'll be first in line at launch, with a Founding Member badge.\n\n— BJJ Open Mat",
    );
  }

  public async sendGymLeadConfirmation(to: string, gymName: string): Promise<void> {
    await this.send(
      to,
      `We got your gym: ${gymName}`,
      `Thanks for claiming ${gymName} on BJJ Open Mat. We'll reach out with next steps.\n\n— BJJ Open Mat`,
    );
  }

  public async sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void> {
    const lines = [
      `New gym lead: ${lead.gymName}`,
      `Owner: ${lead.ownerName ?? "(not given)"} <${lead.ownerEmail}>`,
      `Location: ${[lead.city, lead.state].filter(Boolean).join(", ") || "(not given)"}`,
      `Message: ${lead.message ?? "(none)"}`,
    ];
    await this.send(this.config.adminEmail, `[BJJ Open Mat] Gym lead: ${lead.gymName}`, lines.join("\n"));
  }
}

// Used in local dev / tests when SES is not configured. Logs and no-ops.
export class UnconfiguredEmailService implements EmailService {

  public async sendWaitlistConfirmation(to: string): Promise<void> {
    logger.info(`[email:noop] waitlist confirmation -> ${to}`);
  }

  public async sendGymLeadConfirmation(to: string, gymName: string): Promise<void> {
    logger.info(`[email:noop] gym confirmation -> ${to} (${gymName})`);
  }

  public async sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void> {
    logger.info(`[email:noop] gym admin alert for ${lead.gymName}`);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/email-service.test.mts`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add apps/api/package.json apps/api/src/services/email.service.mts apps/api/test/email-service.test.mts ../../bun.lock
git commit -m "feat(api): add SES email service with unconfigured fallback"
```

---

### Task 5: Lead facade

**Files:**
- Create: `apps/api/src/facades/lead.facade.mts`
- Test: `apps/api/test/lead-facade.test.mts`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/lead-facade.test.mts
import { describe, expect, it, mock } from "bun:test";
import { LeadFacade } from "../src/facades/lead.facade.mts";
import type { EmailService } from "../src/services/email.service.mts";

function fakeEmail(): EmailService & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    async sendWaitlistConfirmation(): Promise<void> { calls.push("waitlist"); },
    async sendGymLeadConfirmation(): Promise<void> { calls.push("gymConfirm"); },
    async sendGymLeadAdminAlert(): Promise<void> { calls.push("gymAdmin"); },
  };
}

describe("LeadFacade.joinWaitlist", () => {
  it("persists then emails, returning confirmed", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "USER@X.com" });

    expect(res.status).toBe("confirmed");
    // email is lowercased before persistence
    const arg = (waitlist.upsertByEmail.mock.calls[0] as unknown[])[0] as { email: string };
    expect(arg.email).toBe("user@x.com");
    expect(email.calls).toEqual(["waitlist"]);
  });

  it("stays successful even if the email send throws", async () => {
    const email = fakeEmail();
    email.sendWaitlistConfirmation = async (): Promise<void> => { throw new Error("SES down"); };
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "user@x.com" });
    expect(res.status).toBe("confirmed");
  });

  it("does not send a second confirmation for a duplicate signup", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => false) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "dup@x.com" });
    expect(res.status).toBe("confirmed");
    expect(email.calls).toEqual([]);
  });
});

describe("LeadFacade.submitGymLead", () => {
  it("inserts, confirms the owner, and alerts the admin", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock(async () => undefined) };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.submitGymLead({ gymName: "GB", ownerEmail: "coach@gym.com" });
    expect(res.status).toBe("new");
    expect(gym.insert).toHaveBeenCalledTimes(1);
    expect(email.calls).toEqual(["gymConfirm", "gymAdmin"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/lead-facade.test.mts`
Expected: FAIL — `LeadFacade` not defined.

- [ ] **Step 3: Write the facade**

```ts
// apps/api/src/facades/lead.facade.mts
import type { GymLeadRequest, LeadResponse, WaitlistLead, WaitlistLeadRequest, GymLead } from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { WaitlistLeadRepository } from "../repositories/waitlist-lead.repository.mts";
import type { GymLeadRepository } from "../repositories/gym-lead.repository.mts";
import type { EmailService } from "../services/email.service.mts";

type IdFactory = () => string;

export class LeadFacade {

  public constructor(
    private readonly waitlist: Pick<WaitlistLeadRepository, "upsertByEmail">,
    private readonly gymLeads: Pick<GymLeadRepository, "insert">,
    private readonly email: EmailService,
    private readonly newId: IdFactory,
  ) {}

  public async joinWaitlist(req: WaitlistLeadRequest): Promise<LeadResponse> {
    const email = req.email.trim().toLowerCase();
    const lead: WaitlistLead = {
      id: this.newId(),
      email,
      status: "confirmed",
      source: req.source,
      utm: req.utm,
      createdAt: new Date().toISOString(),
      confirmationSentAt: new Date().toISOString(),
    };
    const isNew = await this.waitlist.upsertByEmail(lead);
    // Only email on first signup; re-submits succeed silently without a duplicate email.
    if (isNew) {
      try {
        await this.email.sendWaitlistConfirmation(email);
      } catch (err: unknown) {
        logger.warn(`Waitlist confirmation email failed for ${email}`, { err });
      }
    }
    return { status: "confirmed" };
  }

  public async submitGymLead(req: GymLeadRequest): Promise<LeadResponse> {
    const ownerEmail = req.ownerEmail.trim().toLowerCase();
    const lead: GymLead = {
      id: this.newId(),
      gymName: req.gymName.trim(),
      ownerName: req.ownerName,
      ownerEmail,
      city: req.city,
      state: req.state,
      message: req.message,
      status: "new",
      utm: req.utm,
      createdAt: new Date().toISOString(),
    };
    await this.gymLeads.insert(lead);
    try {
      await this.email.sendGymLeadConfirmation(ownerEmail, lead.gymName);
      await this.email.sendGymLeadAdminAlert({
        gymName: lead.gymName,
        ownerName: lead.ownerName,
        ownerEmail,
        city: lead.city,
        state: lead.state,
        message: lead.message,
      });
    } catch (err: unknown) {
      logger.warn(`Gym lead email failed for ${lead.gymName}`, { err });
    }
    return { status: "new" };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/lead-facade.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/lead.facade.mts apps/api/test/lead-facade.test.mts
git commit -m "feat(api): add lead facade orchestrating persistence + email"
```

---

### Task 6: Env config for SES + website origin

**Files:**
- Modify: `apps/api/src/config/env.mts`
- Test: `apps/api/test/env-lead.test.mts`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/env-lead.test.mts
import { describe, expect, it } from "bun:test";
import { loadEnv } from "../src/config/env.mts";

const base = {
  MONGODB_URI: "mongodb://localhost:27017",
  MONGODB_DB: "bjj",
  AUTH_BYPASS_SECRET: "s",
  DEMO_USER_ID: "u",
  DEMO_USER_ROLE: "gym_owner",
  DEMO_USER_EMAIL: "d@e.f",
};

describe("loadEnv lead/SES fields", () => {
  it("defaults website origins and leaves SES undefined when unset", () => {
    const env = loadEnv(base);
    expect(env.sesFrom).toBeUndefined();
    expect(env.websiteOrigins).toContain("http://localhost:4200");
  });

  it("reads SES + admin + origins when set", () => {
    const env = loadEnv({
      ...base,
      SES_FROM: "no-reply@dsylvester.ai",
      ADMIN_EMAIL: "admin@x.com",
      WEBSITE_ORIGIN: "https://bjj-open-mat.dsylvester.ai",
    });
    expect(env.sesFrom).toBe("no-reply@dsylvester.ai");
    expect(env.adminEmail).toBe("admin@x.com");
    expect(env.websiteOrigins).toContain("https://bjj-open-mat.dsylvester.ai");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/env-lead.test.mts`
Expected: FAIL — `sesFrom`/`websiteOrigins` missing.

- [ ] **Step 3: Extend the env schema + AppEnv**

In `apps/api/src/config/env.mts`, add these fields to `EnvSchema` (inside the `t.Object({...})`):

```ts
  SES_FROM: t.Optional(t.String()),
  SES_REGION: t.Optional(t.String()),
  ADMIN_EMAIL: t.Optional(t.String()),
  WEBSITE_ORIGIN: t.Optional(t.String()),
```

Add to the `AppEnv` interface:

```ts
  readonly sesFrom: string | undefined;
  readonly sesRegion: string;
  readonly adminEmail: string | undefined;
  readonly websiteOrigins: string[];
```

Add to the returned object in `loadEnv` (before the closing `};`):

```ts
    sesFrom: raw.SES_FROM,
    sesRegion: raw.SES_REGION ?? raw.ASSETS_REGION ?? "us-east-1",
    adminEmail: raw.ADMIN_EMAIL,
    websiteOrigins: [raw.WEBSITE_ORIGIN, "http://localhost:4200"].filter(
      (o): o is string => typeof o === "string" && o.length > 0,
    ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/env-lead.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/config/env.mts apps/api/test/env-lead.test.mts
git commit -m "feat(api): add SES + website-origin env configuration"
```

---

### Task 7: Wire the container

**Files:**
- Modify: `apps/api/src/container.mts`

- [ ] **Step 1: Add imports**

At the top of `apps/api/src/container.mts`, add:

```ts
import { LeadFacade } from "./facades/lead.facade.mts";
import { WaitlistLeadRepository } from "./repositories/waitlist-lead.repository.mts";
import { GymLeadRepository } from "./repositories/gym-lead.repository.mts";
import { SesEmailService, UnconfiguredEmailService, type EmailService } from "./services/email.service.mts";
```

- [ ] **Step 2: Add `leadFacade` to the `Container` interface**

Add to the `Container` interface:

```ts
  readonly leadFacade: LeadFacade;
```

- [ ] **Step 3: Construct repos, email service, and facade**

Inside `createContainer`, after the existing repo constructions add:

```ts
  const waitlistLeadRepo = new WaitlistLeadRepository(db);
  const gymLeadRepo = new GymLeadRepository(db);
  const emailService: EmailService =
    env.sesFrom && env.adminEmail
      ? new SesEmailService({ from: env.sesFrom, adminEmail: env.adminEmail }, undefined, env.sesRegion)
      : new UnconfiguredEmailService();
```

In the returned object add (near the other facades):

```ts
    leadFacade: new LeadFacade(waitlistLeadRepo, gymLeadRepo, emailService, id),
```

In `ensureIndexes`'s `Promise.all([...])` add:

```ts
        waitlistLeadRepo.ensureIndexes(),
        gymLeadRepo.ensureIndexes(),
```

- [ ] **Step 4: Verify it compiles + boots**

Run: `cd apps/api && bun test test/boot.test.mts`
Expected: PASS (existing boot test still green with the new wiring).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/container.mts
git commit -m "feat(api): wire lead repositories, email service, and facade into the container"
```

---

### Task 8: Public lead routes + CORS

**Files:**
- Create: `apps/api/src/routes/lead.routes.mts`
- Modify: `apps/api/src/app.mts`
- Test: `apps/api/test/lead-routes.test.mts`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/lead-routes.test.mts
import { describe, expect, it, mock } from "bun:test";
import { Elysia } from "elysia";
import { leadRoutes } from "../src/routes/lead.routes.mts";

function appWith(joinWaitlist: unknown, submitGymLead: unknown) {
  const container = { leadFacade: { joinWaitlist, submitGymLead } };
  return new Elysia().use(leadRoutes(container as never));
}

describe("POST /api/v1/waitlist", () => {
  it("accepts a valid email and returns confirmed", async () => {
    const join = mock(async () => ({ status: "confirmed" }));
    const app = appWith(join, mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "a@b.com" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ data: { status: "confirmed" } });
    expect(join).toHaveBeenCalledTimes(1);
  });

  it("silently drops honeypot submissions without calling the facade", async () => {
    const join = mock(async () => ({ status: "confirmed" }));
    const app = appWith(join, mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "a@b.com", hp: "i-am-a-bot" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(join).toHaveBeenCalledTimes(0);
  });

  it("rejects an invalid email with 422", async () => {
    const app = appWith(mock(), mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "nope" }),
      }),
    );
    expect(res.status).toBe(422);
  });
});

describe("POST /api/v1/gym-leads", () => {
  it("accepts a valid gym lead", async () => {
    const submit = mock(async () => ({ status: "new" }));
    const app = appWith(mock(), submit);
    const res = await app.handle(
      new Request("http://localhost/api/v1/gym-leads", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ gymName: "GB", ownerEmail: "c@g.com" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ data: { status: "new" } });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/lead-routes.test.mts`
Expected: FAIL — `leadRoutes` not defined.

- [ ] **Step 3: Write the routes**

```ts
// apps/api/src/routes/lead.routes.mts
import { Elysia } from "elysia";
import { GymLeadRequest, WaitlistLeadRequest } from "@bjj/contract";
import type { Container } from "../container.mts";
import { data } from "../http/envelope.mts";

// Public, unauthenticated lead capture for the marketing site. A non-empty
// honeypot (`hp`) field marks a bot: we return success without persisting.
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function leadRoutes(container: Container) {
  const { leadFacade } = container;

  return new Elysia({ prefix: "/api/v1" })
    .post(
      "/waitlist",
      async ({ body }) => {
        if (body.hp && body.hp.length > 0) return data({ status: "confirmed" as const });
        return data(await leadFacade.joinWaitlist(body));
      },
      { body: WaitlistLeadRequest },
    )
    .post(
      "/gym-leads",
      async ({ body }) => {
        if (body.hp && body.hp.length > 0) return data({ status: "new" as const });
        return data(await leadFacade.submitGymLead(body));
      },
      { body: GymLeadRequest },
    );
}
```

- [ ] **Step 4: Register the routes + scope CORS to the website origins**

In `apps/api/src/app.mts`:

1. Add the import:

```ts
import { leadRoutes } from "./routes/lead.routes.mts";
```

2. Change the `base` builder so CORS allows the configured origins. Replace `.use(cors())` with:

```ts
    .use(cors({ origin: container.env.websiteOrigins }))
```

3. Add `.use(leadRoutes(container))` to the returned chain (e.g. after `.use(reportRoutes(container))`).

> **Note:** `container.env` does not exist yet. Add `readonly env: AppEnv;` to the `Container` interface, `import type { AppEnv } from "./config/env.mts";`, and set `env,` in the returned object of `createContainer` (the `env` param is already in scope). This exposes the config to `app.mts` for CORS.

- [ ] **Step 5: Run test to verify it passes + full suite**

Run: `cd apps/api && bun test test/lead-routes.test.mts && bun test`
Expected: lead-routes PASS (4 tests); full suite green.

- [ ] **Step 6: Lint + commit**

```bash
cd apps/api && bun run lint
git add apps/api/src/routes/lead.routes.mts apps/api/src/app.mts apps/api/src/container.mts apps/api/test/lead-routes.test.mts
git commit -m "feat(api): add public waitlist + gym-lead endpoints with honeypot and scoped CORS"
```

---

### Task 9: OpenAPI + Postman docs

**Files:**
- Modify: `apps/api/src/openapi.mts` (add the two paths + schemas)

- [ ] **Step 1: Add the endpoints to the OpenAPI document**

In `apps/api/src/openapi.mts`, following the existing `paths`/`components` pattern, add `/api/v1/waitlist` and `/api/v1/gym-leads` POST entries referencing `WaitlistLeadRequest`/`GymLeadRequest` bodies and a `LeadResponse` data envelope. Mirror the shape of an existing public POST entry.

- [ ] **Step 2: Verify the document builds**

Run: `cd apps/api && bun test test/boot.test.mts` (boot builds the OpenAPI doc). If a dedicated openapi test exists, run it too.
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/api/src/openapi.mts
git commit -m "docs(api): document waitlist + gym-lead endpoints in OpenAPI"
```

**Phase 1 checkpoint:** Full `bun test` green, `bun run lint` clean. Endpoints live at `POST /api/v1/waitlist` and `POST /api/v1/gym-leads`. Manually smoke locally: `cd apps/api && bun src/index.mts`, then `curl -X POST localhost:3100/api/v1/waitlist -H 'content-type: application/json' -d '{"email":"you@example.com"}'` → `{"data":{"status":"confirmed"}}`.

---

# PHASE 2 — Website: Angular landing page (pixel-perfect)

> **Prerequisite:** The design reference is fetched via the DesignSync tool, which needs a claude.ai login. Before starting Task 11, ensure the user has run `/login` and selected "Claude account with subscription". Task 10 (scaffold) does not need it.

### Task 10: Scaffold the Angular app in `website/`

**Files:**
- Create: `website/` (Angular CLI output)
- Modify: repo root `.gitignore` (ignore `website/node_modules`, `website/dist`, `website/.angular`, `website/test-results`, `website/reference/*.png`)

- [ ] **Step 1: Generate the app**

Run from repo root:

```bash
npx -y @angular/cli@latest new website --style=scss --routing --ssr=false --skip-git --package-manager=bun
```

Expected: `website/angular.json`, `website/src/main.ts`, etc. created.

- [ ] **Step 2: Confirm it serves**

Run: `cd website && bun run start -- --port 4200` (or `npx ng serve --port 4200`).
Expected: dev server up at `http://localhost:4200` showing the Angular starter.

- [ ] **Step 3: Add ignores + commit scaffold**

Append to repo-root `.gitignore`:

```
website/node_modules/
website/dist/
website/.angular/
website/test-results/
website/reference/*.png
```

```bash
git add website .gitignore
git commit -m "chore(website): scaffold Angular landing app"
```

---

### Task 11: Fetch the design reference + capture reference screenshots

**Files:**
- Create: `website/reference/BJJ-Open-Mat-Landing.dc.html`
- Create: `website/reference/README.md` (how the references were produced)

- [ ] **Step 1: Fetch the design file**

Using the DesignSync tool: `get_file` with `projectId: 45ac103e-5117-445c-9d19-85dba1f3474f`, `path: "BJJ Open Mat Landing.dc.html"`. Save the returned HTML verbatim to `website/reference/BJJ-Open-Mat-Landing.dc.html`.

- [ ] **Step 2: Render + screenshot the reference at both viewports**

Open the saved HTML with the Playwright MCP browser (`browser_navigate` to `file://.../BJJ-Open-Mat-Landing.dc.html`), then:
- Resize to 390×844 (mobile) → `browser_take_screenshot` full page → save as `website/reference/ref-mobile.png`.
- Resize to 1280×900 (desktop) → full-page screenshot → save as `website/reference/ref-desktop.png`.

- [ ] **Step 3: Extract exact tokens**

Read the design HTML and record exact hex colors, font families/weights, spacing, border-radii, and shadows into `website/src/styles/_tokens.scss` (see Task 12). Cross-check against `docs/marketing/claude-design-prompt.md` (indigo `#5B53F2`, gold `#FFB020`, ink `#14151A`, body `#3D4150`, bg `#FFFFFF`/`#F5F6FA`, Plus Jakarta Sans 600/700/800).

- [ ] **Step 4: Commit the reference (HTML only; screenshots are gitignored)**

```bash
git add website/reference/BJJ-Open-Mat-Landing.dc.html website/reference/README.md
git commit -m "chore(website): add fetched design reference"
```

---

### Task 12: Brand tokens + global styles

**Files:**
- Create: `website/src/styles/_tokens.scss`
- Modify: `website/src/styles.scss`

- [ ] **Step 1: Write the tokens** (fill hex values with the exact ones extracted in Task 11)

```scss
// website/src/styles/_tokens.scss
:root {
  --indigo: #5B53F2;
  --indigo-deep: #4038D6;
  --gold: #FFB020;
  --ink: #14151A;
  --body: #3D4150;
  --muted: #6B7280;
  --bg: #FFFFFF;
  --bg-alt: #F5F6FA;
  --gi-blue: #2E7BFF;
  --nogi-orange: #FF7A33;
  --radius-card: 16px;
  --shadow-card: 0 8px 30px rgba(20, 21, 26, 0.08);
  --font-sans: 'Plus Jakarta Sans', system-ui, sans-serif;
}
```

- [ ] **Step 2: Import tokens + font in global styles**

At the top of `website/src/styles.scss`:

```scss
@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@600;700;800&display=swap');
@use 'styles/tokens';

* { box-sizing: border-box; }
body { margin: 0; font-family: var(--font-sans); color: var(--body); background: var(--bg); }
```

- [ ] **Step 3: Commit**

```bash
git add website/src/styles.scss website/src/styles/_tokens.scss
git commit -m "feat(website): add brand design tokens and global styles"
```

---

### Task 13: Lead API service + models

**Files:**
- Create: `website/src/app/core/models/i-lead.ts`
- Create: `website/src/app/core/lead-api.service.ts`
- Create: `website/src/environments/environment.ts`, `website/src/environments/environment.development.ts`
- Modify: `website/src/app/app.config.ts` (provide HttpClient)
- Test: `website/src/app/core/lead-api.service.spec.ts`

- [ ] **Step 1: Environments**

```ts
// website/src/environments/environment.ts
export const environment = { apiBaseUrl: 'https://api.bjj-open-mat.dsylvester.io' };
```
```ts
// website/src/environments/environment.development.ts
export const environment = { apiBaseUrl: 'http://localhost:3100' };
```

- [ ] **Step 2: Models**

```ts
// website/src/app/core/models/i-lead.ts
export interface Utm { source?: string; medium?: string; campaign?: string; }

export interface WaitlistRequest { email: string; source?: string; utm?: Utm; hp?: string; }

export interface GymLeadRequest {
  gymName: string; ownerName?: string; ownerEmail: string;
  city?: string; state?: string; message?: string; utm?: Utm; hp?: string;
}

export interface LeadResponse { status: 'confirmed' | 'new'; }
```

- [ ] **Step 3: Write the failing service test**

```ts
// website/src/app/core/lead-api.service.spec.ts
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { LeadApiService } from './lead-api.service';
import { environment } from '../../environments/environment';

describe('LeadApiService', () => {
  let svc: LeadApiService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting(), LeadApiService] });
    svc = TestBed.inject(LeadApiService);
    http = TestBed.inject(HttpTestingController);
  });

  it('POSTs the waitlist email and unwraps the envelope', async () => {
    const p = svc.joinWaitlist({ email: 'a@b.com' });
    const req = http.expectOne(`${environment.apiBaseUrl}/api/v1/waitlist`);
    expect(req.request.method).toBe('POST');
    req.flush({ data: { status: 'confirmed' } });
    expect((await p).status).toBe('confirmed');
  });
});
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd website && npx ng test --watch=false`
Expected: FAIL — `LeadApiService` not defined.

- [ ] **Step 5: Write the service**

```ts
// website/src/app/core/lead-api.service.ts
import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom, map } from 'rxjs';
import { environment } from '../../environments/environment';
import type { GymLeadRequest, LeadResponse, WaitlistRequest } from './models/i-lead';

interface Envelope<T> { data: T; }

@Injectable({ providedIn: 'root' })
export class LeadApiService {

  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  public joinWaitlist(req: WaitlistRequest): Promise<LeadResponse> {
    return firstValueFrom(
      this.http.post<Envelope<LeadResponse>>(`${this.base}/api/v1/waitlist`, req).pipe(map((e) => e.data)),
    );
  }

  public submitGymLead(req: GymLeadRequest): Promise<LeadResponse> {
    return firstValueFrom(
      this.http.post<Envelope<LeadResponse>>(`${this.base}/api/v1/gym-leads`, req).pipe(map((e) => e.data)),
    );
  }
}
```

- [ ] **Step 6: Provide HttpClient**

In `website/src/app/app.config.ts`, add `provideHttpClient()` (import from `@angular/common/http`) to the `providers` array.

- [ ] **Step 7: Run test to verify it passes**

Run: `cd website && npx ng test --watch=false`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add website/src/app/core website/src/environments website/src/app/app.config.ts
git commit -m "feat(website): add typed lead API service, models, and environments"
```

---

### Task 14: Landing page + section components

**Files:**
- Create: `website/src/app/landing/landing.component.{ts,html,scss}`
- Create section components under `website/src/app/landing/sections/`: `hero`, `how-it-works`, `features`, `gym-owner`, `faq`, `site-footer` (each `.ts/.html/.scss`)
- Modify: `website/src/app/app.routes.ts` (route `''` → `LandingComponent`)

- [ ] **Step 1: Generate components**

Run: `cd website && npx ng g c landing && npx ng g c landing/sections/hero && npx ng g c landing/sections/how-it-works && npx ng g c landing/sections/features && npx ng g c landing/sections/gym-owner && npx ng g c landing/sections/faq && npx ng g c landing/sections/site-footer`

- [ ] **Step 2: Compose the landing page**

`LandingComponent` template imports and stacks the section components (`<app-hero/>`, `<app-how-it-works/>`, `<app-features/>`, `<app-gym-owner/>`, `<app-faq/>`, `<app-site-footer/>`). Author each section's HTML/SCSS to reproduce the corresponding block of `website/reference/BJJ-Open-Mat-Landing.dc.html`, using the copy from `docs/marketing/landing-page-copy.md` and the tokens from Task 12. The `hero` includes the waitlist form (Task 15); `gym-owner` includes the gym-lead form (Task 15).

- [ ] **Step 3: Route to it**

In `website/src/app/app.routes.ts`:

```ts
import { Routes } from '@angular/router';
import { LandingComponent } from './landing/landing.component';

export const routes: Routes = [{ path: '', component: LandingComponent }];
```

- [ ] **Step 4: Verify it renders without errors**

Run: `cd website && npx ng build`
Expected: build succeeds. Serve and eyeball at `http://localhost:4200`.

- [ ] **Step 5: Commit**

```bash
git add website/src/app/landing website/src/app/app.routes.ts
git commit -m "feat(website): add landing page and section components"
```

---

### Task 15: Waitlist + gym-lead forms (signals)

**Files:**
- Create: `website/src/app/landing/forms/waitlist-form.component.{ts,html,scss}`
- Create: `website/src/app/landing/forms/gym-lead-form.component.{ts,html,scss}`
- Test: `website/src/app/landing/forms/waitlist-form.component.spec.ts`

- [ ] **Step 1: Write the failing component test**

```ts
// website/src/app/landing/forms/waitlist-form.component.spec.ts
import { TestBed } from '@angular/core/testing';
import { WaitlistFormComponent } from './waitlist-form.component';
import { LeadApiService } from '../../core/lead-api.service';

describe('WaitlistFormComponent', () => {
  it('shows success state after a successful submit', async () => {
    const api = { joinWaitlist: jasmine.createSpy().and.resolveTo({ status: 'confirmed' }) };
    await TestBed.configureTestingModule({
      imports: [WaitlistFormComponent],
      providers: [{ provide: LeadApiService, useValue: api }],
    }).compileComponents();
    const fixture = TestBed.createComponent(WaitlistFormComponent);
    const cmp = fixture.componentInstance;
    cmp.email.set('a@b.com');
    await cmp.submit();
    expect(api.joinWaitlist).toHaveBeenCalled();
    expect(cmp.state()).toBe('success');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd website && npx ng test --watch=false`
Expected: FAIL — component not defined.

- [ ] **Step 3: Write the waitlist form component**

```ts
// website/src/app/landing/forms/waitlist-form.component.ts
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { LeadApiService } from '../../core/lead-api.service';

type FormState = 'idle' | 'submitting' | 'success' | 'error';

@Component({
  selector: 'app-waitlist-form',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './waitlist-form.component.html',
  styleUrl: './waitlist-form.component.scss',
})
export class WaitlistFormComponent {

  private readonly api = inject(LeadApiService);

  public readonly email = signal('');
  public readonly hp = signal(''); // honeypot; kept visually hidden in template
  public readonly state = signal<FormState>('idle');

  public async submit(): Promise<void> {
    if (this.state() === 'submitting') return;
    this.state.set('submitting');
    try {
      const utm = this.readUtm();
      await this.api.joinWaitlist({ email: this.email(), hp: this.hp(), utm });
      this.state.set('success');
    } catch {
      this.state.set('error');
    }
  }

  private readUtm(): { source?: string; medium?: string; campaign?: string } {
    const p = new URLSearchParams(window.location.search);
    return {
      source: p.get('utm_source') ?? undefined,
      medium: p.get('utm_medium') ?? undefined,
      campaign: p.get('utm_campaign') ?? undefined,
    };
  }
}
```

Template `waitlist-form.component.html` (styled to match the design; honeypot hidden with a CSS class, not `type=hidden`, so bots fill it):

```html
@if (state() === 'success') {
  <p class="success">You're on the list 🥋 Check your inbox.</p>
} @else {
  <form (submit)="$event.preventDefault(); submit()">
    <input class="hp" type="text" tabindex="-1" autocomplete="off" aria-hidden="true"
           [ngModel]="hp()" (ngModelChange)="hp.set($event)" name="hp" />
    <input class="email" type="email" required placeholder="you@email.com"
           [ngModel]="email()" (ngModelChange)="email.set($event)" name="email" />
    <button type="submit" [disabled]="state() === 'submitting'">Join the founding list →</button>
    @if (state() === 'error') { <p class="error">Something went wrong — try again.</p> }
  </form>
  <p class="microcopy">Free. No spam. First access + a Founding Member badge at launch.</p>
}
```

Add `.hp { position: absolute; left: -9999px; }` to the component SCSS.

- [ ] **Step 4: Write the gym-lead form component** (same pattern, fields `gymName`, `ownerName`, `ownerEmail`, `city`, `state`, `message`, `hp`; calls `api.submitGymLead`; success copy "Thanks — we'll be in touch."). Mirror the structure above.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd website && npx ng test --watch=false`
Expected: PASS.

- [ ] **Step 6: Wire forms into sections**

Import `WaitlistFormComponent` into the `hero` section and `GymLeadFormComponent` into the `gym-owner` section; place them where the design shows the CTA form.

- [ ] **Step 7: Commit**

```bash
git add website/src/app/landing/forms website/src/app/landing/sections
git commit -m "feat(website): add signal-based waitlist and gym-lead forms"
```

---

### Task 16: Playwright — pixel-perfect visual regression loop

**Files:**
- Create: `website/playwright.config.ts`
- Create: `website/tests/visual.spec.ts`
- Modify: `website/package.json` (add `@playwright/test`, `pixelmatch`, `pngjs`; scripts)

- [ ] **Step 1: Install Playwright**

Run: `cd website && bun add -d @playwright/test pixelmatch pngjs && npx playwright install chromium`

- [ ] **Step 2: Playwright config**

```ts
// website/playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  webServer: {
    command: 'npx ng serve --port 4200 --configuration development',
    url: 'http://localhost:4200',
    reuseExistingServer: true,
    timeout: 120_000,
  },
  use: { baseURL: 'http://localhost:4200' },
  projects: [
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 900 } } },
  ],
});
```

- [ ] **Step 3: Write the visual diff spec**

```ts
// website/tests/visual.spec.ts
import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

// Compares the rendered Angular page against the design reference screenshot for
// the current project (mobile/desktop). Fails if > 2% of pixels differ.
test('landing page matches the design reference', async ({ page }, testInfo) => {
  const proj = testInfo.project.name; // 'mobile' | 'desktop'
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  const actualBuf = await page.screenshot({ fullPage: true });

  const expected = PNG.sync.read(readFileSync(`reference/ref-${proj}.png`));
  const actual = PNG.sync.read(actualBuf);
  const { width, height } = expected;
  // Resize guard: require the render to match reference dimensions closely.
  expect(Math.abs(actual.width - width)).toBeLessThanOrEqual(2);

  const diff = new PNG({ width, height });
  const mismatched = pixelmatch(
    expected.data,
    actual.data.subarray(0, expected.data.length),
    diff.data, width, height, { threshold: 0.1 },
  );
  const ratio = mismatched / (width * height);
  testInfo.attach(`diff-${proj}.png`, { body: PNG.sync.write(diff), contentType: 'image/png' });
  expect(ratio).toBeLessThan(0.02);
});
```

- [ ] **Step 4: Run the loop until it passes**

Run: `cd website && npx playwright test`
Expected initially: FAIL with a diff ratio > 0.02. Iterate on section SCSS/markup, re-run, and inspect the attached `diff-*.png` until both projects report ratio < 0.02 (≥98% match). Prioritize mobile.

> This is the core pixel-perfect loop. Do not consider Phase 2 done until both viewports pass. If the design uses assets (logo, images), export them from the reference HTML into `website/public/` and reference them.

- [ ] **Step 5: Add scripts + commit**

Add to `website/package.json` scripts: `"e2e": "playwright test"`, `"e2e:visual": "playwright test tests/visual.spec.ts"`.

```bash
git add website/playwright.config.ts website/tests/visual.spec.ts website/package.json
git commit -m "test(website): add pixel-perfect visual regression against design reference"
```

---

### Task 17: Playwright — form E2E (stubbed API)

**Files:**
- Create: `website/tests/forms.spec.ts`

- [ ] **Step 1: Write the E2E spec**

```ts
// website/tests/forms.spec.ts
import { test, expect } from '@playwright/test';

test('waitlist form shows success and posts to the API', async ({ page }) => {
  let posted: unknown = null;
  await page.route('**/api/v1/waitlist', async (route) => {
    posted = route.request().postDataJSON();
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: { status: 'confirmed' } }) });
  });

  await page.goto('/');
  await page.getByPlaceholder('you@email.com').first().fill('tester@example.com');
  await page.getByRole('button', { name: /join the founding list/i }).click();

  await expect(page.getByText(/on the list/i)).toBeVisible();
  expect((posted as { email: string }).email).toBe('tester@example.com');
});

test('gym-lead form submits and confirms', async ({ page }) => {
  await page.route('**/api/v1/gym-leads', (route) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ data: { status: 'new' } }) }),
  );
  await page.goto('/');
  await page.getByLabel(/gym name/i).fill('Test BJJ');
  await page.getByLabel(/email/i).last().fill('coach@test.com');
  await page.getByRole('button', { name: /claim your gym/i }).click();
  await expect(page.getByText(/be in touch/i)).toBeVisible();
});
```

- [ ] **Step 2: Run the E2E**

Run: `cd website && npx playwright test tests/forms.spec.ts`
Expected: PASS (2 tests). Adjust selectors/labels to match the actual form markup if needed.

- [ ] **Step 3: Commit**

```bash
git add website/tests/forms.spec.ts
git commit -m "test(website): add form submission E2E with stubbed API"
```

**Phase 2 checkpoint:** `npx ng test --watch=false` green, `npx playwright test` green (visual + forms, both viewports). Site is a pixel-perfect match to the design and both forms work against a stubbed API.

---

# PHASE 3 — Infra: hosting, SES, DNS

### Task 18: SES identity + Lambda grant + env in ApiStack

**Files:**
- Modify: `infra/lib/api-stack.ts`

- [ ] **Step 1: Add SES imports**

At the top of `infra/lib/api-stack.ts`:

```ts
import * as sesv2 from "aws-cdk-lib/aws-ses";
```

- [ ] **Step 2: Add constants + email identity + env + grant**

Near the other constants add:

```ts
const SES_FROM = "no-reply@dsylvester.ai";
const ADMIN_EMAIL = "davis.sylvester@davaco.com";
const WEBSITE_ORIGIN = "https://bjj-open-mat.dsylvester.ai";
```

Inside the constructor, create the SES domain identity (DKIM records are surfaced as outputs to add on Hostinger):

```ts
    // Verifies dsylvester.ai for SES so no-reply@dsylvester.ai can send. Easy DKIM
    // produces 3 CNAMEs that must be added to Hostinger DNS (see WebsiteStack DNS task).
    const emailIdentity = new sesv2.EmailIdentity(this, "SesDomainIdentity", {
      identity: sesv2.Identity.domain("dsylvester.ai"),
    });
    emailIdentity.dkimRecords.forEach((r, i) => {
      new CfnOutput(this, `SesDkim${i}`, { value: `${r.name} CNAME ${r.value}` });
    });
```

Add these entries to the Lambda's `environment` object:

```ts
        SES_FROM,
        ADMIN_EMAIL,
        WEBSITE_ORIGIN,
        SES_REGION: this.region,
```

After the function is created, grant SES send:

```ts
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ses:SendEmail"],
        resources: ["*"],
      }),
    );
```

- [ ] **Step 2b: Ensure the secret carries SES config at runtime**

The Lambda reads secrets at cold start (`APP_SECRET_ARN`). `SES_FROM`/`ADMIN_EMAIL` are passed as plain env above (non-secret), so no secret change is required. Confirm `resolveEnv`/`loadEnv` read these env vars (they do after Task 6).

- [ ] **Step 3: Synthesize**

Run: `cd infra && npx cdk synth BjjApiStack`
Expected: template synthesizes without error; SES identity + DKIM outputs present.

- [ ] **Step 4: Commit**

```bash
git add infra/lib/api-stack.ts
git commit -m "feat(infra): verify dsylvester.ai in SES and grant the API SES send"
```

---

### Task 19: WebsiteStack — S3 + CloudFront + ACM

**Files:**
- Create: `infra/lib/website-stack.ts`
- Modify: `infra/bin/infra.ts`

- [ ] **Step 1: Write the stack**

```ts
// infra/lib/website-stack.ts
import * as path from "node:path";
import { CfnOutput, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as s3deploy from "aws-cdk-lib/aws-s3-deployment";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";
import * as acm from "aws-cdk-lib/aws-certificatemanager";

const SITE_DOMAIN = "bjj-open-mat.dsylvester.ai";

// Static hosting for the Angular marketing site. Private S3 bucket fronted by
// CloudFront (OAC). The ACM cert is DNS-validated on Hostinger (dsylvester.ai is
// NOT in Route 53), so the validation records are emitted as outputs to add by hand.
export class WebsiteStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    const repoRoot = path.resolve(process.cwd(), "..");

    const bucket = new s3.Bucket(this, "SiteBucket", {
      bucketName: "bjj-open-mat-website",
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    // CloudFront needs the cert in us-east-1. This stack MUST be deployed to
    // us-east-1 (set in bin/infra.ts). DNS validation is manual on Hostinger.
    const certificate = new acm.Certificate(this, "SiteCert", {
      domainName: SITE_DOMAIN,
      validation: acm.CertificateValidation.fromDns(), // no hosted zone -> emits CNAME to add manually
    });

    const distribution = new cloudfront.Distribution(this, "SiteDistribution", {
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(bucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      },
      domainNames: [SITE_DOMAIN],
      certificate,
      defaultRootObject: "index.html",
      // SPA fallback: serve index.html for client-routed 403/404s.
      errorResponses: [
        { httpStatus: 403, responseHttpStatus: 200, responsePagePath: "/index.html" },
        { httpStatus: 404, responseHttpStatus: 200, responsePagePath: "/index.html" },
      ],
    });

    new s3deploy.BucketDeployment(this, "DeploySite", {
      sources: [s3deploy.Source.asset(path.join(repoRoot, "website/dist/website/browser"))],
      destinationBucket: bucket,
      distribution,
      distributionPaths: ["/*"],
    });

    new CfnOutput(this, "DistributionDomain", { value: distribution.distributionDomainName });
    new CfnOutput(this, "SiteUrl", { value: `https://${SITE_DOMAIN}` });
  }
}
```

> Confirm the Angular build output path: after `ng build`, check whether files land in `website/dist/website/browser` (Angular ≥17 default) and adjust the `Source.asset` path if the project name differs.

- [ ] **Step 2: Register the stack in us-east-1**

In `infra/bin/infra.ts`, import and instantiate:

```ts
import { WebsiteStack } from "../lib/website-stack.js";
// ...
new WebsiteStack(app, "BjjWebsiteStack", { env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: "us-east-1" } });
```

(Match the existing import/style used for `ApiStack` in that file — check whether it uses `.js` specifiers or not, and mirror it.)

- [ ] **Step 3: Build the site + synth**

Run: `cd website && npx ng build && cd ../infra && npx cdk synth BjjWebsiteStack`
Expected: synth succeeds referencing the built assets.

- [ ] **Step 4: Commit**

```bash
git add infra/lib/website-stack.ts infra/bin/infra.ts
git commit -m "feat(infra): add website stack (S3 + CloudFront + ACM) for dsylvester.ai"
```

---

### Task 20: Deploy + DNS on Hostinger

**Files:** none (operational task; uses the `hostinger-dns` agent)

- [ ] **Step 1: Deploy the API stack** (SES identity + updated env)

Run: `cd infra && npx cdk deploy BjjApiStack`
Expected: outputs include `SesDkim0/1/2` CNAME records.

- [ ] **Step 2: Deploy the website stack (will pause on cert validation)**

Run: `cd infra && npx cdk deploy BjjWebsiteStack`
Expected: it prints the ACM validation CNAME and waits. Note the CNAME (name + value).

- [ ] **Step 3: Add DNS records on Hostinger**

Dispatch the `hostinger-dns` agent for `dsylvester.ai` to add:
- The **ACM validation CNAME** (from Step 2) — so the cert validates and the deploy completes.
- The **3 SES DKIM CNAMEs** (from Step 1 outputs).
- **SPF** TXT: `v=spf1 include:amazonses.com ~all` on `dsylvester.ai`.
- **DMARC** TXT on `_dmarc.dsylvester.ai`: `v=DMARC1; p=none; rua=mailto:davis.sylvester@davaco.com`.
- The site **CNAME**: `bjj-open-mat.dsylvester.ai` → the `DistributionDomain` CloudFront domain (from the WebsiteStack output).

- [ ] **Step 4: Confirm cert validation + finish deploy**

Once the ACM CNAME propagates, `BjjWebsiteStack` deploy finishes on its own (or re-run `npx cdk deploy BjjWebsiteStack`).
Expected: `SiteUrl` output `https://bjj-open-mat.dsylvester.ai`.

- [ ] **Step 5: Request SES production access (launch prerequisite)**

In the SES console (us-east-1), request production access to leave the sandbox. Until then, verify test recipient addresses so confirmation emails deliver during testing.

- [ ] **Step 6: Live smoke test**

- Visit `https://bjj-open-mat.dsylvester.ai` — page loads over HTTPS.
- Submit the waitlist form with a **verified** test email → success state shown; confirmation email received; a `waitlistLeads` doc exists in Mongo.
- Submit the gym form → success; owner confirmation + admin alert emails received; `gymLeads` doc exists.
- Confirm cross-origin works (browser devtools: no CORS error; `WEBSITE_ORIGIN` is allowed).

- [ ] **Step 7: Document + commit**

Create `docs/website-deploy.md` capturing the URLs, the DNS records added, SES status, and the redeploy command (`cd website && ng build && cd ../infra && cdk deploy BjjWebsiteStack`).

```bash
git add docs/website-deploy.md
git commit -m "docs(website): add deployment + DNS runbook"
```

**Phase 3 checkpoint:** Site live at `https://bjj-open-mat.dsylvester.ai`, both forms persist to Mongo and send SES email (to verified recipients until production access is granted), DNS + DKIM/SPF/DMARC in place on Hostinger.

---

## Self-Review Notes (author checklist — completed)

- **Spec coverage:** website (Tasks 10–17) ✓; two public endpoints (Tasks 1–9) ✓; Mongo persistence (Task 3) ✓; SES email + admin alert (Tasks 4–5, 18) ✓; idempotent waitlist (Tasks 3, 5) ✓; honeypot + CORS (Tasks 6, 8) ✓; pixel-perfect Playwright verify (Tasks 11, 16) ✓; AWS hosting + Hostinger DNS on dsylvester.ai (Tasks 19–20) ✓; SES sandbox caveat (Task 20 Step 5) ✓; error handling non-fatal email (Task 5) ✓.
- **Type consistency:** `WaitlistLeadRequest`/`GymLeadRequest`/`LeadResponse` used identically across contract, facade, routes, and Angular models; `upsertByEmail` (returns `boolean` isNew) used consistently in repo/facade/tests; `EmailService` method names match across service, facade, and tests.
- **Placeholder scan:** No TBD/TODO left. The only intentionally open items are values to be read from the fetched design (exact hex/spacing in Task 11/12) and the Angular build output path (Task 19 Step 1), both flagged with explicit verification steps.
