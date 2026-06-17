# Monorepo Architecture Decision

**Date:** 2026-06-17
**Status:** Accepted & scaffolded

## Context

The project began as a standalone Flutter app (`bjj-open-mat`). It needs a backend API (Open Mat detail, RSVP/attendance, gym directions). Rather than a separate repo, we consolidate into a **Bun-workspace + Turborepo monorepo**, restructured in place to preserve git history.

## Decision

```
bjj-open-mat/                 # monorepo root (this repo, history preserved)
├─ apps/
│  ├─ api/                    # Bun + Elysia backend  (@bjj/api)
│  └─ mobile/                 # Flutter app (Dart) — Turbo task target, not a Bun pkg
├─ packages/
│  └─ contract/               # @bjj/contract — TypeBox schemas = source of truth
├─ docs/                      # monorepo-wide docs (this file, API contract, specs)
├─ package.json               # workspaces: ["apps/*","packages/*"], packageManager: bun
├─ turbo.json                 # task pipeline (build/type-check/lint/test/dev)
└─ bun.lock
```

### Key constraint: Flutter is not a Bun workspace package

Dart/Flutter can't be a Bun workspace member or import TS. `apps/mobile` lives in the
repo as a directory Turbo *orchestrates* via root scripts (`mobile:run`, `mobile:build`),
while `pub` manages its deps independently. `apps/mobile` deliberately has **no
`package.json`**, so Turbo's TS pipeline (`type-check`, `test`, etc.) only scopes
`@bjj/api` and `@bjj/contract`.

### Cross-language contract bridge

The Dart↔TS type-sharing gap is bridged by **`packages/contract`**:
- TypeBox schemas (`@sinclair/typebox`) define every request/response shape once.
- `@bjj/api` (Elysia) consumes them and serves `GET /openapi.json` (the schemas are valid JSON Schema).
- The Flutter app's Dart models are hand-mirrored from — and verified against — that OpenAPI document. (Codegen via `openapi-generator`/`swagger_parser` is a later option.)

## Tooling choices

| Choice | Decision | Why |
|---|---|---|
| Package manager | **Bun** (`bun@1.3.12`) | Project standard; runs `.mts` directly, no build step for TS packages. |
| Task runner | **Turborepo** | Caches/orchestrates the TS task graph; future-proofs as packages grow. |
| API framework | **Elysia** | Project standard; TypeBox-native validation, fast on Bun. |
| Validation | **TypeBox** (not Zod) | Project standard; one schema → runtime validation + JSON Schema + TS types. |
| Logging | **Winston** | Project standard; no `console.log`. |

## TypeScript conventions in this repo

- `.mts` source; `module: Preserve`, `moduleResolution: bundler`, `noEmit: true`, `strict: true`, `verbatimModuleSyntax: true`.
- Internal imports use explicit `.mts` specifiers (Bun resolves them directly; `allowImportingTsExtensions` keeps `tsc` happy). **Note:** if the API ever targets a Node emit build, switch internal specifiers to `.mjs` per the global standard.
- Layering: **Router → Service → Repository**, wired through a DI composition root (`apps/api/src/container.mts`). No `new` inside services/routes.
- Health endpoints: **`/health`** (liveness) + **`/ready`** (readiness). Never `/healthz`. (The legacy Flutter `endpoints.dart` still references `/healthz` — fix when wiring the app to the real API.)

## Verification gates (met at scaffold time)

- `cd apps/api && bun test` — socket-bound boot test: `/health`, `/ready`, `/openapi.json`, `/api/v1/open-mats`, detail, 404, and RSVP all return expected status over a real port.
- `bun run type-check` (Turbo) — strict `tsc --noEmit` passes for `@bjj/contract` and `@bjj/api`.
- `cd apps/mobile && flutter analyze` — clean from the new location.

## Migration notes

- The entire prior Flutter tree moved to `apps/mobile/` (history preserved via rename). Its `.gitignore`, `docs/`, `.docs/`, `e2e/` moved with it.
- Root gained `package.json`, `turbo.json`, `.gitignore`, `apps/api`, `packages/contract`, `docs/`.
- Generated artifacts (`build/`, `.dart_tool/`) were dropped and regenerate under `apps/mobile`.

## Next steps

1. Replace the API's in-memory seed (`apps/api/src/data/seed.mts`) with a real datastore + auth middleware.
2. Wire the Flutter Open Mat detail + finder to the API (see the feature design spec); the seed API already satisfies the contract, so this can start immediately.
3. Add ESLint to the TS packages (currently stubbed `lint` scripts).
