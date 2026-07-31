# BJJ Open Mat — Session Resume

**Session date:** 2026-07-29 → 2026-07-30
**App:** BJJ OPEN MAT (iOS, Apple ID `6787704999`, bundle `com.davissylvester.bjjopenmat`)
**Repo:** https://github.com/DavisSylvester/bjj-open-mat

This document records what happened, what is live, and what remains. It is written to be
read cold by someone with no memory of the session.

---

## 1. Where things stand right now

| | State |
|---|---|
| `main` | Pushed to origin at `d449191..4e916e6`, then further work merged |
| Unmerged branch | `feature/home-gym-membership-sync` — 6 commits, complete, reviewed, **not merged** |
| Flutter tests | **286 passing** on `main` |
| API tests | **268 passing** on the sync branch (253 on `main`) |
| API type-check | 4 pre-existing errors (`class-journal.routes.test.mts` ×1, `class.routes.test.mts` ×2, `forum.routes.test.mts` ×1) — untouched all session |
| **App Store** | **Still on 1.0.** None of this session's mobile work has reached a user. |

### The single most important fact

**Version 1.1 was never submitted.** Five features were built, reviewed, merged, and — for
the API half — deployed. The mobile half sits on `main` and reaches nobody until an App Store
build ships. This has been true since the first hour of the session and is now four features
deep.

---

## 2. What is live in production

Deployed via GitHub Actions (`API Deploy`), verified working against
`https://api.bjj-open-mat.dsylvester.io`:

- **Gym `id` fix.** `fromDoc` in `gym.repository.mts` destructured `_id` away and never
  mapped it to `id`. 842 of 847 gyms (99.4%) returned no `id`, making them unreachable by
  every id-keyed route. Fixed; all 847 now expose one.
- **`GET /api/v1/gyms/:id/review-link`** — returns a Google Maps "write a review" URI from
  Places API (New), cached on the gym document. Verified live: 318ms uncached → 149ms cached.
- **`GOOGLE_PLACES_API_KEY`** in AWS Secrets Manager (`bjj-open-mat/app`), synced by CI.
- **Generalised CI secret sync** — `api-deploy.yml` now patches any number of runtime keys in
  one read-modify-write, writing only non-empty values so an unconfigured GitHub secret can
  never blank an existing one.

---

## 3. What is on `main` but NOT in front of users

All mobile. Requires an App Store build.

### 1.1 fixes
- **Login screen no longer leaks raw `DioException` text.** A stale Keychain token (which
  survives app reinstall) made `checkAuth` call `/auth/me`, 401, and stringify the exception
  into the UI. Now clears dead credentials silently and self-heals.
- **`friendlyErrorMessage`** maps failures to general-but-descriptive text; applied at the
  login path and six admin screens.
- **Cancelling sign-in** (`USER_CANCELLED`) shows no error — it is a choice, not a failure.
- **Favorites entry point.** `FavoritesScreen` was routed but unreachable; users could
  favourite gyms and never see the list.
- **Join button** distinguishes signed-out ("Sign in to join") from roster-error ("Retry")
  instead of one silent grey dead button.
- **App Store rating prompt** after the third check-in, count read from server data.

### My Gym tab
Replaced the Report tab (Report moved to Profile settings with a back affordance). Hub shows
header, next-up class, quick actions, recent forum. Forum and Feedback tiles gated so they
cannot 403.

### Open Mats screen
Gym detail's inline list moved to `/gym/:id/open-mats`, reachable from a gym-detail row and an
ungated My Gym tile.

### Gym logo upload
Shared `GymLogoPicker` extracted; gym admin screen can now add a logo to an **existing** gym
(previously only possible at creation); dismissible banner prompts owners.

---

## 4. Unmerged work: `feature/home-gym-membership-sync`

Complete and reviewed. **Not merged, not pushed.**

**Problem it fixes:** "home gym" is written by two paths and only one kept a membership in
sync. Setting a home gym from the profile screen wrote `users.homeGymId` and nothing else, so
the gym's roster stayed empty.

**Commits:**
```
5616eb0 fix(api): type gymMemberships collection and enforce home-gym exclusivity in backfill
a1eae19 feat(api): add home-gym membership backfill script
2a7b841 feat(api): join the gym when a profile sets a home gym
fa4efb3 feat(api): add MembershipFacade.ensureHome
f2e7a58 docs: add home gym / membership sync implementation plan
9c5c404 docs: add home gym / membership sync design spec
```

**Behaviour:** setting a home gym now also joins that gym. The sync runs *before* the user
write, so an unknown gym rejects the whole update rather than leaving a profile pointing at a
gym the user was never joined to.

### ⚠️ Awaiting a human decision

The backfill script has **never been run with `--commit`**. Nothing has been written to
production. Dry run against production returned:

```
users with a home gym : 3
  to create           : 2
  already a member    : 0
  home gym missing    : 1   (test-user@local.priv -> gym-atos, stale seed data)
```

To apply, after merging:

```bash
cd apps/api
MONGODB_URI="$(grep '^MONGODB_URI=' .env | cut -d= -f2-)" \
MONGODB_DB="$(grep '^MONGODB_DB=' .env | cut -d= -f2-)" \
  bun run scripts/backfill-home-gym-memberships.mts --commit
```

---

## 5. Production data reality — read this before planning features

Measured directly against Atlas on 2026-07-30:

| | Count |
|---|---|
| Gyms | 847 |
| Gyms with an `ownerId` | **0** |
| Gyms with a `logoUrl` | **0** |
| Gym memberships | **0** |
| Users | 14 (4 with `gym_owner` role) |
| Users with `homeGymId` set | 3 |
| Open mats | 54 |
| Forum questions | 0 |
| Check-ins | 0 |

### What this means

**No gym has an owner, and nothing in the app can assign one.** Every owner-gated feature is
therefore decoration in production:

- Logo upload — banner gated on `isGymOwner && gym.ownerId == currentUserId`; unsatisfiable.
- Instructor feedback — `assertCanManageGym`; unreachable.
- Gym admin screen — router redirects non-`gym_owner` accounts away from `/owner/**`.
- Gym forum — `assertActiveMember`; with 0 memberships, only an admin can open one.

**A gym claim flow is the upstream blocker for most of what was built this session.** It is
not scoped, not designed, and needs a product decision (who may claim a gym, and how is it
verified?).

---

## 6. Future work

### Blocking the release
1. **Submit 1.1 to the App Store.** Create the version in App Store Connect, set
   **Secondary category → Health & Fitness** (primary stays Sports), `bun run mobile:ios`,
   upload, write "What's New", submit. `ios/Podfile.lock` is already committed.
2. **Manual simulator pass with a `gym_owner` account.** Three separate features shipped with
   *no* on-device visual verification because simulator UI automation kept failing and no
   `gym_owner` test account exists. The logo work's final review noted that one manual pass
   would have caught all four of its findings in under a minute.

### High value
3. **Gym ownership / claim flow** — see §5. Unblocks four features.
4. **Merge and push `feature/home-gym-membership-sync`**, then run the backfill with
   `--commit`.
5. **Duplicate gym records.** Two RM Elite rows exist: `518d6c86-5a21-4079-92d6-353a5be162d8`
   and `gpl-ChIJQ6RbfKRlTIYRqwLvhXoHGEE`. Likely scraper duplication; worth a dedupe pass
   across all 847.

### Known gaps, ruled ship-safe
6. **Add-session flow cannot be prefilled with a gym.** `CreateSessionScreen` takes no
   constructor arguments, so "Post an open mat" from a gym-scoped empty state makes the user
   re-pick the gym they were just looking at.
7. **Profile screen should say that setting a home gym joins the gym** — the semantic changed
   on the sync branch.
8. **My Gym hub grid** renders 2+2+1 with five tiles; never visually confirmed (test account
   sees only 3).
9. **Rating prompt** may fire one check-in late (cached `myStatsProvider`), and `logout()`'s
   `deleteAll()` wipes its once-only flag, so a logout/login cycle re-arms it.
10. **Gym admin back arrow** does `context.go('/owner/gyms')`, stranding a user who arrived
    from a gym detail page.
11. **`SessionRow` headlines every card with the gym name**, so on a gym-scoped screen every
    row reads identically; the open mat's own title is never shown.
12. **Logo banner flickers** while the dismissal read is in flight.

### Environment / hygiene
13. **`~/.aws/config`** was fixed this session (`region = a` → `us-east-1`). The `default`
    profile's session token is **expired**; the `dsylvesteriii` profile's access key returns
    `InvalidClientTokenId` and needs rotating. Not blocking — CI writes secrets via its own
    OIDC role.
14. **`apps/api/.env` points at production Atlas.** A duplicate `MONGODB_URI` line was removed
    this session; the surviving value is production, now annotated with a warning comment.
    Local runs — including the review-link endpoint's cache writes — hit production.
15. **Local Mongo container maps host port 27021**, not the 27017 declared in
    `docker-compose.yml`, and uses anonymous volumes rather than the named `bjj-mongo-data`.
16. **API tests are now isolated** from ambient `MONGODB_URI` via `apps/api/bunfig.toml` +
    `test/setup.mts`. Run them as
    `TEST_MONGODB_URI="mongodb://localhost:27021" bun test`.
17. **4 pre-existing type-check errors** in three route test files. Untouched all session.

---

## 7. Notable defects found by review, worth remembering

These were all caught by the review loop rather than by tests, and several originated in
plan/spec text rather than implementer error.

- **Gym `id` never mapped from `_id`** — 99.4% of gyms unreachable by id. Found by
  investigating why the Google review link returned null.
- **Logo banner gated on the wrong role.** `deriveCanManageGym` would have shown it to coaches
  the router bounces; `isGymOwner` alone would have shown it to owners of *other* gyms, who
  upload to S3 and then 403. Correct gate needs both account role and per-gym ownership.
- **`friendlyErrorMessage` bypassed** by `ApiException`, so six admin screens lost their real
  error messages — a regression introduced by the very fix meant to improve them.
- **Wrong provider invalidated** after a gym save (`gymDetailProvider` vs `gymByIdProvider`),
  so a saved logo never appeared and the banner kept nagging.
- **Backfill would have written unreadable rows** — `upsertJoin` stores `{ ...m, _id: m.id }`,
  so `_id` and `id` must be the same value; the draft generated two UUIDs.
- **String-containment tests hid two real bugs.** Asserting a source file merely *contains*
  `_uploadingLogo` passes with the guard fully inverted.
- **Riverpod 3 retries thrown `Exception`s but not `Error` subtypes** — an error-state test
  using `Exception` sits in `loading` and passes for the wrong reason. Use `StateError`.

---

## 8. Key file locations

| What | Where |
|---|---|
| Specs | `docs/superpowers/specs/2026-07-*.md` |
| Plans | `docs/superpowers/plans/2026-07-*.md` |
| Home gym resolver | `apps/mobile/lib/features/mygym/data/home_gym_provider.dart` |
| Gym permissions (shared gates) | `apps/mobile/lib/features/gyms/data/gym_permissions.dart` |
| Friendly errors | `apps/mobile/lib/core/api/friendly_error.dart` |
| Places client | `apps/api/src/services/places-client.mts` |
| Backfill script | `apps/api/scripts/backfill-home-gym-memberships.mts` |
| Test DB isolation | `apps/api/bunfig.toml`, `apps/api/test/setup.mts` |

## 9. Useful commands

```bash
# Mobile
cd apps/mobile && flutter analyze && flutter test
flutter run -d "iPhone 17 Pro" --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com

# API (tests are pinned to a local DB; container is on 27021)
cd apps/api && TEST_MONGODB_URI="mongodb://localhost:27021" bun test
cd apps/api && bun run type-check     # expect 4 pre-existing errors

# Boot check — a passing suite does not prove the DI container wires up
cd apps/api && MONGODB_URI="mongodb://localhost:27021" MONGODB_DB="bjj_bootcheck" \
  PORT=3199 bun src/index.mts &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3199/health
```
