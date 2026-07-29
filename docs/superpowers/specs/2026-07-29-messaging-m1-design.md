# Member Messaging — M1 (Core Messaging) Design

> Subsystem 5 of the social-gym roadmap, decomposed into three sequenced milestones. **This spec covers M1 only.** M2 (realtime WebSockets) and M3 (push notifications) are separate follow-on specs that layer onto M1's persisted model without schema rework.

**Goal:** Gym-community messaging on the existing stack: members hold 1:1 and group conversations with people they share a gym with, gym managers run gym-wide channels members can read and reply to, and a moderation layer (block, report, admin-delete, leave/mute) keeps it safe — all delivered by polling, exactly like the existing notifications feature.

**Architecture:** TypeBox contracts (`@bjj/contract`) → MongoDB repositories → a `MessagingFacade` (all authorization + orchestration) → Elysia routes via DI → Flutter + Riverpod client delivering by polling. Reuses `assertActiveMember` / `assertCanManageGym` from `apps/api/src/facades/gym-authz.mts`, adds a `sharesActiveGym(a, b)` helper, and reuses the existing membership model as the messaging gate.

**Tech Stack:** Bun, Elysia, TypeBox (`@sinclair/typebox`), MongoDB (`mongodb@^7`), Flutter + Riverpod + Dio. Tests: `bun test` (API/contract), `flutter test` (mobile).

---

## Milestone Decomposition (context)

Messaging was scoped at maximal breadth (1:1 + group + gym channels, realtime, push). To keep each build shippable it is sequenced:

- **M1 — Core messaging (this spec).** Full data model + REST + polling delivery + moderation + Flutter UI. Complete, usable messaging on the current Lambda stack.
- **M2 — Realtime delivery (later spec).** API Gateway WebSocket API + connection-state store + broadcast-on-send. Pure delivery acceleration; **no schema rework** because M1 already persists everything.
- **M3 — Push notifications (later spec).** FCM/APNs, device-token registration, push-on-new-message-when-offline. Independent infra track.

The architectural invariant that makes this safe: **M1 persists the complete model, so M2/M3 are additive delivery paths, not rewrites.**

---

## Product Decisions (resolved)

1. **Conversation kinds:** `direct` (1:1), `group` (multi-member, gym-scoped), `gym_channel` (gym-wide).
2. **DM/group gating:** shared active gym only. You may start a direct conversation with, or add to a group, only users who share at least one active gym membership with you.
3. **Channels:** gym owner/coach/admin create channels; **members read and post replies freely once a channel exists** — the manager gate applies to *channel creation* (and admin moderation), not to posting. (Considered stricter "reply only under an admin message"; rejected as more machinery for little gain.) One default **"General"** channel is auto-created per gym on first channel access/list.
4. **Delivery:** polling (list refresh on focus/interval; open thread polls on a short timer while visible). No realtime, no push in M1.
5. **Moderation (all four):** block a user, report a message/user, gym-manager delete in channels/groups, self-service leave/mute.
6. **Messages are text-only** in M1. Images/attachments deferred to a later track (would reuse the existing S3 presigned-upload pattern).
7. **No notification-per-message** in M1. Unread badges drive awareness; message push belongs to M3.
8. **Direct gating checked at conversation *start*.** Existing threads remain usable if gym overlap later changes; a block still stops sends both ways.
9. **Blocked authors' messages are hidden from the blocker** in group/channel views.
10. **Message pagination:** newest-first with a `before` cursor (createdAt + id tiebreak).
11. **Data model:** Approach A — one unified `Conversation` with a `kind` enum; **explicit** participant rows for direct/group; **implicit** channel membership (via active gym membership) with a **lazy** `ChannelReadState` row created only on first read/mute.

---

## Global Constraints

- TypeScript strict; **no `any`**; explicit return types + access modifiers; explicit variable types.
- TypeBox only (never Zod). Schema-first, `Static<typeof X>`, `$id` on every schema.
- `.mts` source; import specifiers use `.mjs`. Contract TEST files import from source (`../src/index.mts`). One concern per file; barrel via `index.mts`; named exports.
- Backend logging is Winston — **no `console.*`** in `apps/api`. Flutter may use `debugPrint`.
- Layering router → facade → repository; DI via `container.mts`, no `new` in routers. Repo deps via `Pick<>`.
- MongoDB driver `mongodb@^7`. `null !== undefined` care on optional fields; Mongo rejects empty `$set`; never put a field in both `$set` and `$setOnInsert`. Clearing an optional field uses `$unset` (see the forum repo's `$set`/`$unset` split precedent).
- Route param is `:id` where it collides at a path position (memoirist). Gym-scoped creates live under `/api/v1/gyms/:id/...`; everything else under `/api/v1/messaging/...`.
- Health endpoints `/health` and `/ready` only.
- Conventional Commits; **never** add Co-Authored-By. Do NOT commit `packages/contract/src/index.mjs` (gitignored). Commit per task.
- Run `bunx eslint --fix` on changed `apps/api`/`packages/contract` files before each commit; `flutter analyze` clean on changed mobile files.

---

## Data Model

### Enums (`packages/contract/src/enums`)
- `ConversationKind` = `'direct' | 'group' | 'gym_channel'`
- `ParticipantRole` = `'member' | 'admin'`
- `MessageReportReason` = `'spam' | 'harassment' | 'inappropriate' | 'other'`
- `MessageReportStatus` = `'open' | 'reviewed' | 'dismissed'`

### Schemas (`packages/contract/src/schemas`)

- **`Conversation`** = `{ id, kind: ConversationKind, gymId?, title?, pairKey?, createdBy, createdAt?, lastMessageAt?, lastMessagePreview? }`
  - `direct`: `pairKey` = the two user ids sorted and joined (`a|b`), unique; no `title`; `gymId` optional (context only).
  - `group` / `gym_channel`: `gymId` + `title` required; no `pairKey`.
- **`Message`** = `{ id, conversationId, authorId, body: String(minLength 1), createdAt?, editedAt?, deletedAt? }`. Soft-deleted messages return with `deletedAt` set and `body` blanked to `""` at read time (author/content redacted), so threads keep their shape.
- **`ConversationParticipant`** = `{ id, conversationId, userId, role: ParticipantRole (default 'member'), lastReadAt?, muted: Boolean(default false), leftAt? }`.
- **`ChannelReadState`** = `{ id, channelId, userId, lastReadAt?, muted: Boolean(default false) }`.
- **`UserBlock`** = `{ id, blockerId, blockedId, createdAt? }`.
- **`MessageReport`** = `{ id, messageId?, reportedUserId, reporterId, gymId, reason: MessageReportReason, note?, status: MessageReportStatus (default 'open'), createdAt?, reviewedAt? }`.
- **`ConversationSummary`** (list-item read shape) = `{ conversation: Conversation, unreadCount: Integer, muted: Boolean, lastMessage?: Message, otherParticipantIds: String[] }`.

### Request schemas (`packages/contract/src/schemas/requests`)
- `StartDirectRequest` = `{ recipientId }`
- `CreateGroupRequest` = `{ gymId, title (minLength 1), participantIds: String[] (minItems 1) }`
- `CreateChannelRequest` = `{ title (minLength 1) }`  *(gymId comes from the `:id` path param)*
- `SendMessageRequest` = `{ body (minLength 1) }`
- `EditMessageRequest` = `{ body (minLength 1) }`
- `AddParticipantsRequest` = `{ userIds: String[] (minItems 1) }`
- `SetMutedRequest` = `{ muted: Boolean }`
- `BlockUserRequest` = `{ userId }`
- `ReportMessageRequest` = `{ messageId?, reportedUserId, reason: MessageReportReason, note? }`
- `ResolveReportRequest` = `{ status: MessageReportStatus }`  *(`reviewed` | `dismissed`)*
- `ConversationListQuery` = `{ page?: Integer≥1 default 1, limit?: Integer 1..100 default 20 }`
- `MessageListQuery` = `{ before?: String, limit?: Integer 1..100 default 30 }`

### Collections (`apps/api/src/db/collections.mts`)
Add: `conversations`, `messages`, `conversationParticipants`, `channelReadStates`, `userBlocks`, `messageReports`.

---

## Repositories (`apps/api/src/repositories`)

- **`ConversationRepository`** — indexes `{ pairKey: 1 }` (sparse/unique), `{ kind: 1, gymId: 1 }`, `{ lastMessageAt: -1 }`. Methods: `ensureIndexes`, `insert`, `findById`, `findDirectByPairKey`, `listChannelsByGym(gymId)`, `updateLastMessage(id, at, preview)`, `update(id, patch)`, `delete(id)`.
- **`MessageRepository`** — indexes `{ conversationId: 1, createdAt: -1 }`. Methods: `ensureIndexes`, `insert`, `findById`, `listByConversation(conversationId, before?, limit)` (newest-first, cursor by `createdAt`+`id`), `softDelete(id, at)`, `update(id, patch)`, `countAfter(conversationId, afterIso | undefined)` (for unread), `latestForConversation(conversationId)`.
- **`ConversationParticipantRepository`** — indexes `{ conversationId: 1, userId: 1 }` (unique), `{ userId: 1 }`. Methods: `ensureIndexes`, `insertMany`, `find(conversationId, userId)`, `listByConversation(conversationId)`, `listActiveForUser(userId)` (participant rows where `leftAt` unset), `setLastReadAt`, `setMuted`, `setLeftAt`, `delete`.
- **`ChannelReadStateRepository`** — indexes `{ channelId: 1, userId: 1 }` (unique). Methods: `ensureIndexes`, `findOrDefault(channelId, userId)`, `upsertLastReadAt`, `upsertMuted`.
- **`UserBlockRepository`** — indexes `{ blockerId: 1, blockedId: 1 }` (unique). Methods: `ensureIndexes`, `insert`, `existsEitherWay(a, b)`, `listBlockedBy(userId)` (ids the user blocked), `delete(id, blockerId)`.
- **`MessageReportRepository`** — indexes `{ gymId: 1, status: 1, createdAt: -1 }`. Methods: `ensureIndexes`, `insert`, `listByGym(gymId, status?)`, `findById`, `updateStatus(id, status, reviewedAt)`.

All extend `BaseRepository`; use `_id: entity.id` + `stripId` like existing repos.

---

## `MessagingFacade` (`apps/api/src/facades/messaging.facade.mts`)

Consumes (via `Pick`): the six repositories above, `MembershipRepository` (`find` + a list-by-user for `sharesActiveGym`), `GymRepository` (`findById`), `UserRole`, `assertActiveMember`, `assertCanManageGym`, and an `IdFactory`. Adds a private `sharesActiveGym(a, b): Promise<boolean>` (intersect both users' active memberships).

Methods:
- `startDirect(userId, recipientId, role)` → assert `userId !== recipientId` (`bad_request`); `sharesActiveGym` (else `forbidden`); `!blocked either way` (else `forbidden`); find-or-create by `pairKey`; return `Conversation`.
- `createGroup(userId, gymId, req, role)` → `assertActiveMember(gymId)`; each `participantId` must be an active member of `gymId` (else `forbidden`); dedupe + include creator; insert conversation `kind:'group'`; participant rows (creator `admin`, others `member`); return.
- `createChannel(userId, gymId, req, role)` → `assertCanManageGym`; insert `kind:'gym_channel'`; return.
- `listChannels(userId, gymId, role)` → `assertActiveMember(gymId)`; ensure a default "General" channel exists (create once if none); return channels.
- `listConversations(userId, role, page, limit)` → gather direct/group where an **active** participant, plus `gym_channel`s for gyms where the user is an active member; compute `unreadCount` (messages after `lastReadAt` / channel read state), `muted`, `lastMessage`, `otherParticipantIds`; sort by `lastMessageAt` desc; paginate; return `{ items: ConversationSummary[], total }`.
- `getMessages(userId, conversationId, req, role)` → assert access (participant not-left; or active gym member for channel); list messages (cursor); **hide messages whose author the viewer has blocked** (group/channel); update `lastReadAt`/channel read state; return messages (soft-deleted redacted).
- `sendMessage(userId, conversationId, req, role)` → assert access **and** can-post: direct → `!blocked either way`; group → active participant (not left); channel → any active gym member may post (channel *creation* was the manager gate); insert message; `updateLastMessage`; return `Message`. (No Notification write in M1.)
- `editMessage(userId, messageId, req, role)` → author only (else `forbidden`); update body + `editedAt`.
- `deleteMessage(userId, messageId, role)` → author OR (`group`/`gym_channel` → `assertCanManageGym(conversation.gymId)`); soft-delete.
- `addParticipants(userId, conversationId, req, role)` → group only; caller is an `admin` participant; each new user active member of the group's `gymId`; insert participant rows.
- `leaveConversation(userId, conversationId)` → group/channel; set `leftAt` (group) or mark channel read-state left-equivalent (channels: leaving = mute, since membership is implicit — leaving a channel just mutes/hides it).
- `setMuted(userId, conversationId, muted)` → set on participant row or channel read state.
- `markRead(userId, conversationId)` → set `lastReadAt = now` on the right store.
- `blockUser(userId, targetId)` / `unblockUser(userId, blockId)` / `listBlocks(userId)`.
- `reportMessage(userId, req)` → resolve `gymId` (the message's conversation `gymId`, or a shared gym for a direct/user report; else `bad_request`); insert `MessageReport` (`status:'open'`); return.
- `listReports(userId, gymId, status, role)` → `assertCanManageGym`; list.
- `resolveReport(userId, reportId, req, role)` → find (404); `assertCanManageGym(report.gymId)`; `updateStatus`.

**Authorization note — channel leave semantics:** because channel membership is implicit, "leave" is modeled as mute-and-hide via `ChannelReadState`; the user regains the channel automatically while still an active gym member if they unmute. This keeps channels row-free per member.

---

## Routes (`apps/api/src/routes/messaging.routes.mts`)

Prefixed Elysia instances; `authPlugin(container.verifier, container.roleLookup)`; `requireId` helper; `data`/`list` envelopes; `requireAuth: true` on ALL routes.

**Gym-scoped (`/api/v1/gyms`):**
- `POST /api/v1/gyms/:id/channels` (`CreateChannelRequest`) → `data(createChannel)`
- `GET /api/v1/gyms/:id/channels` → `list(listChannels)`
- `GET /api/v1/gyms/:id/message-reports` (`?status`) → `list(listReports)` *(managers)*

**Messaging (`/api/v1/messaging`):**
- `POST /direct` (`StartDirectRequest`) → `data(startDirect)`
- `POST /groups` (`CreateGroupRequest`) → `data(createGroup)`
- `GET /conversations` (`ConversationListQuery`) → `list(listConversations)`
- `GET /conversations/:id` → `data(getConversation)` *(conversation + participants)*
- `GET /conversations/:id/messages` (`MessageListQuery`) → `list(getMessages)`
- `POST /conversations/:id/messages` (`SendMessageRequest`) → `data(sendMessage)`
- `POST /conversations/:id/read` → `data({ ok: true })`
- `POST /conversations/:id/mute` (`SetMutedRequest`) → `data({ ok: true })`
- `POST /conversations/:id/leave` → `data({ ok: true })`
- `POST /conversations/:id/participants` (`AddParticipantsRequest`) → `data({ ok: true })`
- `PATCH /messages/:id` (`EditMessageRequest`) → `data(editMessage)`
- `DELETE /messages/:id` → `data({ ok: true })`
- `POST /messages/:id/report` (`ReportMessageRequest` sans messageId) → `data(report)` *(messageId from path)*
- `POST /reports` (`ReportMessageRequest`) → `data(report)` *(user-level report, no message)*
- `POST /reports/:id/resolve` (`ResolveReportRequest`) → `data({ ok: true })`
- `GET /blocks` → `list(listBlocks)`
- `POST /blocks` (`BlockUserRequest`) → `data({ ok: true })`
- `DELETE /blocks/:id` → `data({ ok: true })`

Wire `container.mts` (construct the six repos + `MessagingFacade`, add `ensureIndexes()` calls) and `app.mts` (`.use(messagingRoutes(container))`).

---

## Client (`apps/mobile/lib/features/messaging`)

- **Models:** `conversation.dart`, `message.dart`, `conversation_participant.dart`, `conversation_summary.dart`, `message_report.dart`, `user_block.dart` (const ctor + `fromJson`, camelCase mirroring contracts).
- **Endpoints:** add a `// Messaging` section to `core/api/endpoints.dart` mirroring the routes.
- **Repository + providers:** `MessagingRepository` (abstract) + `ApiMessagingRepository` (Dio, try/catch → `ApiException.fromDio`, unwrapData/unwrapList, only-non-null query), modeled on `forum_repository.dart`. Providers: `messagingRepositoryProvider`, `conversationsProvider` (FutureProvider, refresh on focus/interval), `messagesProvider.family<..., String>` (per conversation, short poll timer while visible), `blocksProvider`, `gymChannelsProvider.family`, `gymMessageReportsProvider.family`.
- **Screens:**
  - `conversations_screen.dart` — list with unread badges, mute indicator, last-message preview; FAB → new message.
  - `conversation_screen.dart` — thread: message list (accepted-first N/A; soft-deleted shown as "message removed"), composer (disabled/hidden appropriately), author edit/delete, gym-manager delete, report action, block action from a direct thread.
  - `new_message_screen.dart` — pick a shared-gym member → direct; create group (title + multi-select shared-gym members); managers create a channel.
  - `blocked_users_screen.dart` — under settings; list + unblock.
  - `gym_reports_screen.dart` — managers review/resolve reports for a gym.
- **Entry points:** a "Messages" nav destination (with an aggregate unread badge) and a "Channels" entry on gym detail (member-gated, like the forum entry).
- **Polling:** conversations list refreshes on app-resume + a periodic timer; the open thread polls every few seconds while mounted (dispose the timer on unmount — see the detail-screen reviews-provider timer-test gotcha in memory).

---

## Error Handling

`AppError` codes: `unauthorized` (401), `forbidden` (403) — not a shared-gym member, blocked, non-participant, non-manager posting to a manager-only surface; `not_found` (404) — missing conversation/message/report/gym; `bad_request` (400) — self-DM, report with neither messageId nor resolvable gym, adding a non-member to a group; `conflict` (409) — reserved (e.g., duplicate block) where applicable.

---

## Testing Strategy

TDD per task, RED → GREEN → commit:
- **Contract:** `Value.Check`/`Value.Parse` for every enum, schema (defaults), and request (required/optional).
- **Repositories:** Mongo on `localhost:27017` (throwaway db per file; `dropDatabase` in `afterAll`). Cover pairKey find-or-create, message cursor pagination + newest-first, unread counting, participant active/left filtering, lazy channel read-state, block existence-either-way, report list-by-gym+status.
- **`MessagingFacade`:** in-memory fakes for all deps; cover — non-shared-gym direct rejected; block stops direct start + send both ways; group create rejects a non-member participant; channel create requires manager, member can post replies; implicit channel access for active gym members; unread counts; blocked-author messages hidden in group/channel; author vs manager delete; report scoping + manager-only review; leave/mute.
- **Routes:** auth (401 without token) + delegation with caller id (fake facade recording calls), modeled on `forum.routes.test.mts`.
- **Mobile:** widget tests per screen (providers overridden with fakes); `flutter analyze` clean.
- **Verification pass (final task):** full `bun test` (api + contract) green, `flutter test` green, eslint `--fix` clean, and a real-boot smoke on a throwaway db + non-default port asserting: unauth `POST /api/v1/messaging/direct` → 401; authed direct to a non-shared-gym user → 403; `GET /api/v1/messaging/conversations/nonexistent/messages` → 404.

---

## File Structure

**`packages/contract/src`**
- `enums/`: `conversation-kind.mts`, `participant-role.mts`, `message-report-reason.mts`, `message-report-status.mts` (+ barrel)
- `schemas/`: `conversation.mts`, `message.mts`, `conversation-participant.mts`, `channel-read-state.mts`, `user-block.mts`, `message-report.mts`, `conversation-summary.mts` (+ barrel)
- `schemas/requests/messaging-requests.mts` (+ barrel)

**`apps/api/src`**
- `repositories/`: `conversation.repository.mts`, `message.repository.mts`, `conversation-participant.repository.mts`, `channel-read-state.repository.mts`, `user-block.repository.mts`, `message-report.repository.mts`
- `facades/messaging.facade.mts` (+ `sharesActiveGym` helper, in `messaging.facade.mts` or `gym-authz.mts`)
- `routes/messaging.routes.mts`
- Modify: `db/collections.mts`, `container.mts`, `app.mts`, `openapi.mts`

**`apps/mobile/lib/features/messaging`**
- `models/`, `data/messaging_repository.dart` (+ providers), `screens/` (5 screens), `widgets/` as needed
- Modify: `core/api/endpoints.dart`, `app/router.dart`, gym-detail + settings entry points

---

## Out of Scope for M1 (explicit)

- Realtime WebSocket delivery (**M2**).
- Push notifications / FCM/APNs / device tokens (**M3**).
- Image/file attachments, voice notes, reactions, typing indicators, read receipts beyond unread counts.
- Cross-gym / public messaging (shared-gym gate is intentional).
- Notification-feed entries per message.
