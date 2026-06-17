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
bun run type-check     # tsc --noEmit across @bjj/contract + @bjj/api (Turbo)
bun run test           # bun test across TS packages (incl. API boot test)
bun run api:dev        # run the API with --watch (http://localhost:3100)
bun run mobile:run     # flutter run (apps/mobile)
bun run mobile:build   # flutter build web
```

## Health
- API liveness: `GET /health` · readiness: `GET /ready` · spec: `GET /openapi.json`

See [`docs/decisions/2026-06-17-monorepo-architecture.md`](docs/decisions/2026-06-17-monorepo-architecture.md).
