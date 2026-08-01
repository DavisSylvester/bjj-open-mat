# Push Notifications — Design Spec

**Date:** 2026-08-01
**Status:** Approved (brainstorm) — pending implementation plan
**Feature branch:** `feature/push-notifications`
**Release target:** blocks App Store **1.1** (per product decision, 1.1 does not ship until push is done)

---

## 1. Problem & goal

The app has an **in-app notification** system (`notifications` collection, `NotificationFacade`,
a notifications list with mark-read; types: `rsvp`, `review`, `session_update`, `system`,
`forum_answer`, `forum_accepted`, `gym_claim`). It has **no device push delivery**, and new
**messages create no notification at all**. Users don't learn about new messages (or other
events) unless they open the app.

**Goal:** deliver push notifications to the user's device for **new messages** and for **all
existing in-app notification event types**, on iOS and Android, using Firebase Cloud Messaging.

---

## 2. Decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Scope of triggers | **Messages + all existing in-app events** (RSVP, review, session_update, system, forum_answer, forum_accepted, gym_claim) |
| Transport | **Firebase Cloud Messaging (HTTP v1)** — single send path for iOS + Android; Firebase relays to APNs |
| User controls | **OS permission + existing per-conversation mute only.** No new preference UI in 1.1 |
| Messages → in-app row? | **Push-only for messages** (no persisted `notifications` row — the conversation list is the durable record). Existing in-app events keep persisting AND now also push |
| Correctness rules | Never push to the message's own sender; respect **blocks**; respect **muted** conversation/channel; skip recipients with no registered tokens |
| Tap behavior | Deep-link via `go_router` to the relevant screen (`/messages/:id` for a message) |

**Deferred (not 1.1):** per-category notification preference UI; quiet hours; rich/image
notifications; grouping/threading; badge-count management; web push.

---

## 3. Architecture & components

### 3.1 Contract (`packages/contract`)
- `DeviceToken` schema: `{ id, userId, token, platform: 'ios' | 'android', createdAt, lastSeenAt }`.
- `RegisterDeviceRequest`: `{ token, platform }` (TypeBox; validated on the route).

### 3.2 API

| Component | Responsibility |
|---|---|
| `DeviceTokenRepository` (`deviceTokens` collection) | `upsertByToken`, `listByUser`, `deleteByToken`, `pruneTokens(tokens[])`. Unique index on `token`. String-`_id` collection (Bun/bson pattern). |
| `PushSender` **port** + `FcmPushSender` **adapter** | Port: `send(tokens, payload) → { unregistered: string[] }`. Adapter calls **FCM HTTP v1**, authenticated by a Firebase **service-account** credential loaded from **AWS Secrets Manager**; returns tokens FCM reports `UNREGISTERED`/`NOT_FOUND`. |
| `PushService` | Orchestrates a send: resolve recipient(s) → apply rules (skip sender / blocked / muted / no-token) → load tokens → `PushSender.send` → prune returned unregistered tokens. **Swallows all errors** (a push failure never fails the originating request). |
| Device routes | `POST /api/v1/devices` (register/upsert), `DELETE /api/v1/devices/:token` (unregister). Auth required; `userId` from the identity. |
| Wiring | `NotificationFacade.create` → after persisting, call `PushService` (covers all existing in-app events). `MessagingFacade.sendMessage` → call `PushService` directly (message push-only). |

**Message push content:** title = sender's **display name**, body = message preview. Reuse the
display-name resolution added in PR #46 (user repo lookup).

**Payload `data`:** `{ type, conversationId? , route? }` — enough for the client to deep-link.

### 3.3 Mobile (`apps/mobile`, Flutter/Riverpod)
- Deps: `firebase_core`, `firebase_messaging`, `flutter_local_notifications` (foreground banner).
- `PushController` (Riverpod): request permission → get token → register; listen
  `onTokenRefresh` → re-register; on logout → unregister + clear.
- Handlers: `onMessage` (foreground → local banner); background/terminated handled by OS;
  `onMessageOpenedApp` / `getInitialMessage` → parse `data` → `go_router` deep-link.

---

## 4. Data flow

**A. Registration:** login/app-start → OS permission prompt → on grant, fetch FCM token →
`POST /api/v1/devices` (upsert by token). `onTokenRefresh` re-registers. Logout → `DELETE`.

**B. Send:** trigger (`sendMessage` or `NotificationFacade.create`) → `PushService` resolves
recipients, applies skip rules, loads `deviceTokens` → `FcmPushSender` sends one HTTP v1 message
per token with `notification{title,body}` + `data{type,conversationId|route}` → prune
unregistered tokens. Errors swallowed.

**C. Receive & tap:** foreground → in-app local banner; background/terminated → OS notification;
tap → `data` → `go_router` to `/messages/:id` (or relevant screen).

---

## 5. External setup (provisioned by the user — gates timeline)

1. **Firebase project** with two apps:
   - iOS, bundle `com.davissylvester.bjjopenmat` → `GoogleService-Info.plist`
   - Android, applicationId → `google-services.json`
2. **APNs Auth Key** (Apple Developer → Keys, APNs enabled) → `.p8` + **Key ID** + **Team ID**;
   upload to **Firebase → Cloud Messaging → APNs Authentication Key**.
3. **iOS App ID:** enable **Push Notifications** capability; build adds **Push Notifications** +
   **Background Modes → Remote notifications** + `aps-environment` entitlement.
4. **Firebase service-account private key** (JSON) for server send → stored in **AWS Secrets
   Manager** (new secret, read by the Lambda like `APP_SECRET_ARN`). Provide the **Firebase
   project ID**.

**CI/build implication (spec'd in the plan):** `GoogleService-Info.plist` / `google-services.json`
and APNs config must reach the CI mobile build (committed or injected as CI secrets); iOS
entitlements/capabilities added to the Xcode project.

---

## 6. Testing

- **API (TDD, `bun test`):** `PushService` unit tests with a **mock `PushSender`** — asserts
  skip rules (sender/blocked/muted/no-token), fan-out to all of a user's tokens, and pruning of
  unregistered tokens. `DeviceTokenRepository` against `mongodb-memory-server`. Route tests
  (auth required, upsert idempotent). `FcmPushSender` is thin and mocked in units; verified once
  manually against real FCM.
- **Mobile (`flutter test`):** `PushController` with a fake messaging/permission layer —
  registers on grant, re-registers on refresh, unregisters on logout, routes a tap payload to the
  correct `go_router` path. Firebase plugin stubbed.
- **End-to-end (manual):** build 120+ on device/emulator; send a message from a second account;
  confirm banner + tap-to-open. FCM is not exercised in CI.

---

## 7. Scope boundaries

**In scope:** device-token register/unregister; FCM send for messages + all existing in-app event
types; foreground banner; tap deep-link; token pruning; block/mute/self rules.

**Out of scope (deferred to 1.2+):** per-category notification preference UI; quiet hours;
rich/image notifications; grouping/threading; badge-count management; web push.

---

## 8. Suggested implementation workstreams

The plan will sequence these; roughly:
1. **Contract + DeviceToken repo + device routes** (register/unregister) — testable, no devices.
2. **PushSender port + PushService + rules** — TDD with mock sender.
3. **FcmPushSender adapter + Secrets Manager wiring** — the real FCM call.
4. **Hook `NotificationFacade.create` + `MessagingFacade.sendMessage`** into `PushService`.
5. **Mobile Firebase integration** — SDK, permission, token lifecycle, handlers, deep-links.
6. **iOS/Android build config + CI** — entitlements, `GoogleService-Info.plist`/`google-services.json`, capabilities.
7. **Manual E2E on build 120+.**
