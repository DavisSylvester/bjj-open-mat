# Profile Screen Metadata & SSO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Profile screen show real user metadata, keep social/SSO identity (name/email/avatar) provider-authoritative and read-only while allowing only birthday/belt/home-gym edits, and make the Home nav icon reset the discover feed to its root.

**Architecture:** Add a `birthday` field through the contract → API → mobile. Derive "is this a social user?" from the Auth0 subject (`sub`) both server-side (enforce the restricted edit set by stripping disallowed fields) and client-side (shape the edit UI). Sync Google/OIDC name/email/avatar to the API on login via a dedicated sync endpoint. Rebuild the Profile screen on the glass design system with real stats from `myCheckins`. Fix the bottom-nav Home tap to reset its branch.

**Tech Stack:** Bun, Elysia, TypeBox (`@bjj/contract`), MongoDB, Flutter (Riverpod, go_router), Dio.

## Global Constraints

- TypeBox only (no Zod); schema-first, derive types with `Static<>`. Strict TS: explicit types/returns/access modifiers, no `any`.
- Flutter: Riverpod `NotifierProvider`/`FutureProvider` (no legacy `StateProvider`); glass design via `Theme.of(context).extension<AppTokens>()`.
- Health endpoints unchanged. Winston logging on API (no `console.*`). Conventional commits, no Co-Authored-By.
- `isSocial(sub)` ≡ `sub.includes("|") && !sub.startsWith("auth0|")`. Social users' editable fields = **exactly** `{ birthday, beltRank, beltStripes, homeGymId }`. Identity fields (`displayName`, `email`, `avatarUrl`) for social users are provider-authoritative.
- Birthday is an ISO `YYYY-MM-DD` string. Age is computed in the UI, never stored.
- Disallowed edits for social users are **stripped** server-side (silently ignored), not rejected.

---

### Task 1: Contract — `birthday` field + auth-sync request

**Files:**
- Modify: `packages/contract/src/schemas/user.mts`
- Modify: `packages/contract/src/schemas/requests/user-requests.mts`
- Create: `packages/contract/src/schemas/requests/auth-sync-request.mts`
- Modify: `packages/contract/src/schemas/index.mts` (barrel export the new request)
- Test: `apps/api/test/contract-birthday.test.mts`

**Interfaces:**
- Produces: `User.birthday?: string`; `UpdateUserRequest.birthday?: string`; `AuthSyncRequest = { displayName?: string; email?: string; avatarUrl?: string }`.

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/contract-birthday.test.mts
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { UpdateUserRequest, AuthSyncRequest } from "@bjj/contract";

describe("contract: birthday + auth sync", () => {
  it("UpdateUserRequest accepts an ISO birthday", () => {
    expect(Value.Check(UpdateUserRequest, { birthday: "1990-01-05" })).toBe(true);
  });
  it("AuthSyncRequest accepts provider identity claims", () => {
    expect(Value.Check(AuthSyncRequest, { displayName: "Ada", email: "a@x.io", avatarUrl: "https://x/i.png" })).toBe(true);
    expect(Value.Check(AuthSyncRequest, {})).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/contract-birthday.test.mts`
Expected: FAIL — `AuthSyncRequest` is not exported / `birthday` rejected.

- [ ] **Step 3: Add `birthday` to `User`**

In `packages/contract/src/schemas/user.mts`, inside the `User` object (after `homeGymId`):
```ts
    homeGymId: t.Optional(t.String()),
    birthday: t.Optional(t.String()), // ISO YYYY-MM-DD
```

- [ ] **Step 4: Add `birthday` to `UpdateUserRequest`**

In `packages/contract/src/schemas/requests/user-requests.mts`, inside the `t.Object` passed to `t.Partial` (after `homeGymId: t.String(),`):
```ts
    homeGymId: t.String(),
    birthday: t.String(),
```

- [ ] **Step 5: Create the auth-sync request schema**

```ts
// packages/contract/src/schemas/requests/auth-sync-request.mts
import { type Static, Type as t } from "@sinclair/typebox";

export const AuthSyncRequest = t.Object(
  {
    displayName: t.Optional(t.String()),
    email: t.Optional(t.String()),
    avatarUrl: t.Optional(t.String()),
  },
  { $id: "AuthSyncRequest" },
);
export type AuthSyncRequest = Static<typeof AuthSyncRequest>;
```

- [ ] **Step 6: Barrel-export it**

In `packages/contract/src/schemas/index.mts`, add alongside the other request exports:
```ts
export * from "./requests/auth-sync-request.mjs";
```
(Match the existing extension convention in that file — if siblings use `.mts`, use `.mts`; if `.mjs`, use `.mjs`. Verify by opening the file.)

- [ ] **Step 7: Run test to verify it passes**

Run: `cd apps/api && bun test test/contract-birthday.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 8: Commit**

```bash
git add packages/contract/src/schemas/user.mts packages/contract/src/schemas/requests/user-requests.mts packages/contract/src/schemas/requests/auth-sync-request.mts packages/contract/src/schemas/index.mts apps/api/test/contract-birthday.test.mts
git commit -m "feat(contract): add user birthday and AuthSyncRequest"
```

---

### Task 2: API — social-user detection + restricted edit enforcement

**Files:**
- Create: `apps/api/src/auth/is-social.mts`
- Modify: `apps/api/src/repositories/user.repository.mts` (UserDoc gains `birthday?`)
- Modify: `apps/api/src/facades/user.facade.mts` (`updateProfile` strips fields for social users)
- Modify: `apps/api/src/routes/user.routes.mts` (pass social flag)
- Test: `apps/api/test/user-social-edit.test.mts`

**Interfaces:**
- Produces: `isSocial(sub: string): boolean`; `UserFacade.updateProfile(id: string, patch: UpdateUserRequest, isSocialUser?: boolean): Promise<User>`.
- Consumes: `UpdateUserRequest.birthday` (Task 1).

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/user-social-edit.test.mts
import { describe, expect, it } from "bun:test";
import { isSocial } from "../src/auth/is-social.mts";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";

describe("isSocial", () => {
  it("classifies subjects", () => {
    expect(isSocial("google-oauth2|123")).toBe(true);
    expect(isSocial("apple|123")).toBe(true);
    expect(isSocial("auth0|123")).toBe(false); // email-password db
    expect(isSocial("test-user@local.priv")).toBe(false); // dev-bypass
  });
});

describe("updateProfile edit restriction", () => {
  function facadeWith(captured: { patch?: Partial<User> }): UserFacade {
    const base: User = { id: "google-oauth2|1", email: "g@x.io", displayName: "Google Name" };
    const repo: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert"> = {
      findById: async () => base,
      upsertByAuth0Id: async () => base,
      insert: async () => base,
      update: async (_id: string, patch: Partial<User>): Promise<User> => { captured.patch = patch; return { ...base, ...patch }; },
    };
    return new UserFacade(repo);
  }

  it("social user: strips identity/other fields, keeps birthday/belt/homeGym", async () => {
    const cap: { patch?: Partial<User> } = {};
    await facadeWith(cap).updateProfile("google-oauth2|1", {
      displayName: "Hacker", bio: "x", weight: "170", birthday: "1990-01-05", beltRank: "purple", beltStripes: 2, homeGymId: "g-1",
    }, true);
    expect(cap.patch).toEqual({ birthday: "1990-01-05", beltRank: "purple", beltStripes: 2, homeGymId: "g-1" });
  });

  it("non-social user: passes the full patch through", async () => {
    const cap: { patch?: Partial<User> } = {};
    await facadeWith(cap).updateProfile("auth0|1", { displayName: "New Name", birthday: "1991-02-02" }, false);
    expect(cap.patch).toEqual({ displayName: "New Name", birthday: "1991-02-02" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/user-social-edit.test.mts`
Expected: FAIL — `is-social.mts` missing; `updateProfile` ignores the 3rd arg.

- [ ] **Step 3: Create `isSocial`**

```ts
// apps/api/src/auth/is-social.mts
// A social/SSO login's Auth0 subject is "<connection>|<id>" where the
// connection is not the email-password database ("auth0"). Dev-bypass ids
// have no "|" and are treated as non-social (full edit).
export function isSocial(sub: string): boolean {
  return sub.includes("|") && !sub.startsWith("auth0|");
}
```

- [ ] **Step 4: Add `birthday` to the UserDoc type**

In `apps/api/src/repositories/user.repository.mts`, the `UserDoc` interface derives from `User` via `t.Composite([User, ...])`, so no change is needed there — but confirm the local `interface UserDoc`/type includes `User` fields. If there is a hand-written field list, add `birthday?: string;`. (If `UserDoc` is `t.Composite([User, t.Object({ _id: t.String() })])`, `birthday` flows automatically — leave as is.)

- [ ] **Step 5: Strip disallowed fields in `updateProfile`**

In `apps/api/src/facades/user.facade.mts`, replace the `updateProfile` method:
```ts
  public async updateProfile(id: string, patch: UpdateUserRequest, isSocialUser = false): Promise<User> {
    const effective: UpdateUserRequest = isSocialUser ? this.socialAllowed(patch) : patch;
    const updated = await this.users.update(id, effective);
    if (!updated) throw new AppError("not_found", `User ${id} not found`);
    return updated;
  }

  // Social/SSO users may only change these fields; identity comes from the provider.
  private socialAllowed(patch: UpdateUserRequest): UpdateUserRequest {
    const allowed: UpdateUserRequest = {};
    if (patch.birthday !== undefined) allowed.birthday = patch.birthday;
    if (patch.beltRank !== undefined) allowed.beltRank = patch.beltRank;
    if (patch.beltStripes !== undefined) allowed.beltStripes = patch.beltStripes;
    if (patch.homeGymId !== undefined) allowed.homeGymId = patch.homeGymId;
    return allowed;
  }
```

- [ ] **Step 6: Pass the social flag from the route**

In `apps/api/src/routes/user.routes.mts`, import and use `isSocial`. Change the `PUT /api/v1/users/me` handler:
```ts
import { isSocial } from "../auth/is-social.mts";
// ...
    .put(
      "/api/v1/users/me",
      async ({ identity, body }) => {
        const id = requireId(identity).userId;
        return data(await userFacade.updateProfile(id, body, isSocial(id)));
      },
      { requireAuth: true, body: UpdateUserRequest },
    )
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd apps/api && bun test test/user-social-edit.test.mts`
Expected: PASS (3 tests).

- [ ] **Step 8: Run the full API suite + lint**

Run: `cd apps/api && bun test && bunx eslint src/auth/is-social.mts src/facades/user.facade.mts src/routes/user.routes.mts`
Expected: all pass, no lint errors.

- [ ] **Step 9: Commit**

```bash
git add apps/api/src/auth/is-social.mts apps/api/src/facades/user.facade.mts apps/api/src/routes/user.routes.mts apps/api/test/user-social-edit.test.mts
git commit -m "feat(api): restrict social users to birthday/belt/home-gym edits"
```

---

### Task 3: API — provider identity sync endpoint

**Files:**
- Modify: `apps/api/src/facades/user.facade.mts` (`syncFromProvider`)
- Modify: `apps/api/src/routes/user.routes.mts` (`POST /api/v1/auth/sync`)
- Test: `apps/api/test/user-sync.test.mts`

**Interfaces:**
- Produces: `UserFacade.syncFromProvider(identity: AuthIdentity, claims: AuthSyncRequest): Promise<User>` — getOrCreate the user, then for social users overwrite `displayName`/`email`/`avatarUrl` from `claims` (ignoring blanks). Non-social users keep their stored identity.
- Consumes: `AuthSyncRequest` (Task 1), `isSocial` (Task 2).

- [ ] **Step 1: Write the failing test**

```ts
// apps/api/test/user-sync.test.mts
import { describe, expect, it } from "bun:test";
import { UserFacade } from "../src/facades/user.facade.mts";
import type { UserRepository } from "../src/repositories/user.repository.mts";
import type { User } from "@bjj/contract";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function facade(store: Map<string, User>): UserFacade {
  const repo: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert"> = {
    findById: async (id: string) => store.get(id) ?? null,
    upsertByAuth0Id: async () => { throw new Error("unused"); },
    insert: async (u): Promise<User> => { const full = { ...u } as User; store.set(full.id, full); return full; },
    update: async (id: string, patch: Partial<User>): Promise<User | null> => {
      const cur = store.get(id); if (!cur) return null; const next = { ...cur, ...patch }; store.set(id, next); return next;
    },
  };
  return new UserFacade(repo);
}

const googleId: AuthIdentity = { userId: "google-oauth2|9", email: "old@x.io", role: "practitioner" };

describe("syncFromProvider", () => {
  it("social user: applies provider name/email/avatar", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    await f.getOrCreate(googleId);
    const out = await f.syncFromProvider(googleId, { displayName: "Ada Lovelace", email: "ada@x.io", avatarUrl: "https://x/a.png" });
    expect(out.displayName).toBe("Ada Lovelace");
    expect(out.email).toBe("ada@x.io");
    expect(out.avatarUrl).toBe("https://x/a.png");
  });

  it("non-social user: keeps stored identity (claims ignored)", async () => {
    const store = new Map<string, User>();
    const f = facade(store);
    const email = "db@x.io";
    const dbId: AuthIdentity = { userId: "auth0|5", email, role: "practitioner" };
    await f.getOrCreate(dbId);
    const out = await f.syncFromProvider(dbId, { displayName: "Should Not Apply" });
    expect(out.displayName).toBe(email.split("@")[0]); // unchanged from getOrCreate
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/api && bun test test/user-sync.test.mts`
Expected: FAIL — `syncFromProvider` is not a function.

- [ ] **Step 3: Implement `syncFromProvider`**

In `apps/api/src/facades/user.facade.mts` add (import `isSocial` and `AuthSyncRequest`):
```ts
  public async syncFromProvider(identity: AuthIdentity, claims: AuthSyncRequest): Promise<User> {
    const user = await this.getOrCreate(identity);
    if (!isSocial(identity.userId)) return user; // db/bypass users manage their own identity
    const patch: Partial<User> = {};
    if (claims.displayName) patch.displayName = claims.displayName;
    if (claims.email) patch.email = claims.email;
    if (claims.avatarUrl) patch.avatarUrl = claims.avatarUrl;
    if (Object.keys(patch).length === 0) return user;
    const updated = await this.users.update(identity.userId, patch);
    return updated ?? user;
  }
```

- [ ] **Step 4: Add the route**

In `apps/api/src/routes/user.routes.mts` (import `AuthSyncRequest`), after the `PUT /users/me` route:
```ts
    .post(
      "/api/v1/auth/sync",
      async ({ identity, body }) => data(await userFacade.syncFromProvider(requireId(identity), body)),
      { requireAuth: true, body: AuthSyncRequest },
    )
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/api && bun test test/user-sync.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 6: Full suite + lint, then commit**

```bash
cd apps/api && bun test && bunx eslint src/facades/user.facade.mts src/routes/user.routes.mts
git add apps/api/src/facades/user.facade.mts apps/api/src/routes/user.routes.mts apps/api/test/user-sync.test.mts
git commit -m "feat(api): POST /auth/sync applies provider identity for social users"
```

---

### Task 4: Mobile — UserProfile birthday + isSocial + login sync

**Files:**
- Modify: `apps/mobile/lib/core/auth/auth_service.dart`
- Modify: `apps/mobile/lib/core/api/endpoints.dart` (add `authSync`)
- Test: `apps/mobile/test/user_profile_test.dart`

**Interfaces:**
- Produces: `UserProfile.birthday: String?`; `UserProfile.isSocial: bool`; `AuthStateNotifier.syncProfile({String? displayName, String? email, String? avatarUrl})`.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/user_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';

void main() {
  UserProfile p(String id, {String? auth0Id, String? birthday}) => UserProfile(
        id: id, auth0Id: auth0Id, email: 'x@y.io', displayName: 'X', birthday: birthday,
      );

  test('isSocial from provider subject', () {
    expect(p('google-oauth2|1', auth0Id: 'google-oauth2|1').isSocial, true);
    expect(p('auth0|1', auth0Id: 'auth0|1').isSocial, false);
    expect(p('test-user@local.priv').isSocial, false);
  });

  test('birthday round-trips through json', () {
    final u = UserProfile.fromJson({'id': 'a', 'email': 'x@y.io', 'displayName': 'X', 'birthday': '1990-01-05'});
    expect(u.birthday, '1990-01-05');
    expect(u.toJson()['birthday'], '1990-01-05');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/user_profile_test.dart`
Expected: FAIL — `birthday` param/`isSocial` getter missing.

- [ ] **Step 3: Add `birthday` + `isSocial` to `UserProfile`**

In `apps/mobile/lib/core/auth/auth_service.dart`, add the field (near `homeGymId`), constructor param, `fromJson`, `toJson`, and the getter:
```dart
  final String? birthday; // ISO YYYY-MM-DD
  // ...in constructor:
    this.birthday,
  // ...in fromJson:
      birthday: json['birthday'] as String?,
  // ...in toJson map:
    'birthday': birthday,
  // add getter on the class:
  bool get isSocial {
    final sub = auth0Id ?? id;
    return sub.contains('|') && !sub.startsWith('auth0|');
  }
```

- [ ] **Step 4: Add the sync endpoint constant**

In `apps/mobile/lib/core/api/endpoints.dart`:
```dart
  static const String authSync = '/api/v1/auth/sync';
```

- [ ] **Step 5: Add `syncProfile` to the notifier and call it on social login**

In `AuthStateNotifier` add:
```dart
  Future<void> syncProfile({String? displayName, String? email, String? avatarUrl}) async {
    final updated = await _authService.syncProfile(displayName: displayName, email: email, avatarUrl: avatarUrl);
    if (updated != null) state = state.copyWith(user: updated);
  }
```
In `AuthService` add (mirrors `updateProfile`, POSTs to `Endpoints.authSync`):
```dart
  Future<UserProfile?> syncProfile({String? displayName, String? email, String? avatarUrl}) async {
    final res = await apiClient.post(Endpoints.authSync, data: {
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    final body = res.data as Map<String, dynamic>;
    return body['data'] == null ? null : UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }
```
In `_socialLogin`, after a successful native login capture the provider profile and sync before/with `getOrCreateProfile`:
```dart
      final credentials = await _authService.login(connection);
      if (kIsWeb) return;
      if (credentials != null) {
        final pu = credentials.user; // auth0_flutter UserProfile
        await _authService.syncProfile(displayName: pu.name, email: pu.email, avatarUrl: pu.pictureUrl?.toString());
        final user = await _authService.getOrCreateProfile();
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: 'Login cancelled');
      }
```
(If `apiClient.post` doesn't exist, use the same Dio accessor `updateProfile` uses — open `AuthService.updateProfile` and mirror its HTTP call, swapping PUT `/users/me` for POST `Endpoints.authSync`.)

- [ ] **Step 6: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/user_profile_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/core/auth/auth_service.dart lib/core/api/endpoints.dart
git add apps/mobile/lib/core/auth/auth_service.dart apps/mobile/lib/core/api/endpoints.dart apps/mobile/test/user_profile_test.dart
git commit -m "feat(mobile): UserProfile birthday/isSocial and provider sync on login"
```

---

### Task 5: Mobile — home-gym picker + gym lookup providers

**Files:**
- Create: `apps/mobile/lib/features/profile/widgets/home_gym_picker.dart`
- Modify: `apps/mobile/lib/features/gyms/data/gym_repository.dart` (add providers if absent)
- Test: none (UI widget; covered by Task 9 on-simulator verification)

**Interfaces:**
- Consumes: `GymRepository.searchAll(String query)`, `GymRepository.getById(String id)` (both exist).
- Produces: `showHomeGymPicker(BuildContext, WidgetRef) -> Future<Gym?>`; `gymByIdProvider(String id)` (FutureProvider.family resolving a gym name).

- [ ] **Step 1: Add a gym-by-id provider**

In `apps/mobile/lib/features/gyms/data/gym_repository.dart` (bottom), add:
```dart
final gymByIdProvider = FutureProvider.family<Gym, String>((ref, id) {
  return ref.read(gymRepositoryProvider).getById(id);
});
```
(Confirm `gymRepositoryProvider` exists in this file; it is used by `ownerStatsProvider`.)

- [ ] **Step 2: Build the picker**

```dart
// apps/mobile/lib/features/profile/widgets/home_gym_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../../shared/models/gym.dart'; // adjust import to the Gym model's actual path

/// Modal searchable gym list. Returns the picked Gym, or null if dismissed.
Future<Gym?> showHomeGymPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Gym>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HomeGymPickerSheet(),
  );
}

class _HomeGymPickerSheet extends ConsumerStatefulWidget {
  const _HomeGymPickerSheet();
  @override
  ConsumerState<_HomeGymPickerSheet> createState() => _HomeGymPickerSheetState();
}

class _HomeGymPickerSheetState extends ConsumerState<_HomeGymPickerSheet> {
  String _q = '';
  List<Gym> _results = const [];
  bool _loading = false;

  Future<void> _search(String q) async {
    setState(() { _q = q; _loading = true; });
    final gyms = await ref.read(gymRepositoryProvider).searchAll(q);
    if (mounted) setState(() { _results = gyms; _loading = false; });
  }

  @override
  void initState() { super.initState(); _search(''); }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(hintText: 'Search gyms', filled: true, fillColor: t.surfaceHi, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_results[i].name, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).pop(_results[i]),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
```
(Open the `Gym` model to confirm the import path and that it exposes `.name` and `.id`; adjust the import line accordingly.)

- [ ] **Step 3: Analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/profile/widgets/home_gym_picker.dart lib/features/gyms/data/gym_repository.dart
git add apps/mobile/lib/features/profile/widgets/home_gym_picker.dart apps/mobile/lib/features/gyms/data/gym_repository.dart
git commit -m "feat(mobile): searchable home-gym picker and gym-by-id provider"
```

---

### Task 6: Mobile — permission-scoped edit screen

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/edit_profile_screen.dart`
- Test: none (covered by Task 9 on-simulator verification)

**Interfaces:**
- Consumes: `UserProfile.isSocial`, `UserProfile.birthday` (Task 4); `showHomeGymPicker` + `gymByIdProvider` (Task 5); `authStateProvider.notifier.updateProfile(Map)` (exists).

- [ ] **Step 1: Gate the field set by `isSocial`**

Rebuild `edit_profile_screen.dart` so it reads `final social = ref.read(authStateProvider).user?.isSocial ?? false;` in `initState`/`build`. Always render: **belt selector** (rank ChoiceChips + a stripes selector 0–4), **birthday** (a row that opens `showDatePicker` and stores the ISO string), and **home gym** (a row that opens `showHomeGymPicker`; display the resolved name via `ref.watch(gymByIdProvider(id))`). Only when `!social`, additionally render the Display Name, Bio, and weight fields that exist today.

- [ ] **Step 2: Birthday picker code**

```dart
DateTime? _birthday; // parsed from user.birthday
// ...
Future<void> _pickBirthday() async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: _birthday ?? DateTime(now.year - 25, 1, 1),
    firstDate: DateTime(now.year - 100),
    lastDate: now,
  );
  if (picked != null) setState(() => _birthday = picked);
}
String? get _birthdayIso => _birthday == null
    ? null
    : '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';
```

- [ ] **Step 3: Save only the permitted fields**

```dart
Future<void> _save() async {
  setState(() => _isSaving = true);
  final social = ref.read(authStateProvider).user?.isSocial ?? false;
  final updates = <String, dynamic>{
    'beltRank': _selectedBelt,
    'beltStripes': _selectedStripes,
    if (_birthdayIso != null) 'birthday': _birthdayIso,
    if (_homeGymId != null) 'homeGymId': _homeGymId,
    if (!social) 'displayName': _nameController.text.trim(),
    if (!social) 'bio': _bioController.text.trim(),
  };
  await ref.read(authStateProvider.notifier).updateProfile(updates);
  if (mounted) { setState(() => _isSaving = false); Navigator.of(context).maybePop(); }
}
```
(The server also strips disallowed fields for social users — this client gate is the UX layer.)

- [ ] **Step 4: Analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/features/profile/screens/edit_profile_screen.dart
git add apps/mobile/lib/features/profile/screens/edit_profile_screen.dart
git commit -m "feat(mobile): permission-scoped profile edit (social users limited to birthday/belt/home-gym)"
```

---

### Task 7: Mobile — Profile screen glass rebuild + real stats

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart`
- Create: `apps/mobile/lib/features/profile/data/profile_stats.dart`
- Test: `apps/mobile/test/profile_stats_test.dart`

**Interfaces:**
- Produces: `computeProfileStats(List<CheckIn>) -> ({int checkIns, int reviews, int gyms})`; `myStatsProvider` (FutureProvider). `ageFromBirthday(String iso, {DateTime? now}) -> int?`.
- Consumes: `Endpoints.myCheckins`; `CheckIn` model (`checkedInAt`, `rating`, `gymId`); `gymByIdProvider` (Task 5).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/profile_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/profile/data/profile_stats.dart';
import 'package:bjj_open_mat/features/checkins/models/checkin.dart';

void main() {
  test('computeProfileStats counts check-ins, reviews, distinct gyms', () {
    final list = [
      CheckIn.fromJson({'id': '1', 'checkedInAt': '2026-07-01', 'gymId': 'g1', 'rating': 5}),
      CheckIn.fromJson({'id': '2', 'checkedInAt': '2026-07-02', 'gymId': 'g1'}),
      CheckIn.fromJson({'id': '3', 'checkedInAt': '2026-07-03', 'gymId': 'g2', 'rating': 4}),
    ];
    final s = computeProfileStats(list);
    expect(s.checkIns, 3);
    expect(s.reviews, 2);
    expect(s.gyms, 2);
  });

  test('ageFromBirthday computes years', () {
    expect(ageFromBirthday('1990-01-05', now: DateTime(2026, 7, 6)), 36);
    expect(ageFromBirthday('2000-12-31', now: DateTime(2026, 7, 6)), 25);
    expect(ageFromBirthday('bad'), null);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/profile_stats_test.dart`
Expected: FAIL — `profile_stats.dart` missing.

- [ ] **Step 3: Implement stats + age helpers + provider**

```dart
// apps/mobile/lib/features/profile/data/profile_stats.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../checkins/models/checkin.dart';

typedef ProfileStats = ({int checkIns, int reviews, int gyms});

ProfileStats computeProfileStats(List<CheckIn> checkins) {
  final gyms = <String>{};
  var reviews = 0;
  for (final c in checkins) {
    if (c.gymId != null && c.gymId!.isNotEmpty) gyms.add(c.gymId!);
    if (c.rating != null) reviews += 1;
  }
  return (checkIns: checkins.length, reviews: reviews, gyms: gyms.length);
}

int? ageFromBirthday(String iso, {DateTime? now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final ref = now ?? DateTime.now();
  var age = ref.year - d.year;
  if (ref.month < d.month || (ref.month == d.month && ref.day < d.day)) age -= 1;
  return age < 0 ? null : age;
}

final myStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.myCheckins);
  final items = unwrapList(res.data as Map<String, dynamic>).items;
  final checkins = items.map((j) => CheckIn.fromJson(j)).toList();
  return computeProfileStats(checkins);
});
```
(Confirm `unwrapList` and `apiClientProvider.dio` exist — they are used in `owner_dashboard_screen.dart`. Confirm `CheckIn.fromJson` takes `Map<String, dynamic>`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/profile_stats_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Rebuild the Profile screen (glass)**

In `profile_screen.dart` `_GlassProfile`: replace the hardcoded stat row with `ref.watch(myStatsProvider)` values labelled **Check-ins / Reviews / Gyms** (show `--` while loading). Add an identity block: avatar (`user.avatarUrl` via `NetworkImage` else belt-colored initial), `user.displayName`, `user.email`, belt via `BeltIcon(rank: user.beltRank ?? 'white', stripes: user.beltStripes ?? 0, size: 44)`. Add metadata rows: **Age** (`ageFromBirthday(user.birthday!)` when set, else "Add birthday"), **Home gym** (`ref.watch(gymByIdProvider(user.homeGymId!)).maybeWhen(data: (g) => g.name, orElse: () => '—')` when set, else "Set home gym"), **Member since** (format `user.createdAt`). Keep the existing settings section / role toggle and the "Edit profile" entry (Account row → `/profile/edit`).

- [ ] **Step 6: Analyze, run mobile tests, commit**

```bash
cd apps/mobile && flutter analyze lib/features/profile && flutter test test/profile_stats_test.dart
git add apps/mobile/lib/features/profile/screens/profile_screen.dart apps/mobile/lib/features/profile/data/profile_stats.dart apps/mobile/test/profile_stats_test.dart
git commit -m "feat(mobile): glass profile with real metadata, age, home gym, and real stats"
```

---

### Task 8: Mobile — Home nav resets its branch

**Files:**
- Modify: `apps/mobile/lib/app/router.dart:263-266` (the `AppBottomNav` wiring in `_ScaffoldWithNavBar`)

**Interfaces:**
- Consumes: `StatefulNavigationShell.goBranch(int, {bool initialLocation})`; `kPracTabs`.

- [ ] **Step 1: Reset the branch when the active tab is re-tapped**

In `_ScaffoldWithNavBar.build`, change the practitioner `AppBottomNav.onTap` so tapping the currently-active tab resets its branch to root (this makes Home return to the discover landing from any nested route):
```dart
            onTap: (tabId) {
              final idx = kPracTabs.indexOf(tabId);
              shell.goBranch(idx, initialLocation: idx == shell.currentIndex);
            },
```

- [ ] **Step 2: Analyze + commit**

```bash
cd apps/mobile && flutter analyze lib/app/router.dart
git add apps/mobile/lib/app/router.dart
git commit -m "feat(mobile): tapping the active Home tab resets the discover feed to its root"
```

---

### Task 9: End-to-end verification on the iOS simulator

**Files:** none (verification only)

- [ ] **Step 1:** Ensure the local API (`:3100`) + its DB are up; run the app with DEV_BYPASS (dev-bypass user is non-social → full edit).
- [ ] **Step 2:** Profile tab shows real metadata (name/email/belt), Age from birthday once set, Home gym once set, and real stat tiles (Check-ins / Reviews / Gyms) — no mock numbers.
- [ ] **Step 3:** Edit profile as the (non-social) bypass user: all fields present; set birthday via the date picker, pick a home gym, change belt → save → values persist on return.
- [ ] **Step 4:** Confirm the social path in code: a social user (`google-oauth2|…`) would see only birthday/belt/home-gym in the edit screen, and the API strips other fields (covered by Task 2/3 tests). Note this in the verification record since a live Google login isn't available in the simulator harness.
- [ ] **Step 5:** From an open-mat detail (nested route under Home), tap the **Home** tab → returns to the discover feed root. Screenshot the profile and the reset behavior.

## Self-Review

**Spec coverage:**
- Birthday field → Task 1 (contract), Task 2 (doc), Task 4 (mobile), Task 6/7 (UI). ✔
- Social identity read-only + provider sync → Task 3 (sync), Task 4 (login capture). ✔
- Restricted edit set enforced server + client → Task 2 (server strip), Task 6 (client gate). ✔
- Provider classification `isSocial` → Task 2 (API), Task 4 (mobile). ✔
- Profile all-metadata + real stats (drop Hours) → Task 7. ✔
- Home gym selector → Task 5, consumed in Task 6/7. ✔
- Home nav resets discover branch → Task 8. ✔
- Testing (birthday round-trip, isSocial, restricted edits, stats, age) → Tasks 1–4, 7 + Task 9 sim. ✔

**Placeholder scan:** No TBD/TODO. Steps that touch existing files whose exact line contents can't be shown verbatim (edit screen rebuild, profile rebuild) name the exact symbols/providers to use and the shape of the change; the implementer reads the file first. Import paths flagged for confirmation are called out explicitly (Gym model path, `apiClient.post`).

**Type consistency:** `isSocial(sub)` identical in API (`is-social.mts`) and mobile (`UserProfile.isSocial`). `updateProfile(id, patch, isSocialUser)` signature used consistently in Task 2 route + tests. `ProfileStats = ({int checkIns, int reviews, int gyms})` consistent between helper, test, and provider. `AuthSyncRequest` fields (`displayName/email/avatarUrl`) consistent across Tasks 1, 3, 4.
