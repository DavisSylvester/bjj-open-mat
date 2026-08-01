# Admin Portal — Design

**Date:** 2026-08-01
**Status:** Approved (design)
**Phase:** I (no authentication)

## Summary

A new Angular 22 admin application at `apps/admin` that gives internal operators a
dashboard over the BJJ Open Mat data set: browse all users/gyms/members/open-mats,
see signup and open-mat KPIs, verify gyms, create/update core records, add gym
owners, and email new members to join a gym. It talks to a **new unauthenticated
`/api/v1/admin/*` router** in the existing Elysia API that reuses existing facades
and services wherever possible and adds a thin `AdminFacade` plus an
`AdminAnalyticsRepository` for KPI aggregations.

**Phase I explicitly has no auth.** The admin router is unauthenticated; the existing
role-guarded routes (`requireAuth`/`requireOwner`/`requireAdmin`) are left untouched.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Portal location | New workspace app `apps/admin` (Angular 22, signals, standalone). `apps/*` are Bun workspaces; the Angular app carries its own `package.json` and simply joins as a member. |
| API access | New `/api/v1/admin/*` endpoints, unauthenticated, reusing existing facades/services. Existing guarded routes unchanged. |
| Invite email | Reuse `email.service` with a real send (new `sendGymMemberInvite` method); record a lightweight invite. |
| KPIs | Real Mongo aggregation queries. |
| UI library | Nebular (Eva Design). No Angular Material. |
| E2E data | Seed a dedicated e2e Mongo database with known fixtures for deterministic assertions. |

## Architecture

```
apps/admin (Angular 22, Nebular)  ──HTTP──▶  /api/v1/admin/*  (Elysia, no auth)
                                                     │
                                                     ├─ AdminFacade  (new, thin orchestration)
                                                     ├─ AdminAnalyticsRepository (new, aggregations)
                                                     └─ reuses: gymFacade, userFacade,
                                                        openMatFacade, membershipFacade,
                                                        gymClaimFacade, leadFacade, email.service
```

- The admin router is a new Elysia module `admin.routes.mts`, registered in `app.mts`
  via `.use(adminRoutes(container))`. It does **not** apply the auth plugin macros in a
  guarding way (Phase I: open).
- New DI wiring in `container.mts`: `adminFacade`, `adminAnalyticsRepo`.

## Backend — endpoints (`/api/v1/admin`)

### KPIs (real aggregations)
- `GET /admin/stats/overview`
  - Signups in windows: **today, 3d, 7d, 14d, month-to-date, YTD** (from `users.createdAt`).
  - Totals: total users, total gyms, total open mats.
- `GET /admin/stats/open-mats-by-state`
  - Total open mats + **top-10 states**. State lives on the **gym**, not the open mat, so
    this aggregates `open-mats` → `$lookup` into `gyms` → group by `gym.state` → sort desc → limit 10.

### Lists (grids)
- `GET /admin/users` — **net-new** (existing user routes expose only `getById`). Needs a
  `UserRepository.list({ skip, limit })` + facade method. Paged via the shared `list()` envelope.
- `GET /admin/gyms` — reuse `gymFacade.list` (drop the `mine` owner filter).
- `GET /admin/open-mats` — reuse open-mat list facade.
- `GET /admin/memberships` — reuse membership facade list.
- `GET /admin/gym-claims` — reuse gym-claim facade list (supports the verify workflow context).

### Actions
- `POST /admin/gyms/:id/verify` — set `gym.isVerified = true` (+ optional `verifiedAt`).
- `POST /admin/gyms` — create a gym (reuse `gymFacade.create`; admin may supply an owner or none).
- `PUT  /admin/gyms/:id` — update gym (reuse `gymFacade.update`).
- `PUT  /admin/open-mats/:id` — update open mat.
- `PATCH /admin/memberships/:id` — update a member/membership.
- `PUT  /admin/gyms/:id/schedule` (classes) — update a gym's class schedule.
- `POST /admin/gyms/:id/owner` — **Add a Gym Owner**: set `gym.ownerId` **and** promote that
  user's `role` to `gym_owner`.
- `POST /admin/gyms/:id/invite` — **email new members**: real send via
  `email.service.sendGymMemberInvite(to, gymName, joinCode)` + record an invite.

### Data-model updates (additive, no destructive migration)
- `EmailService.sendGymMemberInvite(to: string, gymName: string, joinCode?: string): Promise<void>`
  implemented on both `SesEmailService` and `UnconfiguredEmailService`.
- Optional `verifiedAt?: string` on the `Gym` TypeBox schema (`packages/contract`).
- A lightweight invite record (new `gym-invite` collection **or** reuse the existing lead
  collection) to log who was invited to which gym and when.
- New request/response TypeBox schemas in `packages/contract` for admin stats and admin
  create/update/owner/invite payloads (schema-first; derive types with `Static`).

## Frontend — `apps/admin` (Angular 22 + Nebular)

- Nebular layout shell: sidebar navigation + header. Standalone components only.
- Signal-based state: one injectable data service per resource (users, gyms, open-mats,
  members, stats), reading from `environment.apiBaseUrl`. Explicit return types, strict mode,
  no `any`.
- Pages:
  - **Dashboard** — KPI cards for the 6 signup windows + totals; a top-10-states table.
  - **Users** — data grid.
  - **Gyms** — grid + actions: Verify, Create Gym, Edit, Add Owner, Send Invite.
  - **Open Mats** — grid + edit.
  - **Members / Memberships** — grid + edit.
  - **Gym Schedules** — edit a gym's classes.
- Scaffolded via the `angular-scaffold-agent`; themed via `angular-dashboard-styler` (Nebular).
- **No auth in Phase I.**

## E2E — dedicated seed DB

- A seed script loads known user + gym fixtures into a dedicated e2e Mongo database.
- Playwright config boots the API against the e2e DB and serves the admin app.
- Tests assert the **Users grid** and the **Gyms grid** render rows (non-empty), with
  deterministic expectations from the fixtures.
- **Gate: all e2e tests must pass.**

## Build sequence

1. Backend: contract schemas → `AdminAnalyticsRepository` + `UserRepository.list` →
   `AdminFacade` → `admin.routes.mts` → register + DI wire → API unit tests.
2. Frontend: scaffold `apps/admin` shell + services → grids/pages → Nebular styling.
3. E2E: seed fixtures + Playwright specs for the two grids; make them green.

## Reuse map (existing → admin)

| Admin need | Reuses |
|---|---|
| List gyms | `gymFacade.list` |
| Gym CRUD / verify | `gymFacade.create/update`, `gym.isVerified` |
| List/update open mats | `openMatFacade` |
| List/update memberships | `membershipFacade` |
| Gym claims context | `gymClaimFacade` |
| Send invite email | `email.service` (+ new method) |
| Record invite/lead | `leadFacade` / lead collection |
| User by id | `userFacade.getById` |
| **List users** | **new** `UserRepository.list` + facade method |
| **KPI aggregations** | **new** `AdminAnalyticsRepository` |

## Out of scope (Phase I)

- Authentication / authorization on the admin portal.
- Role-based UI gating.
- Audit trail beyond the minimal invite/verify timestamps.
