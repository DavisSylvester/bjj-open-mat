# Member Messaging — M1 (Core Messaging) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gym-community messaging on the existing stack — 1:1 and group conversations gated to shared-gym members, gym-wide channels members read and reply to, plus block/report/admin-delete/leave-mute moderation, all delivered by polling.

**Architecture:** TypeBox contracts (`@bjj/contract`) → MongoDB repositories → a single `MessagingFacade` (all authorization + orchestration) → Elysia routes via DI → Flutter + Riverpod client polling. Reuses `assertActiveMember` / `assertCanManageGym` and `MembershipRepository.listByUser`; adds a `sharesActiveGym` helper. Unified `Conversation` model (`kind` enum), explicit participants for direct/group, implicit channel membership with a lazy `ChannelReadState`.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^7`), Flutter + Riverpod + Dio. Tests: `bun test` (API/contract), `flutter test` (mobile).

**Spec:** `docs/superpowers/specs/2026-07-29-messaging-m1-design.md`. This is M1; M2 (realtime) and M3 (push) are separate later plans that layer onto this persisted model.

## Global Constraints

- TypeScript strict; **no `any`**; explicit return types + access modifiers; explicit variable types.
- TypeBox only (never Zod). Schema-first, `Static<typeof X>`, `$id` on every schema.
- `.mts` source; import specifiers use `.mjs`. Contract TEST files import from source (`../src/index.mts`). One concern per file; barrel via `index.mts`; named exports.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `debugPrint`.
- Layering router → facade → repository; DI via `container.mts`, no `new` in routers. Repo deps via `Pick<>`.
- MongoDB driver `mongodb@^7`. `null !== undefined` care on optional fields; Mongo rejects empty `$set`; never put a field in both `$set` and `$setOnInsert`. Clear optional fields via a `$set`/`$unset` split (forum-question repo precedent).
- Route param is `:id` where it collides at a path position (memoirist). Gym-scoped creates under `/api/v1/gyms/:id/...`; the rest under `/api/v1/messaging/...`.
- Health endpoints `/health` and `/ready` only.
- Conventional Commits; **never** add Co-Authored-By. Do NOT commit `packages/contract/src/index.mjs` (gitignored). Commit per task.
- Run `bunx eslint --fix` on changed `apps/api`/`packages/contract` files before each commit; `flutter analyze` clean on changed mobile files.
- Repo tests need Mongo on `localhost:27017`.
- Authorization signatures: `assertActiveMember(deps, userId, gymId, role)`, `assertCanManageGym(deps, callerId, gymId, callerRole)` where `deps = { gyms: { findById }, memberships: { find } }`.

---

## File Structure

**`packages/contract/src`**
- `enums/conversation-kind.mts`, `enums/participant-role.mts`, `enums/message-report-reason.mts`, `enums/message-report-status.mts` (+ `enums/index.mts`)
- `schemas/conversation.mts`, `schemas/message.mts`, `schemas/conversation-participant.mts`, `schemas/channel-read-state.mts`, `schemas/user-block.mts`, `schemas/message-report.mts`, `schemas/conversation-summary.mts` (+ `schemas/index.mts`)
- `schemas/requests/messaging-requests.mts` (+ `schemas/requests/index.mts`)

**`apps/api/src`**
- `repositories/conversation.repository.mts`, `message.repository.mts`, `conversation-participant.repository.mts`, `channel-read-state.repository.mts`, `user-block.repository.mts`, `message-report.repository.mts`
- `facades/messaging.facade.mts`
- `routes/messaging.routes.mts`
- Modify: `db/collections.mts`, `container.mts`, `app.mts`, `openapi.mts`

**`apps/mobile/lib/features/messaging`**
- `models/conversation.dart`, `message.dart`, `conversation_participant.dart`, `conversation_summary.dart`, `message_report.dart`, `user_block.dart`
- `data/messaging_repository.dart` (+ providers)
- `screens/conversations_screen.dart`, `conversation_screen.dart`, `new_message_screen.dart`, `blocked_users_screen.dart`, `gym_reports_screen.dart`
- Modify: `core/api/endpoints.dart`, `app/router.dart`, `features/gyms/screens/gym_detail_screen.dart`, `features/settings/screens/settings_screen.dart`

---

## Task 1: Messaging enums

**Files:**
- Create: `packages/contract/src/enums/conversation-kind.mts`, `enums/participant-role.mts`, `enums/message-report-reason.mts`, `enums/message-report-status.mts`
- Modify: `packages/contract/src/enums/index.mts`
- Test: `packages/contract/test/messaging-enums.test.mts`

**Interfaces:**
- Produces `ConversationKind` = `'direct'|'group'|'gym_channel'`; `ParticipantRole` = `'member'|'admin'`; `MessageReportReason` = `'spam'|'harassment'|'inappropriate'|'other'`; `MessageReportStatus` = `'open'|'reviewed'|'dismissed'`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/messaging-enums.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { ConversationKind, ParticipantRole, MessageReportReason, MessageReportStatus } from "../src/index.mts";

describe("messaging enums", () => {
  it("ConversationKind", () => {
    expect(Value.Check(ConversationKind, "direct")).toBe(true);
    expect(Value.Check(ConversationKind, "gym_channel")).toBe(true);
    expect(Value.Check(ConversationKind, "nope")).toBe(false);
  });
  it("ParticipantRole", () => {
    expect(Value.Check(ParticipantRole, "admin")).toBe(true);
    expect(Value.Check(ParticipantRole, "owner")).toBe(false);
  });
  it("report reason + status", () => {
    expect(Value.Check(MessageReportReason, "harassment")).toBe(true);
    expect(Value.Check(MessageReportReason, "other")).toBe(true);
    expect(Value.Check(MessageReportStatus, "open")).toBe(true);
    expect(Value.Check(MessageReportStatus, "closed")).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/messaging-enums.test.mts`
Expected: FAIL — not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/enums/conversation-kind.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ConversationKind = t.Union(
  [t.Literal("direct"), t.Literal("group"), t.Literal("gym_channel")],
  { $id: "ConversationKind" },
);
export type ConversationKind = Static<typeof ConversationKind>;
```

```ts
// packages/contract/src/enums/participant-role.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ParticipantRole = t.Union(
  [t.Literal("member"), t.Literal("admin")],
  { $id: "ParticipantRole" },
);
export type ParticipantRole = Static<typeof ParticipantRole>;
```

```ts
// packages/contract/src/enums/message-report-reason.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const MessageReportReason = t.Union(
  [t.Literal("spam"), t.Literal("harassment"), t.Literal("inappropriate"), t.Literal("other")],
  { $id: "MessageReportReason" },
);
export type MessageReportReason = Static<typeof MessageReportReason>;
```

```ts
// packages/contract/src/enums/message-report-status.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const MessageReportStatus = t.Union(
  [t.Literal("open"), t.Literal("reviewed"), t.Literal("dismissed")],
  { $id: "MessageReportStatus" },
);
export type MessageReportStatus = Static<typeof MessageReportStatus>;
```

Append to `enums/index.mts`:
```ts
export * from "./conversation-kind.mts";
export * from "./participant-role.mts";
export * from "./message-report-reason.mts";
export * from "./message-report-status.mts";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/messaging-enums.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/enums packages/contract/test/messaging-enums.test.mts
git commit -m "feat(contract): messaging enums (kind, participant role, report reason/status)"
```

---

## Task 2: Core messaging schemas

**Files:**
- Create: `packages/contract/src/schemas/conversation.mts`, `message.mts`, `conversation-participant.mts`, `channel-read-state.mts`, `user-block.mts`, `message-report.mts`, `conversation-summary.mts`
- Modify: `packages/contract/src/schemas/index.mts`
- Test: `packages/contract/test/messaging-schema.test.mts`

**Interfaces:**
- `Conversation` = `{ id, kind: ConversationKind, gymId?, title?, pairKey?, createdBy, createdAt?, lastMessageAt?, lastMessagePreview? }`
- `Message` = `{ id, conversationId, authorId, body: String(minLength 1), createdAt?, editedAt?, deletedAt? }`
- `ConversationParticipant` = `{ id, conversationId, userId, role: ParticipantRole(default 'member'), lastReadAt?, muted: Boolean(default false), leftAt? }`
- `ChannelReadState` = `{ id, channelId, userId, lastReadAt?, muted: Boolean(default false) }`
- `UserBlock` = `{ id, blockerId, blockedId, createdAt? }`
- `MessageReport` = `{ id, messageId?, reportedUserId, reporterId, gymId, reason: MessageReportReason, note?, status: MessageReportStatus(default 'open'), createdAt?, reviewedAt? }`
- `ConversationSummary` = `{ conversation: Conversation, unreadCount: Integer(default 0), muted: Boolean(default false), lastMessage?: Message, otherParticipantIds: String[] }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/messaging-schema.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { Conversation, Message, ConversationParticipant, ChannelReadState, UserBlock, MessageReport, ConversationSummary } from "../src/index.mts";

describe("messaging schemas", () => {
  it("Conversation parses a direct convo with pairKey", () => {
    const c = Value.Parse(Conversation, { id: "c1", kind: "direct", pairKey: "u1|u2", createdBy: "u1" });
    expect(c.kind).toBe("direct");
    expect(c.pairKey).toBe("u1|u2");
  });
  it("Message requires non-empty body", () => {
    expect(Value.Check(Message, { id: "m1", conversationId: "c1", authorId: "u1", body: "hi" })).toBe(true);
    expect(Value.Check(Message, { id: "m1", conversationId: "c1", authorId: "u1", body: "" })).toBe(false);
  });
  it("ConversationParticipant defaults role member + not muted", () => {
    const p = Value.Parse(ConversationParticipant, { id: "p1", conversationId: "c1", userId: "u1" });
    expect(p.role).toBe("member");
    expect(p.muted).toBe(false);
  });
  it("ChannelReadState defaults muted false", () => {
    const s = Value.Parse(ChannelReadState, { id: "s1", channelId: "c1", userId: "u1" });
    expect(s.muted).toBe(false);
  });
  it("UserBlock + MessageReport + ConversationSummary check", () => {
    expect(Value.Check(UserBlock, { id: "b1", blockerId: "u1", blockedId: "u2" })).toBe(true);
    const r = Value.Parse(MessageReport, { id: "r1", reportedUserId: "u2", reporterId: "u1", gymId: "g1", reason: "spam" });
    expect(r.status).toBe("open");
    expect(Value.Check(ConversationSummary, {
      conversation: { id: "c1", kind: "group", gymId: "g1", title: "T", createdBy: "u1" },
      unreadCount: 2, muted: false, otherParticipantIds: ["u2"],
    })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/messaging-schema.test.mts`
Expected: FAIL — schemas not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/conversation.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { ConversationKind } from "../enums/conversation-kind.mts";

export const Conversation = t.Object(
  {
    id: t.String(),
    kind: ConversationKind,
    gymId: t.Optional(t.String()),
    title: t.Optional(t.String()),
    pairKey: t.Optional(t.String()),
    createdBy: t.String(),
    createdAt: t.Optional(t.String()),
    lastMessageAt: t.Optional(t.String()),
    lastMessagePreview: t.Optional(t.String()),
  },
  { $id: "Conversation" },
);
export type Conversation = Static<typeof Conversation>;
```

```ts
// packages/contract/src/schemas/message.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const Message = t.Object(
  {
    id: t.String(),
    conversationId: t.String(),
    authorId: t.String(),
    body: t.String({ minLength: 1 }),
    createdAt: t.Optional(t.String()),
    editedAt: t.Optional(t.String()),
    deletedAt: t.Optional(t.String()),
  },
  { $id: "Message" },
);
export type Message = Static<typeof Message>;
```

```ts
// packages/contract/src/schemas/conversation-participant.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { ParticipantRole } from "../enums/participant-role.mts";

export const ConversationParticipant = t.Object(
  {
    id: t.String(),
    conversationId: t.String(),
    userId: t.String(),
    role: t.Union([ParticipantRole], { default: "member" }),
    lastReadAt: t.Optional(t.String()),
    muted: t.Boolean({ default: false }),
    leftAt: t.Optional(t.String()),
  },
  { $id: "ConversationParticipant" },
);
export type ConversationParticipant = Static<typeof ConversationParticipant>;
```

> Note: `t.Union([ParticipantRole], { default: "member" })` wraps to attach the default without mutating the shared `ParticipantRole` schema. Equivalent alternative: `t.Unsafe<ParticipantRole>({ ...ParticipantRole, default: "member" })`. Use the wrapper form above.

```ts
// packages/contract/src/schemas/channel-read-state.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const ChannelReadState = t.Object(
  {
    id: t.String(),
    channelId: t.String(),
    userId: t.String(),
    lastReadAt: t.Optional(t.String()),
    muted: t.Boolean({ default: false }),
  },
  { $id: "ChannelReadState" },
);
export type ChannelReadState = Static<typeof ChannelReadState>;
```

```ts
// packages/contract/src/schemas/user-block.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const UserBlock = t.Object(
  {
    id: t.String(),
    blockerId: t.String(),
    blockedId: t.String(),
    createdAt: t.Optional(t.String()),
  },
  { $id: "UserBlock" },
);
export type UserBlock = Static<typeof UserBlock>;
```

```ts
// packages/contract/src/schemas/message-report.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { MessageReportReason } from "../enums/message-report-reason.mts";
import { MessageReportStatus } from "../enums/message-report-status.mts";

export const MessageReport = t.Object(
  {
    id: t.String(),
    messageId: t.Optional(t.String()),
    reportedUserId: t.String(),
    reporterId: t.String(),
    gymId: t.String(),
    reason: MessageReportReason,
    note: t.Optional(t.String()),
    status: t.Union([MessageReportStatus], { default: "open" }),
    createdAt: t.Optional(t.String()),
    reviewedAt: t.Optional(t.String()),
  },
  { $id: "MessageReport" },
);
export type MessageReport = Static<typeof MessageReport>;
```

```ts
// packages/contract/src/schemas/conversation-summary.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { Conversation } from "./conversation.mts";
import { Message } from "./message.mts";

export const ConversationSummary = t.Object(
  {
    conversation: Conversation,
    unreadCount: t.Integer({ minimum: 0, default: 0 }),
    muted: t.Boolean({ default: false }),
    lastMessage: t.Optional(Message),
    otherParticipantIds: t.Array(t.String()),
  },
  { $id: "ConversationSummary" },
);
export type ConversationSummary = Static<typeof ConversationSummary>;
```

Add to `schemas/index.mts`:
```ts
export * from "./conversation.mts";
export * from "./message.mts";
export * from "./conversation-participant.mts";
export * from "./channel-read-state.mts";
export * from "./user-block.mts";
export * from "./message-report.mts";
export * from "./conversation-summary.mts";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/messaging-schema.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/schemas packages/contract/test/messaging-schema.test.mts
git commit -m "feat(contract): messaging core schemas (conversation, message, participant, read-state, block, report, summary)"
```

---

## Task 3: Messaging request schemas

**Files:**
- Create: `packages/contract/src/schemas/requests/messaging-requests.mts`
- Modify: `packages/contract/src/schemas/requests/index.mts`
- Test: `packages/contract/test/messaging-requests.test.mts`

**Interfaces:**
- `StartDirectRequest` = `{ recipientId }`
- `CreateGroupRequest` = `{ gymId, title(minLength 1), participantIds: String[](minItems 1) }`
- `CreateChannelRequest` = `{ title(minLength 1) }`
- `SendMessageRequest` = `{ body(minLength 1) }`
- `EditMessageRequest` = `{ body(minLength 1) }`
- `AddParticipantsRequest` = `{ userIds: String[](minItems 1) }`
- `SetMutedRequest` = `{ muted: Boolean }`
- `BlockUserRequest` = `{ userId }`
- `ReportMessageRequest` = `{ messageId?, reportedUserId, reason: MessageReportReason, note? }`
- `ResolveReportRequest` = `{ status: MessageReportStatus }`
- `ConversationListQuery` = `{ page?: Integer≥1 default 1, limit?: Integer 1..100 default 20 }`
- `MessageListQuery` = `{ before?: String, limit?: Integer 1..100 default 30 }`

- [ ] **Step 1: Write the failing test**

```ts
// packages/contract/test/messaging-requests.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { StartDirectRequest, CreateGroupRequest, CreateChannelRequest, SendMessageRequest, AddParticipantsRequest, ReportMessageRequest, ResolveReportRequest } from "../src/index.mts";

describe("messaging requests", () => {
  it("StartDirectRequest requires recipientId", () => {
    expect(Value.Check(StartDirectRequest, { recipientId: "u2" })).toBe(true);
    expect(Value.Check(StartDirectRequest, {})).toBe(false);
  });
  it("CreateGroupRequest requires gym+title+≥1 participant", () => {
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "Squad", participantIds: ["u2"] })).toBe(true);
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "Squad", participantIds: [] })).toBe(false);
    expect(Value.Check(CreateGroupRequest, { gymId: "g1", title: "", participantIds: ["u2"] })).toBe(false);
  });
  it("CreateChannelRequest + SendMessageRequest need non-empty strings", () => {
    expect(Value.Check(CreateChannelRequest, { title: "General" })).toBe(true);
    expect(Value.Check(SendMessageRequest, { body: "" })).toBe(false);
  });
  it("AddParticipantsRequest needs ≥1 user", () => {
    expect(Value.Check(AddParticipantsRequest, { userIds: ["u3"] })).toBe(true);
    expect(Value.Check(AddParticipantsRequest, { userIds: [] })).toBe(false);
  });
  it("ReportMessageRequest requires reportedUserId+reason; ResolveReportRequest requires status", () => {
    expect(Value.Check(ReportMessageRequest, { reportedUserId: "u2", reason: "spam" })).toBe(true);
    expect(Value.Check(ReportMessageRequest, { reason: "spam" })).toBe(false);
    expect(Value.Check(ResolveReportRequest, { status: "reviewed" })).toBe(true);
    expect(Value.Check(ResolveReportRequest, { status: "open" })).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/messaging-requests.test.mts`
Expected: FAIL — not exported.

- [ ] **Step 3: Write minimal implementation**

```ts
// packages/contract/src/schemas/requests/messaging-requests.mts
import { type Static, Type as t } from "@sinclair/typebox";
import { MessageReportReason } from "../../enums/message-report-reason.mts";
import { MessageReportStatus } from "../../enums/message-report-status.mts";

export const StartDirectRequest = t.Object({ recipientId: t.String() }, { $id: "StartDirectRequest" });
export type StartDirectRequest = Static<typeof StartDirectRequest>;

export const CreateGroupRequest = t.Object(
  { gymId: t.String(), title: t.String({ minLength: 1 }), participantIds: t.Array(t.String(), { minItems: 1 }) },
  { $id: "CreateGroupRequest" },
);
export type CreateGroupRequest = Static<typeof CreateGroupRequest>;

export const CreateChannelRequest = t.Object({ title: t.String({ minLength: 1 }) }, { $id: "CreateChannelRequest" });
export type CreateChannelRequest = Static<typeof CreateChannelRequest>;

export const SendMessageRequest = t.Object({ body: t.String({ minLength: 1 }) }, { $id: "SendMessageRequest" });
export type SendMessageRequest = Static<typeof SendMessageRequest>;

export const EditMessageRequest = t.Object({ body: t.String({ minLength: 1 }) }, { $id: "EditMessageRequest" });
export type EditMessageRequest = Static<typeof EditMessageRequest>;

export const AddParticipantsRequest = t.Object({ userIds: t.Array(t.String(), { minItems: 1 }) }, { $id: "AddParticipantsRequest" });
export type AddParticipantsRequest = Static<typeof AddParticipantsRequest>;

export const SetMutedRequest = t.Object({ muted: t.Boolean() }, { $id: "SetMutedRequest" });
export type SetMutedRequest = Static<typeof SetMutedRequest>;

export const BlockUserRequest = t.Object({ userId: t.String() }, { $id: "BlockUserRequest" });
export type BlockUserRequest = Static<typeof BlockUserRequest>;

export const ReportMessageRequest = t.Object(
  { messageId: t.Optional(t.String()), reportedUserId: t.String(), reason: MessageReportReason, note: t.Optional(t.String()) },
  { $id: "ReportMessageRequest" },
);
export type ReportMessageRequest = Static<typeof ReportMessageRequest>;

export const ResolveReportRequest = t.Object({ status: MessageReportStatus }, { $id: "ResolveReportRequest" });
export type ResolveReportRequest = Static<typeof ResolveReportRequest>;

export const ConversationListQuery = t.Object(
  { page: t.Optional(t.Integer({ minimum: 1, default: 1 })), limit: t.Optional(t.Integer({ minimum: 1, maximum: 100, default: 20 })) },
  { $id: "ConversationListQuery" },
);
export type ConversationListQuery = Static<typeof ConversationListQuery>;

export const MessageListQuery = t.Object(
  { before: t.Optional(t.String()), limit: t.Optional(t.Integer({ minimum: 1, maximum: 100, default: 30 })) },
  { $id: "MessageListQuery" },
);
export type MessageListQuery = Static<typeof MessageListQuery>;
```

Add to `schemas/requests/index.mts`: `export * from "./messaging-requests.mts";`

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/messaging-requests.test.mts`; then full `cd packages/contract && bun test`.
Expected: PASS (all green).

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src packages/contract/test/messaging-requests.test.mts
git commit -m "feat(contract): messaging request schemas"
```

---

## Task 4: collections + `ConversationRepository`

**Files:**
- Create: `apps/api/src/repositories/conversation.repository.mts`
- Modify: `apps/api/src/db/collections.mts` (add `conversations`, `messages`, `conversationParticipants`, `channelReadStates`, `userBlocks`, `messageReports`)
- Test: `apps/api/test/conversation.repository.test.mts`

**Interfaces:**
- Consumes `Conversation`, `COLLECTIONS.conversations`.
- Produces `ConversationRepository`:
  - `ensureIndexes()` — `{ pairKey: 1 }` (unique, sparse), `{ kind: 1, gymId: 1 }`, `{ lastMessageAt: -1 }`.
  - `insert(c: Conversation): Promise<Conversation>`
  - `findById(id): Promise<Conversation | null>`
  - `findDirectByPairKey(pairKey): Promise<Conversation | null>`
  - `listChannelsByGym(gymId): Promise<Conversation[]>` — `kind: 'gym_channel'`, sorted `lastMessageAt` desc then `createdAt` asc.
  - `updateLastMessage(id, at: string, preview: string): Promise<void>`
  - `update(id, patch: Partial<Conversation>): Promise<Conversation | null>` — no-op empty patch; `$set`/`$unset` split (undefined → `$unset`).
  - `delete(id): Promise<void>`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/conversation.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ConversationRepository } from "../src/repositories/conversation.repository.mts";
import type { Conversation } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_conversations");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const conv = (over: Partial<Conversation>): Conversation => ({
  id: over.id ?? "c1", kind: over.kind ?? "direct", createdBy: "u1",
  createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("ConversationRepository", () => {
  it("find-or-create direct by pairKey", async () => {
    const repo = new ConversationRepository(db);
    await repo.ensureIndexes();
    await repo.insert(conv({ id: "d1", kind: "direct", pairKey: "u1|u2" }));
    const found = await repo.findDirectByPairKey("u1|u2");
    expect(found?.id).toBe("d1");
    expect(await repo.findDirectByPairKey("u1|u9")).toBeNull();
  });

  it("lists gym channels newest-first", async () => {
    const repo = new ConversationRepository(db);
    await repo.insert(conv({ id: "ch-old", kind: "gym_channel", gymId: "gL", title: "Old", lastMessageAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(conv({ id: "ch-new", kind: "gym_channel", gymId: "gL", title: "New", lastMessageAt: "2026-08-05T00:00:00.000Z" }));
    const list = await repo.listChannelsByGym("gL");
    expect(list.map((c) => c.id)).toEqual(["ch-new", "ch-old"]);
  });

  it("updateLastMessage sets at + preview", async () => {
    const repo = new ConversationRepository(db);
    await repo.insert(conv({ id: "c2", kind: "group", gymId: "g1", title: "S" }));
    await repo.updateLastMessage("c2", "2026-08-09T00:00:00.000Z", "hey");
    const c = await repo.findById("c2");
    expect(c?.lastMessagePreview).toBe("hey");
    expect(c?.lastMessageAt).toBe("2026-08-09T00:00:00.000Z");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/conversation.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

Add to `apps/api/src/db/collections.mts` inside `COLLECTIONS`:
```ts
  conversations: "conversations",
  messages: "messages",
  conversationParticipants: "conversationParticipants",
  channelReadStates: "channelReadStates",
  userBlocks: "userBlocks",
  messageReports: "messageReports",
```

```ts
// apps/api/src/repositories/conversation.repository.mts
import type { Db } from "mongodb";
import type { Conversation } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ConversationDoc extends Conversation {
  _id: string;
}

export class ConversationRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ConversationDoc>(COLLECTIONS.conversations);
    await col.createIndex({ pairKey: 1 }, { unique: true, sparse: true });
    await col.createIndex({ kind: 1, gymId: 1 });
    await col.createIndex({ lastMessageAt: -1 });
  }

  public async insert(c: Conversation): Promise<Conversation> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<Conversation | null> {
    return stripId<Conversation>(await this.collection<ConversationDoc>(COLLECTIONS.conversations).findOne({ _id: id }));
  }

  public async findDirectByPairKey(pairKey: string): Promise<Conversation | null> {
    return stripId<Conversation>(await this.collection<ConversationDoc>(COLLECTIONS.conversations).findOne({ pairKey }));
  }

  public async listChannelsByGym(gymId: string): Promise<Conversation[]> {
    const docs = await this.collection<ConversationDoc>(COLLECTIONS.conversations)
      .find({ kind: "gym_channel", gymId }).sort({ lastMessageAt: -1, createdAt: 1 }).toArray();
    return docs.map((d) => stripId<Conversation>(d) as Conversation);
  }

  public async updateLastMessage(id: string, at: string, preview: string): Promise<void> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations)
      .updateOne({ _id: id }, { $set: { lastMessageAt: at, lastMessagePreview: preview } });
  }

  public async update(id: string, patch: Partial<Conversation>): Promise<Conversation | null> {
    const set: Record<string, unknown> = {};
    const unset: Record<string, ""> = {};
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined) unset[k] = ""; else set[k] = v;
    }
    const ops: Record<string, unknown> = {};
    if (Object.keys(set).length > 0) ops["$set"] = set;
    if (Object.keys(unset).length > 0) ops["$unset"] = unset;
    if (Object.keys(ops).length === 0) return this.findById(id);
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).updateOne({ _id: id }, ops);
    return this.findById(id);
  }

  public async delete(id: string): Promise<void> {
    await this.collection<ConversationDoc>(COLLECTIONS.conversations).deleteOne({ _id: id });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/conversation.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/conversation.repository.mts apps/api/src/db/collections.mts apps/api/test/conversation.repository.test.mts
git commit -m "feat(api): ConversationRepository + messaging collections"
```

---

## Task 5: `MessageRepository`

**Files:**
- Create: `apps/api/src/repositories/message.repository.mts`
- Test: `apps/api/test/message.repository.test.mts`

**Interfaces:**
- Consumes `Message`, `COLLECTIONS.messages`.
- Produces `MessageRepository`:
  - `ensureIndexes()` — `{ conversationId: 1, createdAt: -1 }`.
  - `insert(m: Message): Promise<Message>`
  - `findById(id): Promise<Message | null>`
  - `listByConversation(conversationId, before: string | undefined, limit): Promise<Message[]>` — newest-first; when `before` provided, only `createdAt < before`.
  - `latestForConversation(conversationId): Promise<Message | null>`
  - `countAfter(conversationId, afterIso: string | undefined): Promise<number>` — messages with `createdAt > afterIso` (all when `afterIso` undefined); excludes soft-deleted (`deletedAt` unset).
  - `softDelete(id, at: string): Promise<void>` — set `deletedAt`, blank `body` to `""`... but `body` minLength 1 in schema is a READ contract; at rest set `body: ""`. (Read-mapping redacts; storing "" is fine — repo doesn't Value.Parse on write.)
  - `update(id, patch: Partial<Message>): Promise<Message | null>` — no-op empty patch.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/message.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MessageRepository } from "../src/repositories/message.repository.mts";
import type { Message } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_messages");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const msg = (over: Partial<Message>): Message => ({
  id: over.id ?? "m1", conversationId: over.conversationId ?? "c1", authorId: over.authorId ?? "u1",
  body: over.body ?? "B", createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("MessageRepository", () => {
  it("lists newest-first and honors before cursor", async () => {
    const repo = new MessageRepository(db);
    await repo.ensureIndexes();
    await repo.insert(msg({ id: "m1", conversationId: "cX", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(msg({ id: "m2", conversationId: "cX", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(msg({ id: "m3", conversationId: "cX", createdAt: "2026-08-03T00:00:00.000Z" }));
    const all = await repo.listByConversation("cX", undefined, 10);
    expect(all.map((m) => m.id)).toEqual(["m3", "m2", "m1"]);
    const older = await repo.listByConversation("cX", "2026-08-03T00:00:00.000Z", 10);
    expect(older.map((m) => m.id)).toEqual(["m2", "m1"]);
  });

  it("countAfter counts messages strictly newer, excluding deleted", async () => {
    const repo = new MessageRepository(db);
    await repo.insert(msg({ id: "a", conversationId: "cY", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(msg({ id: "b", conversationId: "cY", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(msg({ id: "c", conversationId: "cY", createdAt: "2026-08-03T00:00:00.000Z" }));
    await repo.softDelete("c", "2026-08-04T00:00:00.000Z");
    expect(await repo.countAfter("cY", "2026-08-01T00:00:00.000Z")).toBe(1); // only b (c deleted)
    expect(await repo.countAfter("cY", undefined)).toBe(2); // a + b (c deleted)
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/message.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/message.repository.mts
import type { Db } from "mongodb";
import type { Message } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface MessageDoc extends Message {
  _id: string;
}

export class MessageRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).createIndex({ conversationId: 1, createdAt: -1 });
  }

  public async insert(m: Message): Promise<Message> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).insertOne({ ...m, _id: m.id });
    return m;
  }

  public async findById(id: string): Promise<Message | null> {
    return stripId<Message>(await this.collection<MessageDoc>(COLLECTIONS.messages).findOne({ _id: id }));
  }

  public async listByConversation(conversationId: string, before: string | undefined, limit: number): Promise<Message[]> {
    const filter: Record<string, unknown> = { conversationId };
    if (before !== undefined) filter["createdAt"] = { $lt: before };
    const docs = await this.collection<MessageDoc>(COLLECTIONS.messages)
      .find(filter).sort({ createdAt: -1 }).limit(limit).toArray();
    return docs.map((d) => stripId<Message>(d) as Message);
  }

  public async latestForConversation(conversationId: string): Promise<Message | null> {
    const docs = await this.collection<MessageDoc>(COLLECTIONS.messages)
      .find({ conversationId }).sort({ createdAt: -1 }).limit(1).toArray();
    return docs.length > 0 ? (stripId<Message>(docs[0]) as Message) : null;
  }

  public async countAfter(conversationId: string, afterIso: string | undefined): Promise<number> {
    const filter: Record<string, unknown> = { conversationId, deletedAt: { $exists: false } };
    if (afterIso !== undefined) filter["createdAt"] = { $gt: afterIso };
    return this.collection<MessageDoc>(COLLECTIONS.messages).countDocuments(filter);
  }

  public async softDelete(id: string, at: string): Promise<void> {
    await this.collection<MessageDoc>(COLLECTIONS.messages).updateOne({ _id: id }, { $set: { deletedAt: at, body: "" } });
  }

  public async update(id: string, patch: Partial<Message>): Promise<Message | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<MessageDoc>(COLLECTIONS.messages).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
```

> Note on soft-delete `body: ""`: stored value violates the `Message` schema's `minLength: 1`, but repositories do not `Value.Parse` on read — they `stripId` and return. The facade's read mapping presents deleted messages with `deletedAt` set; the UI renders "message removed". Do not add `Value.Parse` to message reads.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/message.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/message.repository.mts apps/api/test/message.repository.test.mts
git commit -m "feat(api): MessageRepository (newest-first cursor, unread count, soft-delete)"
```

---

## Task 6: `ConversationParticipantRepository`

**Files:**
- Create: `apps/api/src/repositories/conversation-participant.repository.mts`
- Test: `apps/api/test/conversation-participant.repository.test.mts`

**Interfaces:**
- Consumes `ConversationParticipant`, `COLLECTIONS.conversationParticipants`.
- Produces `ConversationParticipantRepository`:
  - `ensureIndexes()` — `{ conversationId: 1, userId: 1 }` (unique), `{ userId: 1 }`.
  - `insertMany(ps: ConversationParticipant[]): Promise<void>` (no-op on empty array).
  - `find(conversationId, userId): Promise<ConversationParticipant | null>`
  - `listByConversation(conversationId): Promise<ConversationParticipant[]>`
  - `listActiveForUser(userId): Promise<ConversationParticipant[]>` — rows where `leftAt` unset.
  - `setLastReadAt(conversationId, userId, at): Promise<void>`
  - `setMuted(conversationId, userId, muted): Promise<void>`
  - `setLeftAt(conversationId, userId, at): Promise<void>`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/conversation-participant.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ConversationParticipantRepository } from "../src/repositories/conversation-participant.repository.mts";
import type { ConversationParticipant } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_participants");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const p = (over: Partial<ConversationParticipant>): ConversationParticipant => ({
  id: over.id ?? "p1", conversationId: over.conversationId ?? "c1", userId: over.userId ?? "u1",
  role: over.role ?? "member", muted: over.muted ?? false, ...over,
});

describe("ConversationParticipantRepository", () => {
  it("lists active-for-user excluding left", async () => {
    const repo = new ConversationParticipantRepository(db);
    await repo.ensureIndexes();
    await repo.insertMany([p({ id: "p1", conversationId: "cA", userId: "uX" }), p({ id: "p2", conversationId: "cB", userId: "uX" })]);
    await repo.setLeftAt("cB", "uX", "2026-08-02T00:00:00.000Z");
    const active = await repo.listActiveForUser("uX");
    expect(active.map((x) => x.conversationId)).toEqual(["cA"]);
  });

  it("setLastReadAt + setMuted persist", async () => {
    const repo = new ConversationParticipantRepository(db);
    await repo.insertMany([p({ id: "p3", conversationId: "cC", userId: "uY" })]);
    await repo.setLastReadAt("cC", "uY", "2026-08-03T00:00:00.000Z");
    await repo.setMuted("cC", "uY", true);
    const row = await repo.find("cC", "uY");
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z");
    expect(row?.muted).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/conversation-participant.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/conversation-participant.repository.mts
import type { Db } from "mongodb";
import type { ConversationParticipant } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ParticipantDoc extends ConversationParticipant {
  _id: string;
}

export class ConversationParticipantRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants);
    await col.createIndex({ conversationId: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
  }

  public async insertMany(ps: ConversationParticipant[]): Promise<void> {
    if (ps.length === 0) return;
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .insertMany(ps.map((p) => ({ ...p, _id: p.id })));
  }

  public async find(conversationId: string, userId: string): Promise<ConversationParticipant | null> {
    return stripId<ConversationParticipant>(
      await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants).findOne({ conversationId, userId }),
    );
  }

  public async listByConversation(conversationId: string): Promise<ConversationParticipant[]> {
    const docs = await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants).find({ conversationId }).toArray();
    return docs.map((d) => stripId<ConversationParticipant>(d) as ConversationParticipant);
  }

  public async listActiveForUser(userId: string): Promise<ConversationParticipant[]> {
    const docs = await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .find({ userId, leftAt: { $exists: false } }).toArray();
    return docs.map((d) => stripId<ConversationParticipant>(d) as ConversationParticipant);
  }

  public async setLastReadAt(conversationId: string, userId: string, at: string): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { lastReadAt: at } });
  }

  public async setMuted(conversationId: string, userId: string, muted: boolean): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { muted } });
  }

  public async setLeftAt(conversationId: string, userId: string, at: string): Promise<void> {
    await this.collection<ParticipantDoc>(COLLECTIONS.conversationParticipants)
      .updateOne({ conversationId, userId }, { $set: { leftAt: at } });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/conversation-participant.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/conversation-participant.repository.mts apps/api/test/conversation-participant.repository.test.mts
git commit -m "feat(api): ConversationParticipantRepository"
```

---

## Task 7: `ChannelReadStateRepository`

**Files:**
- Create: `apps/api/src/repositories/channel-read-state.repository.mts`
- Test: `apps/api/test/channel-read-state.repository.test.mts`

**Interfaces:**
- Consumes `ChannelReadState`, `COLLECTIONS.channelReadStates`.
- Produces `ChannelReadStateRepository`:
  - `ensureIndexes()` — `{ channelId: 1, userId: 1 }` (unique).
  - `find(channelId, userId): Promise<ChannelReadState | null>`
  - `upsertLastReadAt(channelId, userId, at, newId): Promise<void>` — upsert; on insert set `id` = `newId`, `muted` false.
  - `upsertMuted(channelId, userId, muted, newId): Promise<void>` — upsert; on insert set `id` = `newId`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/channel-read-state.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { ChannelReadStateRepository } from "../src/repositories/channel-read-state.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_channel_read");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("ChannelReadStateRepository", () => {
  it("lazily creates then updates read state", async () => {
    const repo = new ChannelReadStateRepository(db);
    await repo.ensureIndexes();
    expect(await repo.find("ch1", "u1")).toBeNull();
    await repo.upsertLastReadAt("ch1", "u1", "2026-08-03T00:00:00.000Z", "s-1");
    let row = await repo.find("ch1", "u1");
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z");
    expect(row?.muted).toBe(false);
    await repo.upsertMuted("ch1", "u1", true, "s-2");
    row = await repo.find("ch1", "u1");
    expect(row?.muted).toBe(true);
    expect(row?.lastReadAt).toBe("2026-08-03T00:00:00.000Z"); // preserved
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/channel-read-state.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/channel-read-state.repository.mts
import type { Db } from "mongodb";
import type { ChannelReadState } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ReadStateDoc extends ChannelReadState {
  _id: string;
}

export class ChannelReadStateRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates)
      .createIndex({ channelId: 1, userId: 1 }, { unique: true });
  }

  public async find(channelId: string, userId: string): Promise<ChannelReadState | null> {
    return stripId<ChannelReadState>(
      await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).findOne({ channelId, userId }),
    );
  }

  public async upsertLastReadAt(channelId: string, userId: string, at: string, newId: string): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).updateOne(
      { channelId, userId },
      { $set: { lastReadAt: at }, $setOnInsert: { _id: newId, id: newId, channelId, userId, muted: false } },
      { upsert: true },
    );
  }

  public async upsertMuted(channelId: string, userId: string, muted: boolean, newId: string): Promise<void> {
    await this.collection<ReadStateDoc>(COLLECTIONS.channelReadStates).updateOne(
      { channelId, userId },
      { $set: { muted }, $setOnInsert: { _id: newId, id: newId, channelId, userId } },
      { upsert: true },
    );
  }
}
```

> Note: never place a field in both `$set` and `$setOnInsert`. `upsertLastReadAt` sets `muted` only on insert; `upsertMuted` sets `lastReadAt` never (preserved across upserts). `_id` and `id` both set on insert (mirrors other repos storing `_id: entity.id`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/channel-read-state.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/channel-read-state.repository.mts apps/api/test/channel-read-state.repository.test.mts
git commit -m "feat(api): ChannelReadStateRepository (lazy per-user channel read/mute)"
```

---

## Task 8: `UserBlockRepository`

**Files:**
- Create: `apps/api/src/repositories/user-block.repository.mts`
- Test: `apps/api/test/user-block.repository.test.mts`

**Interfaces:**
- Consumes `UserBlock`, `COLLECTIONS.userBlocks`.
- Produces `UserBlockRepository`:
  - `ensureIndexes()` — `{ blockerId: 1, blockedId: 1 }` (unique).
  - `insert(b: UserBlock): Promise<UserBlock>`
  - `existsEitherWay(a, b): Promise<boolean>` — true if a↔b block exists in either direction.
  - `listBlockedBy(userId): Promise<string[]>` — the `blockedId`s the user has blocked.
  - `delete(id, blockerId): Promise<void>` — scoped to the blocker (can only remove own blocks).

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/user-block.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { UserBlockRepository } from "../src/repositories/user-block.repository.mts";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_blocks");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

describe("UserBlockRepository", () => {
  it("existsEitherWay detects both directions; listBlockedBy returns targets", async () => {
    const repo = new UserBlockRepository(db);
    await repo.ensureIndexes();
    await repo.insert({ id: "b1", blockerId: "u1", blockedId: "u2" });
    expect(await repo.existsEitherWay("u1", "u2")).toBe(true);
    expect(await repo.existsEitherWay("u2", "u1")).toBe(true);
    expect(await repo.existsEitherWay("u1", "u9")).toBe(false);
    expect(await repo.listBlockedBy("u1")).toEqual(["u2"]);
    await repo.delete("b1", "u1");
    expect(await repo.existsEitherWay("u1", "u2")).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/user-block.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/user-block.repository.mts
import type { Db } from "mongodb";
import type { UserBlock } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface BlockDoc extends UserBlock {
  _id: string;
}

export class UserBlockRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).createIndex({ blockerId: 1, blockedId: 1 }, { unique: true });
  }

  public async insert(b: UserBlock): Promise<UserBlock> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).insertOne({ ...b, _id: b.id });
    return b;
  }

  public async existsEitherWay(a: string, b: string): Promise<boolean> {
    const found = await this.collection<BlockDoc>(COLLECTIONS.userBlocks).findOne({
      $or: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }],
    });
    return found !== null;
  }

  public async listBlockedBy(userId: string): Promise<string[]> {
    const docs = await this.collection<BlockDoc>(COLLECTIONS.userBlocks).find({ blockerId: userId }).toArray();
    return docs.map((d) => d.blockedId);
  }

  public async delete(id: string, blockerId: string): Promise<void> {
    await this.collection<BlockDoc>(COLLECTIONS.userBlocks).deleteOne({ _id: id, blockerId });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/user-block.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/user-block.repository.mts apps/api/test/user-block.repository.test.mts
git commit -m "feat(api): UserBlockRepository (either-way existence)"
```

---

## Task 9: `MessageReportRepository`

**Files:**
- Create: `apps/api/src/repositories/message-report.repository.mts`
- Test: `apps/api/test/message-report.repository.test.mts`

**Interfaces:**
- Consumes `MessageReport`, `COLLECTIONS.messageReports`.
- Produces `MessageReportRepository`:
  - `ensureIndexes()` — `{ gymId: 1, status: 1, createdAt: -1 }`.
  - `insert(r: MessageReport): Promise<MessageReport>`
  - `findById(id): Promise<MessageReport | null>`
  - `listByGym(gymId, status: MessageReportStatus | undefined): Promise<MessageReport[]>` — newest-first; filter by status when provided.
  - `updateStatus(id, status, reviewedAt): Promise<void>`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/message-report.repository.test.mts
import { afterAll, describe, expect, it } from "bun:test";
import { MongoClient } from "mongodb";
import { MessageReportRepository } from "../src/repositories/message-report.repository.mts";
import type { MessageReport } from "@bjj/contract";

const client = new MongoClient(process.env["MONGODB_URI"] ?? "mongodb://localhost:27017", { timeoutMS: 4000 });
const db = client.db("bjj_test_reports");
afterAll(async () => { await db.dropDatabase(); await client.close(); });

const rep = (over: Partial<MessageReport>): MessageReport => ({
  id: over.id ?? "r1", reportedUserId: "u2", reporterId: "u1", gymId: over.gymId ?? "g1",
  reason: "spam", status: over.status ?? "open", createdAt: over.createdAt ?? "2026-08-01T00:00:00.000Z", ...over,
});

describe("MessageReportRepository", () => {
  it("lists by gym + status newest-first, updates status", async () => {
    const repo = new MessageReportRepository(db);
    await repo.ensureIndexes();
    await repo.insert(rep({ id: "r1", gymId: "gL", createdAt: "2026-08-01T00:00:00.000Z" }));
    await repo.insert(rep({ id: "r2", gymId: "gL", createdAt: "2026-08-02T00:00:00.000Z" }));
    await repo.insert(rep({ id: "r3", gymId: "gOther" }));
    const open = await repo.listByGym("gL", "open");
    expect(open.map((r) => r.id)).toEqual(["r2", "r1"]);
    await repo.updateStatus("r1", "reviewed", "2026-08-03T00:00:00.000Z");
    expect((await repo.findById("r1"))?.status).toBe("reviewed");
    expect((await repo.listByGym("gL", "open")).map((r) => r.id)).toEqual(["r2"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/message-report.repository.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/repositories/message-report.repository.mts
import type { Db } from "mongodb";
import type { MessageReport, MessageReportStatus } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ReportDoc extends MessageReport {
  _id: string;
}

export class MessageReportRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).createIndex({ gymId: 1, status: 1, createdAt: -1 });
  }

  public async insert(r: MessageReport): Promise<MessageReport> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).insertOne({ ...r, _id: r.id });
    return r;
  }

  public async findById(id: string): Promise<MessageReport | null> {
    return stripId<MessageReport>(await this.collection<ReportDoc>(COLLECTIONS.messageReports).findOne({ _id: id }));
  }

  public async listByGym(gymId: string, status: MessageReportStatus | undefined): Promise<MessageReport[]> {
    const filter: Record<string, unknown> = { gymId };
    if (status !== undefined) filter["status"] = status;
    const docs = await this.collection<ReportDoc>(COLLECTIONS.messageReports).find(filter).sort({ createdAt: -1 }).toArray();
    return docs.map((d) => stripId<MessageReport>(d) as MessageReport);
  }

  public async updateStatus(id: string, status: MessageReportStatus, reviewedAt: string): Promise<void> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).updateOne({ _id: id }, { $set: { status, reviewedAt } });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/message-report.repository.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/repositories/message-report.repository.mts apps/api/test/message-report.repository.test.mts
git commit -m "feat(api): MessageReportRepository"
```

---

## Task 10: `MessagingFacade` — construction, `sharesActiveGym`, conversation creation

**Files:**
- Create: `apps/api/src/facades/messaging.facade.mts`
- Test: `apps/api/test/messaging.facade.test.mts` (shared harness; grows across Tasks 10–13)

**Interfaces:**
- Consumes (via `Pick`): `ConversationRepository` (`insert|findById|findDirectByPairKey|listChannelsByGym|updateLastMessage|update|delete`), `MessageRepository` (`insert|findById|listByConversation|latestForConversation|countAfter|softDelete|update`), `ConversationParticipantRepository` (`insertMany|find|listByConversation|listActiveForUser|setLastReadAt|setMuted|setLeftAt`), `ChannelReadStateRepository` (`find|upsertLastReadAt|upsertMuted`), `UserBlockRepository` (`insert|existsEitherWay|listBlockedBy|delete`), `MessageReportRepository` (`insert|findById|listByGym|updateStatus`), `MembershipRepository` (`find|listByUser`), `GymRepository` (`findById`), `assertActiveMember`, `assertCanManageGym`, `IdFactory`.
- Produces `MessagingFacade` with constructor `(conversations, messages, participants, channelReads, blocks, reports, memberships, gyms, newId)`.
- This task implements: private `authzDeps()`, `sharesActiveGym(a,b)`, `pairKeyOf(a,b)`, and public `startDirect`, `createGroup`, `createChannel`, `listChannels`.

**Method contracts (produced here, consumed by later tasks + routes):**
- `startDirect(userId, recipientId, role): Promise<Conversation>`
- `createGroup(userId, gymId, req: CreateGroupRequest, role): Promise<Conversation>`
- `createChannel(userId, gymId, req: CreateChannelRequest, role): Promise<Conversation>`
- `listChannels(userId, gymId, role): Promise<Conversation[]>`

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/messaging.facade.test.mts
import { describe, expect, it } from "bun:test";
import { MessagingFacade } from "../src/facades/messaging.facade.mts";
import type { Conversation, ConversationParticipant, Gym, GymMembership, Message, UserBlock, MessageReport, ChannelReadState } from "@bjj/contract";

interface Seed {
  gymOwnerId?: string;
  memberships?: GymMembership[];
  conversations?: Conversation[];
  participants?: ConversationParticipant[];
  messages?: Message[];
  blocks?: UserBlock[];
}

export function facade(seed?: Seed) {
  const conversations = new Map<string, Conversation>();
  (seed?.conversations ?? []).forEach((c) => conversations.set(c.id, c));
  const participants = new Map<string, ConversationParticipant>();
  (seed?.participants ?? []).forEach((p) => participants.set(`${p.conversationId}:${p.userId}`, p));
  const messages = new Map<string, Message>();
  (seed?.messages ?? []).forEach((m) => messages.set(m.id, m));
  const blocks = new Map<string, UserBlock>();
  (seed?.blocks ?? []).forEach((b) => blocks.set(b.id, b));
  const channelReads = new Map<string, ChannelReadState>();
  const reports: MessageReport[] = [];
  const memberList: GymMembership[] = seed?.memberships ?? [];
  const gyms = new Map<string, Gym>([
    ["g1", { id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }],
    ["g2", { id: "g2", name: "B", address: "y", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }],
  ]);

  const convRepo = {
    insert: async (c: Conversation) => { conversations.set(c.id, c); return c; },
    findById: async (id: string) => conversations.get(id) ?? null,
    findDirectByPairKey: async (pk: string) => [...conversations.values()].find((c) => c.pairKey === pk) ?? null,
    listChannelsByGym: async (g: string) => [...conversations.values()].filter((c) => c.kind === "gym_channel" && c.gymId === g),
    updateLastMessage: async (id: string, at: string, preview: string) => { const c = conversations.get(id); if (c) { c.lastMessageAt = at; c.lastMessagePreview = preview; } },
    update: async (id: string, patch: Partial<Conversation>) => { const c = conversations.get(id); if (!c) return null; const n = { ...c, ...patch }; Object.keys(patch).forEach((k) => { if ((patch as Record<string, unknown>)[k] === undefined) delete (n as Record<string, unknown>)[k]; }); conversations.set(id, n); return n; },
    delete: async (id: string) => { conversations.delete(id); },
  };
  const msgRepo = {
    insert: async (m: Message) => { messages.set(m.id, m); return m; },
    findById: async (id: string) => messages.get(id) ?? null,
    listByConversation: async (cid: string, before: string | undefined, limit: number) => [...messages.values()].filter((m) => m.conversationId === cid && (before === undefined || (m.createdAt ?? "") < before)).sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? "")).slice(0, limit),
    latestForConversation: async (cid: string) => [...messages.values()].filter((m) => m.conversationId === cid).sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""))[0] ?? null,
    countAfter: async (cid: string, after: string | undefined) => [...messages.values()].filter((m) => m.conversationId === cid && !m.deletedAt && (after === undefined || (m.createdAt ?? "") > after)).length,
    softDelete: async (id: string, at: string) => { const m = messages.get(id); if (m) { m.deletedAt = at; m.body = ""; } },
    update: async (id: string, patch: Partial<Message>) => { const m = messages.get(id); if (!m) return null; const n = { ...m, ...patch }; messages.set(id, n); return n; },
  };
  const partRepo = {
    insertMany: async (ps: ConversationParticipant[]) => { ps.forEach((p) => participants.set(`${p.conversationId}:${p.userId}`, p)); },
    find: async (cid: string, uid: string) => participants.get(`${cid}:${uid}`) ?? null,
    listByConversation: async (cid: string) => [...participants.values()].filter((p) => p.conversationId === cid),
    listActiveForUser: async (uid: string) => [...participants.values()].filter((p) => p.userId === uid && !p.leftAt),
    setLastReadAt: async (cid: string, uid: string, at: string) => { const p = participants.get(`${cid}:${uid}`); if (p) p.lastReadAt = at; },
    setMuted: async (cid: string, uid: string, m: boolean) => { const p = participants.get(`${cid}:${uid}`); if (p) p.muted = m; },
    setLeftAt: async (cid: string, uid: string, at: string) => { const p = participants.get(`${cid}:${uid}`); if (p) p.leftAt = at; },
  };
  const readRepo = {
    find: async (chId: string, uid: string) => channelReads.get(`${chId}:${uid}`) ?? null,
    upsertLastReadAt: async (chId: string, uid: string, at: string, id: string) => { const k = `${chId}:${uid}`; const cur = channelReads.get(k); channelReads.set(k, { id: cur?.id ?? id, channelId: chId, userId: uid, lastReadAt: at, muted: cur?.muted ?? false }); },
    upsertMuted: async (chId: string, uid: string, m: boolean, id: string) => { const k = `${chId}:${uid}`; const cur = channelReads.get(k); channelReads.set(k, { id: cur?.id ?? id, channelId: chId, userId: uid, lastReadAt: cur?.lastReadAt, muted: m }); },
  };
  const blockRepo = {
    insert: async (b: UserBlock) => { blocks.set(b.id, b); return b; },
    existsEitherWay: async (a: string, b: string) => [...blocks.values()].some((x) => (x.blockerId === a && x.blockedId === b) || (x.blockerId === b && x.blockedId === a)),
    listBlockedBy: async (uid: string) => [...blocks.values()].filter((x) => x.blockerId === uid).map((x) => x.blockedId),
    delete: async (id: string, blockerId: string) => { const b = blocks.get(id); if (b && b.blockerId === blockerId) blocks.delete(id); },
  };
  const reportRepo = {
    insert: async (r: MessageReport) => { reports.push(r); return r; },
    findById: async (id: string) => reports.find((r) => r.id === id) ?? null,
    listByGym: async (g: string, s: string | undefined) => reports.filter((r) => r.gymId === g && (s === undefined || r.status === s)),
    updateStatus: async (id: string, status: string, at: string) => { const r = reports.find((x) => x.id === id); if (r) { r.status = status as MessageReport["status"]; r.reviewedAt = at; } },
  };
  const memberRepo = {
    find: async (g: string, u: string) => memberList.find((m) => m.gymId === g && m.userId === u) ?? null,
    listByUser: async (u: string) => memberList.filter((m) => m.userId === u),
  };
  const gymRepo = { findById: async (id: string) => gyms.get(id) ?? null };
  let n = 0;

  return {
    f: new MessagingFacade(convRepo, msgRepo, partRepo, readRepo, blockRepo, reportRepo, memberRepo, gymRepo, () => `id-${n++}`),
    conversations, participants, messages, blocks, channelReads, reports,
  };
}

export const member = (userId: string, gymId = "g1", over: Partial<GymMembership> = {}): GymMembership => ({
  id: `m-${userId}-${gymId}`, gymId, userId, status: "active", verifiedMember: true, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t", ...over,
});

describe("MessagingFacade — creation + gating", () => {
  it("startDirect requires a shared active gym", async () => {
    const { f } = facade({ memberships: [member("u1", "g1"), member("u2", "g2")] });
    await expect(f.startDirect("u1", "u2", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("startDirect find-or-creates one direct conversation by pairKey", async () => {
    const { f, conversations } = facade({ memberships: [member("u1"), member("u2")] });
    const a = await f.startDirect("u1", "u2", "practitioner");
    const b = await f.startDirect("u2", "u1", "practitioner");
    expect(a.id).toBe(b.id);
    expect([...conversations.values()].filter((c) => c.kind === "direct").length).toBe(1);
    expect(a.pairKey).toBe("u1|u2");
  });

  it("startDirect refuses self and blocked users", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2")], blocks: [{ id: "b1", blockerId: "u2", blockedId: "u1" }] });
    await expect(f.startDirect("u1", "u1", "practitioner")).rejects.toMatchObject({ code: "bad_request" });
    await expect(f.startDirect("u1", "u2", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("createGroup rejects a participant who is not a member of the gym", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2")] });
    await expect(f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2", "u3"] }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("createGroup includes creator as admin + members", async () => {
    const { f, participants } = facade({ memberships: [member("u1"), member("u2")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2"] }, "practitioner");
    expect(g.kind).toBe("group");
    expect(participants.get(`${g.id}:u1`)?.role).toBe("admin");
    expect(participants.get(`${g.id}:u2`)?.role).toBe("member");
  });

  it("createChannel requires a manager; listChannels seeds a default General", async () => {
    const nonMgr = facade({ memberships: [member("u1")] });
    await expect(nonMgr.f.createChannel("u1", "g1", { title: "Announcements" }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" })] });
    const channels = await owner.f.listChannels("u1", "g1", "practitioner");
    expect(channels.some((c) => c.title === "General")).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: FAIL — `MessagingFacade` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// apps/api/src/facades/messaging.facade.mts
import type {
  Conversation, ConversationParticipant, CreateChannelRequest, CreateGroupRequest, Gym, GymMembership, UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import { assertActiveMember, assertCanManageGym } from "./gym-authz.mts";
import type { ConversationRepository } from "../repositories/conversation.repository.mts";
import type { MessageRepository } from "../repositories/message.repository.mts";
import type { ConversationParticipantRepository } from "../repositories/conversation-participant.repository.mts";
import type { ChannelReadStateRepository } from "../repositories/channel-read-state.repository.mts";
import type { UserBlockRepository } from "../repositories/user-block.repository.mts";
import type { MessageReportRepository } from "../repositories/message-report.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";

type IdFactory = () => string;
type ConvRepo = Pick<ConversationRepository, "insert" | "findById" | "findDirectByPairKey" | "listChannelsByGym" | "updateLastMessage" | "update" | "delete">;
type MsgRepo = Pick<MessageRepository, "insert" | "findById" | "listByConversation" | "latestForConversation" | "countAfter" | "softDelete" | "update">;
type PartRepo = Pick<ConversationParticipantRepository, "insertMany" | "find" | "listByConversation" | "listActiveForUser" | "setLastReadAt" | "setMuted" | "setLeftAt">;
type ReadRepo = Pick<ChannelReadStateRepository, "find" | "upsertLastReadAt" | "upsertMuted">;
type BlockRepo = Pick<UserBlockRepository, "insert" | "existsEitherWay" | "listBlockedBy" | "delete">;
type ReportRepo = Pick<MessageReportRepository, "insert" | "findById" | "listByGym" | "updateStatus">;
type MemberRepo = Pick<MembershipRepository, "find" | "listByUser">;
type GymRepo = Pick<GymRepository, "findById">;

export class MessagingFacade {

  public constructor(
    private readonly conversations: ConvRepo,
    private readonly messages: MsgRepo,
    private readonly participants: PartRepo,
    private readonly channelReads: ReadRepo,
    private readonly blocks: BlockRepo,
    private readonly reports: ReportRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly newId: IdFactory,
  ) {}

  private authzDeps(): { gyms: GymRepo; memberships: MemberRepo } {
    return { gyms: this.gyms, memberships: this.memberships };
  }

  private pairKeyOf(a: string, b: string): string {
    return [a, b].sort().join("|");
  }

  private async sharesActiveGym(a: string, b: string): Promise<boolean> {
    const [am, bm] = await Promise.all([this.memberships.listByUser(a), this.memberships.listByUser(b)]);
    const bActive: Set<string> = new Set(bm.filter((m: GymMembership) => m.status === "active").map((m) => m.gymId));
    return am.some((m: GymMembership) => m.status === "active" && bActive.has(m.gymId));
  }

  public async startDirect(userId: string, recipientId: string, _role: UserRole): Promise<Conversation> {
    if (userId === recipientId) throw new AppError("bad_request", "Cannot message yourself");
    if (await this.blocks.existsEitherWay(userId, recipientId)) throw new AppError("forbidden", "Messaging is blocked");
    if (!(await this.sharesActiveGym(userId, recipientId))) throw new AppError("forbidden", "You do not share a gym");
    const pairKey: string = this.pairKeyOf(userId, recipientId);
    const existing: Conversation | null = await this.conversations.findDirectByPairKey(pairKey);
    if (existing) return existing;
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "direct", pairKey, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    const rows: ConversationParticipant[] = [userId, recipientId].map((uid) => ({
      id: this.newId(), conversationId: conv.id, userId: uid, role: "member", muted: false,
    }));
    await this.participants.insertMany(rows);
    return conv;
  }

  public async createGroup(userId: string, gymId: string, req: CreateGroupRequest, role: UserRole): Promise<Conversation> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    const others: string[] = [...new Set(req.participantIds)].filter((id) => id !== userId);
    for (const pid of others) {
      const m: GymMembership | null = await this.memberships.find(gymId, pid);
      if (!m || m.status !== "active") throw new AppError("forbidden", `User ${pid} is not a member of this gym`);
    }
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "group", gymId, title: req.title, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    const rows: ConversationParticipant[] = [
      { id: this.newId(), conversationId: conv.id, userId, role: "admin", muted: false },
      ...others.map((uid) => ({ id: this.newId(), conversationId: conv.id, userId: uid, role: "member" as const, muted: false })),
    ];
    await this.participants.insertMany(rows);
    return conv;
  }

  public async createChannel(userId: string, gymId: string, req: CreateChannelRequest, role: UserRole): Promise<Conversation> {
    await assertCanManageGym(this.authzDeps(), userId, gymId, role);
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "gym_channel", gymId, title: req.title, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    return conv;
  }

  public async listChannels(userId: string, gymId: string, role: UserRole): Promise<Conversation[]> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    let channels: Conversation[] = await this.conversations.listChannelsByGym(gymId);
    if (channels.length === 0) {
      const gym: Gym | null = await this.gyms.findById(gymId);
      const now: string = new Date().toISOString();
      const general: Conversation = { id: this.newId(), kind: "gym_channel", gymId, title: "General", createdBy: gym?.ownerId ?? userId, createdAt: now };
      await this.conversations.insert(general);
      channels = [general];
    }
    return channels;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: PASS (creation + gating cases).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/messaging.facade.mts apps/api/test/messaging.facade.test.mts
git commit -m "feat(api): MessagingFacade — creation, shared-gym gating, default channel"
```

---

## Task 11: `MessagingFacade` — list conversations, read messages, send

**Files:**
- Modify: `apps/api/src/facades/messaging.facade.mts`
- Modify: `apps/api/test/messaging.facade.test.mts` (add a describe block)

**Interfaces (produced, consumed by routes):**
- `listConversations(userId, role, page, limit): Promise<{ items: ConversationSummary[]; total: number }>`
- `getMessages(userId, conversationId, req: MessageListQuery, role): Promise<Message[]>` — marks read; hides blocked authors' messages in group/channel; asserts access.
- `sendMessage(userId, conversationId, req: SendMessageRequest, role): Promise<Message>` — asserts access + can-post; updates lastMessage.
- Private helpers: `assertAccess(userId, conv, role)`, `unreadFor(userId, conv)`, `otherParticipantIds(userId, conv)`.

Access rules:
- `direct`/`group`: caller must be a participant with `leftAt` unset (`participants.find`); else `forbidden`. For `direct`, also block if `existsEitherWay`.
- `gym_channel`: `assertActiveMember(conv.gymId)`.

- [ ] **Step 1: Write the failing test** (append)

```ts
// append to apps/api/test/messaging.facade.test.mts
import { MessageListQuery } from "@bjj/contract";

describe("MessagingFacade — read + send", () => {
  it("send + list: unread counts, last message, access", async () => {
    const { f, conversations, participants } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await f.sendMessage("u1", conv.id, { body: "hey" }, "practitioner");
    await f.sendMessage("u1", conv.id, { body: "you there?" }, "practitioner");
    // u2 has never read -> unread 2
    const u2list = await f.listConversations("u2", "practitioner", 1, 20);
    const summary = u2list.items.find((s) => s.conversation.id === conv.id);
    expect(summary?.unreadCount).toBe(2);
    expect(summary?.lastMessage?.body).toBe("you there?");
    expect(summary?.otherParticipantIds).toEqual(["u1"]);
    // u2 reads -> unread 0
    await f.getMessages("u2", conv.id, { }, "practitioner");
    const after = await f.listConversations("u2", "practitioner", 1, 20);
    expect(after.items.find((s) => s.conversation.id === conv.id)?.unreadCount).toBe(0);
    expect(conversations.get(conv.id)?.lastMessagePreview).toBe("you there?");
    expect(participants.get(`${conv.id}:u2`)?.lastReadAt).toBeDefined();
  });

  it("non-participant cannot read a direct conversation", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await expect(f.getMessages("u3", conv.id, {}, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("channel: any active member reads + posts; unread via channel read-state", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [channel] = await owner.f.listChannels("u1", "g1", "practitioner");
    await owner.f.sendMessage("u1", channel.id, { body: "welcome" }, "practitioner");
    // u2 is a plain member -> can read + post
    const msgs = await owner.f.getMessages("u2", channel.id, {}, "practitioner");
    expect(msgs.length).toBe(1);
    await owner.f.sendMessage("u2", channel.id, { body: "thanks coach" }, "practitioner");
    expect((await owner.f.getMessages("u2", channel.id, {}, "practitioner")).length).toBe(2);
  });

  it("blocked author's messages are hidden from the blocker in a group", async () => {
    const { f, blocks } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2", "u3"] }, "practitioner");
    await f.sendMessage("u2", g.id, { body: "from u2" }, "practitioner");
    await f.sendMessage("u3", g.id, { body: "from u3" }, "practitioner");
    blocks.set("b1", { id: "b1", blockerId: "u1", blockedId: "u2" });
    const seen = await f.getMessages("u1", g.id, {}, "practitioner");
    expect(seen.map((m) => m.body)).toEqual(["from u3"]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: FAIL — `listConversations`/`getMessages`/`sendMessage` not defined.

- [ ] **Step 3: Write minimal implementation** (add to the class; add imports `ConversationSummary`, `Message`, `MessageListQuery`, `SendMessageRequest`)

```ts
  private async assertAccess(userId: string, conv: Conversation, role: UserRole): Promise<void> {
    if (conv.kind === "gym_channel") {
      await assertActiveMember(this.authzDeps(), userId, conv.gymId as string, role);
      return;
    }
    const p = await this.participants.find(conv.id, userId);
    if (!p || p.leftAt) throw new AppError("forbidden", "You are not a participant");
  }

  private async unreadFor(userId: string, conv: Conversation): Promise<number> {
    if (conv.kind === "gym_channel") {
      const state = await this.channelReads.find(conv.id, userId);
      return this.messages.countAfter(conv.id, state?.lastReadAt);
    }
    const p = await this.participants.find(conv.id, userId);
    return this.messages.countAfter(conv.id, p?.lastReadAt);
  }

  public async listConversations(
    userId: string, role: UserRole, page: number, limit: number,
  ): Promise<{ items: import("@bjj/contract").ConversationSummary[]; total: number }> {
    const partRows = await this.participants.listActiveForUser(userId);
    const direct: Conversation[] = [];
    for (const row of partRows) {
      const c = await this.conversations.findById(row.conversationId);
      if (c) direct.push(c);
    }
    // gym channels for gyms where the user is an active member
    const memberships = await this.memberships.listByUser(userId);
    const activeGymIds = memberships.filter((m) => m.status === "active").map((m) => m.gymId);
    const channels: Conversation[] = [];
    for (const gymId of activeGymIds) {
      const list = await this.conversations.listChannelsByGym(gymId);
      channels.push(...list);
    }
    const all = [...direct, ...channels];
    const summaries = await Promise.all(all.map(async (conv) => {
      const [unreadCount, lastMessage] = await Promise.all([this.unreadFor(userId, conv), this.messages.latestForConversation(conv.id)]);
      let muted = false;
      if (conv.kind === "gym_channel") muted = (await this.channelReads.find(conv.id, userId))?.muted ?? false;
      else muted = (await this.participants.find(conv.id, userId))?.muted ?? false;
      const others = await this.otherParticipantIds(userId, conv);
      return { conversation: conv, unreadCount, muted, lastMessage: lastMessage ?? undefined, otherParticipantIds: others };
    }));
    summaries.sort((a, b) => (b.conversation.lastMessageAt ?? "").localeCompare(a.conversation.lastMessageAt ?? ""));
    const total = summaries.length;
    const startIdx = (page - 1) * limit;
    return { items: summaries.slice(startIdx, startIdx + limit), total };
  }

  private async otherParticipantIds(userId: string, conv: Conversation): Promise<string[]> {
    if (conv.kind === "gym_channel") return [];
    const rows = await this.participants.listByConversation(conv.id);
    return rows.filter((p) => p.userId !== userId).map((p) => p.userId);
  }

  public async getMessages(userId: string, conversationId: string, req: MessageListQuery, role: UserRole): Promise<Message[]> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    const limit: number = req.limit ?? 30;
    const list = await this.messages.listByConversation(conversationId, req.before, limit);
    const blocked = new Set(await this.blocks.listBlockedBy(userId));
    const visible = list.filter((m) => !blocked.has(m.authorId));
    // mark read
    const now: string = new Date().toISOString();
    if (conv.kind === "gym_channel") await this.channelReads.upsertLastReadAt(conversationId, userId, now, this.newId());
    else await this.participants.setLastReadAt(conversationId, userId, now);
    return visible;
  }

  public async sendMessage(userId: string, conversationId: string, req: SendMessageRequest, role: UserRole): Promise<Message> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    if (conv.kind === "direct") {
      const other = (await this.participants.listByConversation(conversationId)).map((p) => p.userId).find((u) => u !== userId);
      if (other && await this.blocks.existsEitherWay(userId, other)) throw new AppError("forbidden", "Messaging is blocked");
    }
    const now: string = new Date().toISOString();
    const message: Message = { id: this.newId(), conversationId, authorId: userId, body: req.body, createdAt: now };
    await this.messages.insert(message);
    await this.conversations.updateLastMessage(conversationId, now, req.body.slice(0, 140));
    return message;
  }
```

> Import additions at the top of the file: add `ConversationSummary, Message, MessageListQuery, SendMessageRequest` to the `@bjj/contract` type import. (`ConversationSummary` is referenced via `import("@bjj/contract")` inline above to keep the return type explicit; you may instead add it to the top import and use the bare name.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/messaging.facade.mts apps/api/test/messaging.facade.test.mts
git commit -m "feat(api): MessagingFacade — list conversations, read (with block-hide), send"
```

---

## Task 12: `MessagingFacade` — edit/delete, participants, leave, mute, mark-read

**Files:**
- Modify: `apps/api/src/facades/messaging.facade.mts`
- Modify: `apps/api/test/messaging.facade.test.mts`

**Interfaces (produced):**
- `editMessage(userId, messageId, req: EditMessageRequest, role): Promise<Message>` — author only.
- `deleteMessage(userId, messageId, role): Promise<void>` — author, or manager for group/channel.
- `addParticipants(userId, conversationId, req: AddParticipantsRequest, role): Promise<void>` — group; caller is an admin participant; new users must be active gym members.
- `leaveConversation(userId, conversationId, role): Promise<void>` — group → `setLeftAt`; channel → `upsertMuted(true)` (leave = mute/hide for implicit channels).
- `setMuted(userId, conversationId, muted, role): Promise<void>`
- `markRead(userId, conversationId, role): Promise<void>`

- [ ] **Step 1: Write the failing test** (append)

```ts
describe("MessagingFacade — edit/delete/participants/leave/mute", () => {
  it("author edits; non-author cannot", async () => {
    const { f, messages } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    const m = await f.sendMessage("u1", conv.id, { body: "orig" }, "practitioner");
    await f.editMessage("u1", m.id, { body: "edited" }, "practitioner");
    expect(messages.get(m.id)?.body).toBe("edited");
    await expect(f.editMessage("u2", m.id, { body: "hax" }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("manager deletes any message in a channel; plain member cannot delete others'", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [ch] = await owner.f.listChannels("u1", "g1", "practitioner");
    const m = await owner.f.sendMessage("u2", ch.id, { body: "member msg" }, "practitioner");
    await expect(owner.f.deleteMessage("u2b", m.id, "practitioner")).rejects.toBeDefined();
    await owner.f.deleteMessage("u1", m.id, "practitioner"); // owner (manager)
    expect(owner.messages.get(m.id)?.deletedAt).toBeDefined();
  });

  it("addParticipants requires an admin caller + member targets", async () => {
    const { f, participants } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "S", participantIds: ["u2"] }, "practitioner");
    await expect(f.addParticipants("u2", g.id, { userIds: ["u3"] }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
    await f.addParticipants("u1", g.id, { userIds: ["u3"] }, "practitioner");
    expect(participants.get(`${g.id}:u3`)?.role).toBe("member");
  });

  it("leave: group sets leftAt (drops from list); channel mutes", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const g = await owner.f.createGroup("u2", "g1", { gymId: "g1", title: "S", participantIds: ["u1"] }, "practitioner");
    await owner.f.leaveConversation("u1", g.id, "practitioner");
    const list = await owner.f.listConversations("u1", "practitioner", 1, 20);
    expect(list.items.some((s) => s.conversation.id === g.id)).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation** (add to the class; add `AddParticipantsRequest`, `EditMessageRequest` to imports)

```ts
  public async editMessage(userId: string, messageId: string, req: EditMessageRequest, _role: UserRole): Promise<Message> {
    const m = await this.messages.findById(messageId);
    if (!m) throw new AppError("not_found", `Message ${messageId} not found`);
    if (m.authorId !== userId) throw new AppError("forbidden", "Only the author can edit");
    return (await this.messages.update(messageId, { body: req.body, editedAt: new Date().toISOString() })) as Message;
  }

  public async deleteMessage(userId: string, messageId: string, role: UserRole): Promise<void> {
    const m = await this.messages.findById(messageId);
    if (!m) throw new AppError("not_found", `Message ${messageId} not found`);
    if (m.authorId !== userId) {
      const conv = await this.conversations.findById(m.conversationId);
      if (!conv || conv.kind === "direct" || !conv.gymId) throw new AppError("forbidden", "Cannot delete this message");
      await assertCanManageGym(this.authzDeps(), userId, conv.gymId, role);
    }
    await this.messages.softDelete(messageId, new Date().toISOString());
  }

  public async addParticipants(userId: string, conversationId: string, req: AddParticipantsRequest, _role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind !== "group") throw new AppError("bad_request", "Only group conversations take participants");
    const caller = await this.participants.find(conversationId, userId);
    if (!caller || caller.role !== "admin" || caller.leftAt) throw new AppError("forbidden", "Only a group admin can add members");
    const rows: ConversationParticipant[] = [];
    for (const uid of [...new Set(req.userIds)]) {
      if (await this.participants.find(conversationId, uid)) continue;
      const mem = await this.memberships.find(conv.gymId as string, uid);
      if (!mem || mem.status !== "active") throw new AppError("forbidden", `User ${uid} is not a member of this gym`);
      rows.push({ id: this.newId(), conversationId, userId: uid, role: "member", muted: false });
    }
    await this.participants.insertMany(rows);
  }

  public async leaveConversation(userId: string, conversationId: string, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind === "gym_channel") {
      await this.channelReads.upsertMuted(conversationId, userId, true, this.newId());
      return;
    }
    await this.assertAccess(userId, conv, role);
    await this.participants.setLeftAt(conversationId, userId, new Date().toISOString());
  }

  public async setMuted(userId: string, conversationId: string, muted: boolean, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind === "gym_channel") { await this.channelReads.upsertMuted(conversationId, userId, muted, this.newId()); return; }
    await this.assertAccess(userId, conv, role);
    await this.participants.setMuted(conversationId, userId, muted);
  }

  public async markRead(userId: string, conversationId: string, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    const now: string = new Date().toISOString();
    if (conv.kind === "gym_channel") await this.channelReads.upsertLastReadAt(conversationId, userId, now, this.newId());
    else await this.participants.setLastReadAt(conversationId, userId, now);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/messaging.facade.mts apps/api/test/messaging.facade.test.mts
git commit -m "feat(api): MessagingFacade — edit/delete, participants, leave, mute, mark-read"
```

---

## Task 13: `MessagingFacade` — blocks + reports

**Files:**
- Modify: `apps/api/src/facades/messaging.facade.mts`
- Modify: `apps/api/test/messaging.facade.test.mts`

**Interfaces (produced):**
- `blockUser(userId, targetId): Promise<void>` — insert (idempotent: ignore if already exists either way).
- `unblockUser(userId, blockId): Promise<void>`
- `listBlocks(userId): Promise<string[]>`
- `reportMessage(userId, req: ReportMessageRequest): Promise<MessageReport>` — resolve `gymId`: if `messageId` given, from that message's conversation `gymId` (or a shared gym for direct); else the first shared active gym with `reportedUserId`; if none → `bad_request`.
- `listReports(userId, gymId, status, role): Promise<MessageReport[]>` — `assertCanManageGym`.
- `resolveReport(userId, reportId, req: ResolveReportRequest, role): Promise<void>` — find (404) → `assertCanManageGym(report.gymId)` → update status.

- [ ] **Step 1: Write the failing test** (append)

```ts
describe("MessagingFacade — blocks + reports", () => {
  it("block is idempotent + listable; report to a shared gym is manager-reviewable", async () => {
    const { f, reports } = facade({ gymOwnerId: "owner", memberships: [member("owner", "g1", { gymRole: "owner" }), member("u1"), member("u2")] });
    await f.blockUser("u1", "u2");
    await f.blockUser("u1", "u2"); // idempotent
    expect(await f.listBlocks("u1")).toEqual(["u2"]);
    const r = await f.reportMessage("u1", { reportedUserId: "u2", reason: "harassment" });
    expect(r.gymId).toBe("g1");
    // manager can list + resolve
    const open = await f.listReports("owner", "g1", "open", "practitioner");
    expect(open.map((x) => x.id)).toContain(r.id);
    await f.resolveReport("owner", r.id, { status: "reviewed" }, "practitioner");
    expect(reports.find((x) => x.id === r.id)?.status).toBe("reviewed");
    // non-manager cannot list
    await expect(f.listReports("u1", "g1", undefined, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("report with no shared gym is bad_request", async () => {
    const { f } = facade({ memberships: [member("u1", "g1"), member("u2", "g2")] });
    await expect(f.reportMessage("u1", { reportedUserId: "u2", reason: "spam" })).rejects.toMatchObject({ code: "bad_request" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation** (add to the class; add `MessageReport`, `ReportMessageRequest`, `ResolveReportRequest`, `MessageReportStatus` to imports)

```ts
  public async blockUser(userId: string, targetId: string): Promise<void> {
    if (userId === targetId) throw new AppError("bad_request", "Cannot block yourself");
    if (await this.blocks.existsEitherWay(userId, targetId)) return;
    await this.blocks.insert({ id: this.newId(), blockerId: userId, blockedId: targetId, createdAt: new Date().toISOString() });
  }

  public async unblockUser(userId: string, blockId: string): Promise<void> {
    await this.blocks.delete(blockId, userId);
  }

  public async listBlocks(userId: string): Promise<string[]> {
    return this.blocks.listBlockedBy(userId);
  }

  private async firstSharedActiveGym(a: string, b: string): Promise<string | null> {
    const [am, bm] = await Promise.all([this.memberships.listByUser(a), this.memberships.listByUser(b)]);
    const bActive = new Set(bm.filter((m) => m.status === "active").map((m) => m.gymId));
    const hit = am.find((m) => m.status === "active" && bActive.has(m.gymId));
    return hit?.gymId ?? null;
  }

  public async reportMessage(userId: string, req: ReportMessageRequest): Promise<MessageReport> {
    let gymId: string | null = null;
    if (req.messageId) {
      const m = await this.messages.findById(req.messageId);
      const conv = m ? await this.conversations.findById(m.conversationId) : null;
      gymId = conv?.gymId ?? (await this.firstSharedActiveGym(userId, req.reportedUserId));
    } else {
      gymId = await this.firstSharedActiveGym(userId, req.reportedUserId);
    }
    if (!gymId) throw new AppError("bad_request", "No shared gym to route this report");
    const report: MessageReport = {
      id: this.newId(), messageId: req.messageId, reportedUserId: req.reportedUserId, reporterId: userId,
      gymId, reason: req.reason, note: req.note, status: "open", createdAt: new Date().toISOString(),
    };
    await this.reports.insert(report);
    return report;
  }

  public async listReports(userId: string, gymId: string, status: MessageReportStatus | undefined, role: UserRole): Promise<MessageReport[]> {
    await assertCanManageGym(this.authzDeps(), userId, gymId, role);
    return this.reports.listByGym(gymId, status);
  }

  public async resolveReport(userId: string, reportId: string, req: ResolveReportRequest, role: UserRole): Promise<void> {
    const report = await this.reports.findById(reportId);
    if (!report) throw new AppError("not_found", `Report ${reportId} not found`);
    await assertCanManageGym(this.authzDeps(), userId, report.gymId, role);
    await this.reports.updateStatus(reportId, req.status, new Date().toISOString());
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/messaging.facade.test.mts`; then full `cd apps/api && bun test`.
Expected: PASS (all messaging facade cases + no regressions).

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/facades/messaging.facade.mts apps/api/test/messaging.facade.test.mts
git commit -m "feat(api): MessagingFacade — blocks + reports"
```

---

## Task 14: routes + container + app wiring

**Files:**
- Create: `apps/api/src/routes/messaging.routes.mts`
- Modify: `apps/api/src/container.mts`, `apps/api/src/app.mts`
- Test: `apps/api/test/messaging.routes.test.mts`

**Interfaces:**
- Consumes `container.messagingFacade`, `authPlugin`, `requireAuth`, `data`/`list`, request schemas from Tasks 1–3.
- Produces the routes below. Model **exactly** on `forum.routes.mts`: `authPlugin(container.verifier, container.roleLookup)`, prefixed Elysia instances, `requireId(identity)` helper, `data`/`list` envelopes, `requireAuth: true` on ALL routes, `// eslint-disable-next-line @typescript-eslint/explicit-function-return-type` on the export.

Two prefixed instances combined via a root `new Elysia().use(...).use(...)`:

**`/api/v1/gyms` instance:**
- `POST /:id/channels` (`CreateChannelRequest`) → `data(createChannel(caller.userId, params.id, body, caller.role))`
- `GET /:id/channels` → `data(listChannels(caller.userId, params.id, caller.role))`
- `GET /:id/message-reports` (`query: { status?: MessageReportStatus }`) → `list(listReports(caller.userId, params.id, query.status, caller.role))`

**`/api/v1/messaging` instance:**
- `POST /direct` (`StartDirectRequest`) → `data(startDirect(caller.userId, body.recipientId, caller.role))`
- `POST /groups` (`CreateGroupRequest`) → `data(createGroup(caller.userId, body.gymId, body, caller.role))`
- `GET /conversations` (`ConversationListQuery`) → `list(listConversations(caller.userId, caller.role, page, limit))`
- `GET /conversations/:id/messages` (`MessageListQuery`) → `list(getMessages(caller.userId, params.id, query, caller.role))` (return `list(items, { page: 1, limit, total: items.length })` — cursor pagination, so echo a single page)
- `POST /conversations/:id/messages` (`SendMessageRequest`) → `data(sendMessage(...))`
- `POST /conversations/:id/read` → `markRead`; `data({ ok: true })`
- `POST /conversations/:id/mute` (`SetMutedRequest`) → `setMuted`; `data({ ok: true })`
- `POST /conversations/:id/leave` → `leaveConversation`; `data({ ok: true })`
- `POST /conversations/:id/participants` (`AddParticipantsRequest`) → `addParticipants`; `data({ ok: true })`
- `PATCH /messages/:id` (`EditMessageRequest`) → `data(editMessage(...))`
- `DELETE /messages/:id` → `deleteMessage`; `data({ ok: true })`
- `POST /messages/:id/report` (`body: t.Omit(ReportMessageRequest, ['messageId'])` — OR accept full `ReportMessageRequest` and override `messageId` from `params.id`) → `data(reportMessage(caller.userId, { ...body, messageId: params.id }))`
- `POST /reports` (`ReportMessageRequest`) → `data(reportMessage(caller.userId, body))`
- `POST /reports/:id/resolve` (`ResolveReportRequest`) → `resolveReport`; `data({ ok: true })`
- `GET /blocks` → `list(listBlocks(caller.userId).then(ids => ids.map(id => ({ blockedId: id }))))` — return `list` of `{ blockedId }` objects.
- `POST /blocks` (`BlockUserRequest`) → `blockUser`; `data({ ok: true })`
- `DELETE /blocks/:id` → `unblockUser(caller.userId, params.id)`; `data({ ok: true })`

Wire `container.mts`: import the six repos + `MessagingFacade`; construct `conversationRepo`, `messageRepo`, `conversationParticipantRepo`, `channelReadStateRepo`, `userBlockRepo`, `messageReportRepo`; add `readonly messagingFacade: MessagingFacade` to `Container`; build `messagingFacade: new MessagingFacade(conversationRepo, messageRepo, conversationParticipantRepo, channelReadStateRepo, userBlockRepo, messageReportRepo, membershipRepo, gymRepo, id)` (reuse existing `membershipRepo`, `gymRepo`, `id`); in `ensureIndexes()` add the six new `ensureIndexes()` calls. Wire `app.mts`: import + `.use(messagingRoutes(container))`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/messaging.routes.test.mts
import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { registerErrorHandler } from "../src/http/error-handler.mts";
import { messagingRoutes } from "../src/routes/messaging.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const messagingFacade = {
    startDirect: async (u: string, r: string) => { calls.push(`direct:${u}:${r}`); return { id: "c1", kind: "direct", pairKey: `${u}|${r}`, createdBy: u }; },
    createGroup: async (u: string, g: string) => { calls.push(`group:${u}:${g}`); return { id: "c2", kind: "group", gymId: g, title: "S", createdBy: u }; },
    createChannel: async (u: string, g: string) => { calls.push(`channel:${u}:${g}`); return { id: "c3", kind: "gym_channel", gymId: g, title: "General", createdBy: u }; },
    listChannels: async () => [],
    listConversations: async () => ({ items: [], total: 0 }),
    getMessages: async () => [],
    sendMessage: async (u: string, c: string) => { calls.push(`send:${u}:${c}`); return { id: "m1", conversationId: c, authorId: u, body: "hi" }; },
    markRead: async (): Promise<void> => { calls.push("read"); },
    setMuted: async (): Promise<void> => { calls.push("mute"); },
    leaveConversation: async (): Promise<void> => { calls.push("leave"); },
    addParticipants: async (): Promise<void> => { calls.push("addp"); },
    editMessage: async () => ({ id: "m1", conversationId: "c1", authorId: "u1", body: "e" }),
    deleteMessage: async (): Promise<void> => { calls.push("delmsg"); },
    reportMessage: async () => ({ id: "r1", reportedUserId: "u2", reporterId: "u1", gymId: "g1", reason: "spam", status: "open" }),
    listReports: async () => [],
    resolveReport: async (): Promise<void> => { calls.push("resolve"); },
    listBlocks: async () => [],
    blockUser: async (): Promise<void> => { calls.push("block"); },
    unblockUser: async (): Promise<void> => { calls.push("unblock"); },
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    messagingFacade,
  } as unknown as Container;
  const app = registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined }).use(messagingRoutes(container));
  return { app, calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("messaging routes", () => {
  it("POST /direct requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/direct", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ recipientId: "u2" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST /direct calls facade with caller + recipient", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/direct", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ recipientId: "u2" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("direct:u1:u2");
  });
  it("POST send message calls facade with caller + conversation", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/conversations/c9/messages", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ body: "hi" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("send:u1:c9");
  });
  it("POST channel create is gym-scoped", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/channels", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ title: "Announcements" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("channel:u1:g1");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/messaging.routes.test.mts`
Expected: FAIL — `messagingRoutes` not found.

- [ ] **Step 3: Write minimal implementation**

Implement `messaging.routes.mts` per the route table above (copy the structure of `forum.routes.mts` verbatim, swapping facade + schemas). Wire `container.mts` and `app.mts` as described in **Interfaces**.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/api && bun test test/messaging.routes.test.mts`, then `bun test test/boot.test.mts`, then full `cd apps/api && bun test`.
Expected: PASS; no regressions.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/routes/messaging.routes.mts apps/api/src/container.mts apps/api/src/app.mts apps/api/test/messaging.routes.test.mts
git commit -m "feat(api): messaging routes wired into container and app"
```

---

## Task 15: OpenAPI + Postman docs

**Files:** Modify `apps/api/src/openapi.mts`, regenerate `apps/api/openapi.json`, add a "Messaging" Postman folder.

- [ ] **Step 1:** In `openapi.mts` (hand-listed), add the messaging paths (all from Task 14) with request/response schema refs. Register component schemas: `ConversationKind`, `ParticipantRole`, `MessageReportReason`, `MessageReportStatus`, `Conversation`, `Message`, `ConversationParticipant`, `ChannelReadState`, `UserBlock`, `MessageReport`, `ConversationSummary`, `StartDirectRequest`, `CreateGroupRequest`, `CreateChannelRequest`, `SendMessageRequest`, `EditMessageRequest`, `AddParticipantsRequest`, `SetMutedRequest`, `BlockUserRequest`, `ReportMessageRequest`, `ResolveReportRequest`, `ConversationListQuery`, `MessageListQuery`.
- [ ] **Step 2:** Regenerate committed `apps/api/openapi.json`; add the Postman folder mirroring the existing folders.
- [ ] **Step 3:** `cd apps/api && bun test` — full suite green.
- [ ] **Step 4: Commit** `docs(api): document messaging endpoints`.

---

## Task 16: Flutter models + endpoints

**Files:**
- Create: `apps/mobile/lib/features/messaging/models/conversation.dart`, `message.dart`, `conversation_participant.dart`, `conversation_summary.dart`, `message_report.dart`, `user_block.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart`
- Test: `apps/mobile/test/messaging/conversation_test.dart`

**Interfaces:**
- Dart models (const ctor + `fromJson`, camelCase mirroring contracts). `Conversation`: id, kind, gymId?, title?, pairKey?, createdBy, createdAt?, lastMessageAt?, lastMessagePreview?. `Message`: id, conversationId, authorId, body, createdAt?, editedAt?, deletedAt?. `ConversationParticipant`: id, conversationId, userId, role, lastReadAt?, muted, leftAt?. `ConversationSummary`: conversation(Conversation), unreadCount(int), muted(bool), lastMessage?(Message), otherParticipantIds(List<String>). `MessageReport`, `UserBlock` mirror the contracts. Add a getter `Message.isDeleted => deletedAt != null`.
- `Endpoints` (add a `// Messaging` section):
  - `messagingDirect => '/api/v1/messaging/direct'`
  - `messagingGroups => '/api/v1/messaging/groups'`
  - `messagingConversations => '/api/v1/messaging/conversations'`
  - `messagingConversationMessages(String id) => '/api/v1/messaging/conversations/$id/messages'`
  - `messagingConversationRead(String id) => '/api/v1/messaging/conversations/$id/read'`
  - `messagingConversationMute(String id) => '/api/v1/messaging/conversations/$id/mute'`
  - `messagingConversationLeave(String id) => '/api/v1/messaging/conversations/$id/leave'`
  - `messagingConversationParticipants(String id) => '/api/v1/messaging/conversations/$id/participants'`
  - `messagingMessage(String id) => '/api/v1/messaging/messages/$id'`
  - `messagingMessageReport(String id) => '/api/v1/messaging/messages/$id/report'`
  - `messagingReports => '/api/v1/messaging/reports'`
  - `messagingReportResolve(String id) => '/api/v1/messaging/reports/$id/resolve'`
  - `messagingBlocks => '/api/v1/messaging/blocks'`
  - `messagingBlock(String id) => '/api/v1/messaging/blocks/$id'`
  - `gymChannels(String gymId) => '/api/v1/gyms/$gymId/channels'`
  - `gymMessageReports(String gymId) => '/api/v1/gyms/$gymId/message-reports'`

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/messaging/conversation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';

void main() {
  test('ConversationSummary.fromJson maps conversation + unread + last message', () {
    final s = ConversationSummary.fromJson(const {
      'conversation': {'id': 'c1', 'kind': 'direct', 'pairKey': 'u1|u2', 'createdBy': 'u1', 'lastMessagePreview': 'hey'},
      'unreadCount': 3,
      'muted': false,
      'lastMessage': {'id': 'm1', 'conversationId': 'c1', 'authorId': 'u2', 'body': 'hey'},
      'otherParticipantIds': ['u2'],
    });
    expect(s.conversation.kind, 'direct');
    expect(s.unreadCount, 3);
    expect(s.lastMessage?.body, 'hey');
    expect(s.otherParticipantIds, ['u2']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd apps/mobile && flutter test test/messaging/conversation_test.dart` → FAIL (model not found).
- [ ] **Step 3: Write minimal implementation** — create the six models mirroring `forum_question.dart` style (required non-null casts; `muted`/bools as `json['x'] as bool? ?? false`; `unreadCount` as `json['unreadCount'] as int? ?? 0`; nested via `Conversation.fromJson` / `Message.fromJson`; lists via `.map(...).toList()`); add the `Endpoints` helpers.
- [ ] **Step 4: Run test to verify it passes** — PASS.
- [ ] **Step 5: Commit** `feat(mobile): messaging models + endpoints`.

---

## Task 17: Flutter messaging repository + providers

**Files:**
- Create: `apps/mobile/lib/features/messaging/data/messaging_repository.dart`
- Test: `apps/mobile/test/messaging/messaging_repository_test.dart`

**Interfaces:**
- `MessagingRepository` (abstract) + `ApiMessagingRepository` (matches `forum_repository.dart`):
  - `Future<List<ConversationSummary>> listConversations({int page, int limit})` — GET `messagingConversations` → unwrapList.
  - `Future<List<Message>> listMessages(String conversationId, {String? before, int limit})` — GET `messagingConversationMessages` → unwrapList.
  - `Future<Message> sendMessage(String conversationId, String body)` — POST.
  - `Future<Conversation> startDirect(String recipientId)` — POST `messagingDirect` `{recipientId}` → unwrapData.
  - `Future<Conversation> createGroup(String gymId, String title, List<String> participantIds)` — POST `messagingGroups`.
  - `Future<List<Conversation>> listChannels(String gymId)` — GET `gymChannels`.
  - `Future<Conversation> createChannel(String gymId, String title)` — POST `gymChannels`.
  - `Future<void> markRead(String conversationId)`, `Future<void> setMuted(String conversationId, bool muted)`, `Future<void> leave(String conversationId)`, `Future<void> addParticipants(String conversationId, List<String> userIds)`.
  - `Future<Message> editMessage(String messageId, String body)`, `Future<void> deleteMessage(String messageId)`.
  - `Future<void> reportMessage({String? messageId, required String reportedUserId, required String reason, String? note})` — POST `messagingMessageReport(messageId)` when messageId given, else `messagingReports`.
  - `Future<List<MessageReport>> listGymReports(String gymId, {String? status})`, `Future<void> resolveReport(String reportId, String status)`.
  - `Future<List<String>> listBlocks()` (map `{blockedId}` items → ids), `Future<void> blockUser(String userId)`, `Future<void> unblockUser(String blockId)`.
- Providers: `messagingRepositoryProvider`; `conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>`; `messagesProvider = FutureProvider.family.autoDispose<List<Message>, String>`; `gymChannelsProvider = FutureProvider.family<List<Conversation>, String>`; `blocksProvider = FutureProvider<List<String>>`; `gymMessageReportsProvider = FutureProvider.family<List<MessageReport>, ({String gymId, String? status})>`.

- [ ] **Step 1:** Write the failing test — fake Dio adapter returns `{"data":{"items":[...ConversationSummary...],"page":1,"limit":20,"total":1}}` for GET conversations; assert `listConversations()` parses. Model on `forum_repository_test.dart`.
- [ ] **Step 2:** `cd apps/mobile && flutter test test/messaging/messaging_repository_test.dart` → FAIL.
- [ ] **Step 3:** Implement modeled on `forum_repository.dart` (try/catch DioException → ApiException.fromDio; unwrapData/unwrapList; only-non-null query). Providers like the forum ones.
- [ ] **Step 4:** `flutter test test/messaging/messaging_repository_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(mobile): messaging repository + providers`.

---

## Task 18: Conversations list screen + nav entry

**Files:**
- Create: `apps/mobile/lib/features/messaging/screens/conversations_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (add `/messages` route + nav destination)
- Test: `apps/mobile/test/messaging/conversations_screen_test.dart`

**Interfaces:**
- Consumes `conversationsProvider`. `ConversationsScreen()`: watches the provider; renders each `ConversationSummary` (title — for `direct` show the other participant id/name, for `group`/`gym_channel` show `conversation.title`; last-message preview; unread badge when `unreadCount > 0`; mute icon when `muted`); tapping opens the thread (`/messages/:conversationId`, passing gymId when present); a FAB → new-message screen. AsyncValue loading/error/empty. Refresh on pull + on `AppLifecycleState.resumed` and a periodic `Timer.periodic` (dispose in `dispose()` — see the reviews-provider timer-test gotcha in memory).
- Router: add a `/messages` destination to the main nav shell (with an aggregate unread badge derived from `conversationsProvider`), plus a child route `/messages/:id` → thread screen.

- [ ] **Step 1:** Widget test: override `conversationsProvider` → two summaries (one group with unread 2, one direct muted); pump in MaterialApp+ProviderScope; assert both titles render, the unread badge "2" shows, and the mute icon shows. Model on `forum_list_screen_test.dart`.
- [ ] **Step 2:** `flutter test test/messaging/conversations_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement list + nav entry + route.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): conversations list screen + nav entry`.

---

## Task 19: Conversation thread screen — messages, composer, author/admin actions

**Files:**
- Create: `apps/mobile/lib/features/messaging/screens/conversation_screen.dart`
- Modify: `apps/mobile/lib/app/router.dart` (thread route), `conversations_screen.dart` (tap → thread)
- Test: `apps/mobile/test/messaging/conversation_screen_test.dart`

**Interfaces:**
- Consumes `messagesProvider.family(conversationId)`, `messagingRepositoryProvider`, `currentUserIdProvider`, and the `canManage` gate (isAdmin || isOwner || gymRole in {owner,coach}) derived like the forum screen. `ConversationScreen({required String conversationId, String? gymId, required String kind})`: shows messages oldest-at-bottom; each message shows author + body (or "message removed" when `isDeleted`); a composer (multiline + Send) → `sendMessage` then invalidate `messagesProvider`; long-press/overflow on own message → Edit/Delete; for managers, Delete on any message (channel/group); overflow → Report (opens a reason picker → `reportMessage`); for a `direct` thread, an app-bar Block action → `blockUser` then pop. Short poll timer while mounted (dispose on unmount).
- Router: `/messages/:id` builds `ConversationScreen` (read kind/gymId from `extra` or a lightweight fetch).

- [ ] **Step 1:** Widget test: override `messagesProvider('c1')` → two messages (one authored by current user, one deleted); fake `messagingRepositoryProvider` recording calls; `currentUserIdProvider` = author; pump; assert the deleted message renders "message removed"; type + Send → assert `sendMessage('c1', ...)`; tap Delete on own message → assert `deleteMessage(...)`. Model on `forum_question_screen_test.dart`.
- [ ] **Step 2:** `flutter test test/messaging/conversation_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement thread + composer + actions + route + list→thread nav.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): conversation thread screen with composer + author/admin actions`.

---

## Task 20: New-message flow (direct / group / channel) + gym-detail Channels entry

**Files:**
- Create: `apps/mobile/lib/features/messaging/screens/new_message_screen.dart`
- Modify: `apps/mobile/lib/features/gyms/screens/gym_detail_screen.dart` (member-gated "Channels" entry), `app/router.dart` if needed
- Test: `apps/mobile/test/messaging/new_message_screen_test.dart`

**Interfaces:**
- Consumes `rosterProvider(gymId)` (shared-gym member candidates), `messagingRepositoryProvider`, the `canManage` gate. `NewMessageScreen({required String gymId})`: a segmented control for **Direct** (pick one member → `startDirect` → open thread), **Group** (title + multi-select members → `createGroup` → open thread), and **Channel** (managers only: title → `createChannel` → open thread). After create, invalidate `conversationsProvider`/`gymChannelsProvider` and navigate to the thread.
- Gym detail: a member-gated "Channels" entry (like the forum entry) → a channels list (reuse `gymChannelsProvider`) that opens each channel thread; the "＋ New message" affordance lives here and on the conversations FAB.

- [ ] **Step 1:** Widget test: pump `NewMessageScreen(gymId:'g1')` with `rosterProvider` overridden (two members) + fake repo recording calls; Direct tab: pick a member + Start → assert `startDirect(memberId)`. Group tab: title + select member + Create → assert `createGroup('g1', title, [memberId])`. As a manager, Channel tab visible; as non-manager, hidden. Model on `ask_question_screen_test.dart`.
- [ ] **Step 2:** `flutter test test/messaging/new_message_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement the flow + gym-detail Channels entry.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(mobile): new-message flow + gym-detail channels entry`.

---

## Task 21: Blocked-users setting + gym reports review screen

**Files:**
- Create: `apps/mobile/lib/features/messaging/screens/blocked_users_screen.dart`, `screens/gym_reports_screen.dart`
- Modify: `apps/mobile/lib/features/settings/screens/settings_screen.dart` (Blocked users entry), `app/router.dart`
- Test: `apps/mobile/test/messaging/blocked_users_screen_test.dart`, `apps/mobile/test/messaging/gym_reports_screen_test.dart`

**Interfaces:**
- Consumes `blocksProvider`, `gymMessageReportsProvider.family`, `messagingRepositoryProvider`, `canManage`. `BlockedUsersScreen()`: lists blocked user ids with an Unblock action → `unblockUser` then invalidate `blocksProvider`. `GymReportsScreen({required String gymId})`: managers only; lists open `MessageReport`s (reason, reporter, note) with Mark-reviewed / Dismiss → `resolveReport(id, status)` then invalidate.
- Settings gets a "Blocked users" row → `BlockedUsersScreen`. Gym detail (managers) gets a "Message reports" entry → `GymReportsScreen(gymId)`.

- [ ] **Step 1:** Two widget tests: (a) `BlockedUsersScreen` with `blocksProvider` → ['u2'] + fake repo; tap Unblock → assert `unblockUser` called. (b) `GymReportsScreen(gymId:'g1')` with `gymMessageReportsProvider` → one open report; tap Mark-reviewed → assert `resolveReport('r1','reviewed')`.
- [ ] **Step 2:** `flutter test test/messaging/blocked_users_screen_test.dart test/messaging/gym_reports_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implement both screens + entries.
- [ ] **Step 4:** `flutter test ...` → PASS; `flutter analyze` clean; run full `cd apps/mobile && flutter test`.
- [ ] **Step 5: Commit** `feat(mobile): blocked-users setting + gym message-reports review`.

---

## Task 22: End-to-end verification pass

**Files:** none (verification). Do NOT weaken any test.

- [ ] **Step 1:** API: `cd apps/api && bun test` — full suite green (local Mongo on 27017). Prior features' tests must still pass. `cd packages/contract && bun test` — green.
- [ ] **Step 2:** Real API boot smoke — never touch production. Boot with a throwaway local db + self-contained bypass env on a non-default port (kill stale :3199 first):
  ```
  cd apps/api
  MONGODB_URI="mongodb://localhost:27017/bjj_msg_verify" PORT=3199 \
  AUTH_BYPASS_SECRET="verify-secret" DEMO_USER_ID="verify-user@local" DEMO_USER_ROLE="practitioner" DEMO_USER_EMAIL="verify@local.test" \
  bun run src/index.mts   # background; poll /health
  ```
  Assert (status each): `POST /api/v1/messaging/direct` WITHOUT auth → **401**; WITH `Bearer verify-secret` + `{"recipientId":"someone"}` → **403** (demo user shares no gym with a non-member) — NOTE: if `sharesActiveGym` short-circuits before any gym lookup, this is `forbidden` (403), not 404; assert 403. `GET /api/v1/messaging/conversations/nonexistent/messages` WITH auth → **404**. Kill the server after.
- [ ] **Step 3:** Mobile: `cd apps/mobile && flutter test` — full suite green; `flutter analyze` clean.
- [ ] **Step 4:** Lint: `cd apps/api && bunx eslint --fix` on changed api/contract files; zero errors.
- [ ] **Step 5: Commit** any fixups: `chore: lint and verification fixups for messaging M1`.

---

## Self-Review Notes (author)

- **Spec coverage:** enums + notification-free design (T1); core schemas incl. `ConversationSummary` (T2); requests (T3); conversation repo + collections (T4); message repo w/ cursor + unread + soft-delete (T5); participant repo (T6); channel read-state lazy upsert (T7); block repo either-way (T8); report repo (T9); facade creation + shared-gym gating + default channel (T10); list/read/send + block-hide + unread (T11); edit/delete/participants/leave/mute/mark-read (T12); blocks + reports (T13); routes all-auth + wiring (T14); docs (T15); mobile models/endpoints (T16), repo/providers (T17), conversations list + nav (T18), thread + composer + author/admin actions (T19), new-message flow + channels entry (T20), blocked-users + gym reports review (T21); verification incl. real boot (T22).
- **Decisions honored:** 3 conversation kinds unified with `kind` (T2/T4); shared-gym gate for direct/group (T10); channels = manager-create, members post freely (T10/T11); moderation block/report/admin-delete/leave-mute (T8/T9/T12/T13); polling client (T18/T19); text-only (schemas); no notification-per-message (facade send writes none); direct gating at start (T10); blocked-author hide in group/channel (T11); newest-first `before` cursor (T5/T11).
- **Type consistency:** facade constructor arg order (conversations, messages, participants, channelReads, blocks, reports, memberships, gyms, newId) matches the test harness (T10) and container wiring (T14); repo `Pick` sets match the method names defined in T4–T9; endpoint helpers (T16) match routes (T14); provider record types consistent T17–T21; `assertActiveMember`/`assertCanManageGym` signatures match `gym-authz.mts`.
- **Guardrails flagged:** `$set`/`$unset` split in `ConversationRepository.update` (T4); never both `$set` + `$setOnInsert` on one field in `ChannelReadStateRepository` (T7); soft-deleted `body:""` violates schema minLength but reads don't `Value.Parse` (T5); channel "leave" = mute for implicit membership (T12); report with no shared gym → `bad_request` (T13); real-boot smoke expects **403** (not 404) for a non-shared-gym direct because `sharesActiveGym` short-circuits (T22); dispose polling timers on unmount (T18/T19, reviews-provider timer gotcha).
