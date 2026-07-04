# BJJ Open Mat — Monorepo

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
