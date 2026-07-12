# BJJ Open Mat

> **Find a BJJ open mat anywhere, see who's going, and tap "I'm going."**

BJJ Open Mat is the fastest way to find a place to roll — near you or in any city you're
traveling to. Open the app and it instantly maps open mats around you, filtered by **gi/no-gi,
distance, skill level, and when you want to train**. See **who's coming**, RSVP with "I'm going,"
and **check in** when you arrive. It's community-driven: anyone can add a mat, and gyms verify
their own sessions. Built by a grappler, for grapplers. Free.

**Highlights**
- 🔎 Discover/search open mats by **GPS, city, or ZIP** (up to 100 miles)
- 🥋 Filter by **Gi / No-Gi**, free sessions, skill level, and day/time
- 👥 **"I'm going"** RSVPs + arrival **check-ins** with a training log — see attendees + belt rank
- 🏋️ **Gym profiles** with logos; owners post/verify sessions and see expected vs. actual attendance
- 🌍 The killer use case: **train anywhere you travel**

_Status: **beta** (iOS via TestFlight, Android via Play internal testing)._
Marketing & go-to-market: [`docs/marketing/`](docs/marketing/) · Full pitch: [`docs/marketing/elevator-pitch.md`](docs/marketing/elevator-pitch.md)

---

## Monorepo

Bun-workspace + Turborepo monorepo for the BJJ Open Mat Finder.

```
apps/
  api/        @bjj/api      — Bun + Elysia backend (TypeBox-validated)
  mobile/     Flutter app   — Dart (orchestrated by Turbo; not a Bun package)
packages/
  contract/   @bjj/contract — TypeBox schemas, the cross-language source of truth
docs/         architecture decisions, API contract, feature specs
```

## Prerequisites
- [Bun](https://bun.sh) ≥ 1.3
- [Flutter](https://flutter.dev) 3.x (for `apps/mobile`)

## Common commands (run from repo root)

```bash
bun install            # install all TS workspace deps
docker compose up -d   # start local MongoDB 7 (or set MONGODB_URI to Atlas)
bun run type-check     # tsc --noEmit across @bjj/contract + @bjj/api (Turbo)
bun run test           # bun test across TS packages (incl. MongoDB-backed boot test)
bun run verify         # type-check + lint + test (the finish gate)
bun run --filter @bjj/api seed   # load seed fixtures into MongoDB (idempotent)
bun run api:dev        # run the API with --watch (http://localhost:3100)
bun run mobile:run     # flutter run (apps/mobile)
bun run mobile:build   # flutter build web
```

> Copy `.env.example` → `apps/api/.env` before running the API/seed. The `bun run test` suite and `seed` require MongoDB running (`docker compose up -d`).

## Health
- API liveness: `GET /health` · readiness: `GET /ready` (pings MongoDB) · spec: `GET /openapi.json`

## Auth
- Bearer JWT (Auth0). For local dev / Postman, send the bypass token as the Bearer value:
  `Authorization: Bearer TopFlightApiSecurity2026+` (configurable via `AUTH_BYPASS_SECRET`).
- Postman collection + environment: `docs/postman/` (the bearer token is pre-wired).

See [`docs/decisions/2026-06-17-monorepo-architecture.md`](docs/decisions/2026-06-17-monorepo-architecture.md).
