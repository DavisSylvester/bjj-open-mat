# Admin API Authentication

**Date:** 2026-08-06
**Status:** Accepted — API guarded; portal login still outstanding

## Context

`/api/v1/admin/*` shipped to production with **no authentication at all**.

Every other route module applies the auth plugin inside itself, because Elysia
encapsulates a plugin's macros and `resolve` by default — a single top-level
`.use(authPlugin())` would not propagate them (see the comment in
`apps/api/src/app.mts`). `admin.routes.mts` was written without that line and
mounted bare at `app.mts:59`. Nothing failed, because nothing tested for it:
`admin-routes.test.mts` was titled `describe("admin routes (unauthenticated)")`
and asserted `200` for anonymous calls.

Confirmed against production on 2026-08-06:

```
GET https://api.bjj-open-mat.dsylvester.io/api/v1/admin/stats/overview -> 200
{"totalUsers":27,"totalGyms":846,"totalOpenMats":54,"signups":{…}}
```

No token. The same door exposed:

- **Read:** every user record, email addresses included (`GET /admin/users`).
- **Write:** membership status on any member of any gym, gym create/update,
  gym owner assignment, and open-mat update.
- **Outbound email:** `POST /admin/gyms/:id/invite` sends invitations.

## Decision

Guard the whole router once, at the instance level, rather than per route:

```ts
new Elysia({ prefix: "/api/v1/admin" })
  .use(authPlugin(container.verifier, container.roleLookup))
  .guard({ requireAdmin: true })
```

A route added later inherits the guard and cannot be published unprotected by
omission — the failure mode that caused this. The `requireAdmin` macro already
existed and was in use by `gym-claim.routes.mts`; only this router lacked it.

### Admin is a database role, not a token claim

`authPlugin` resolves identity, then overrides the token's role with
`roleLookup(userId)` — the `role` field on the user document. Two consequences:

- A real user only reaches these routes when their `users` record has
  `role: "admin"`. A valid login is not sufficient.
- The dev bypass secret cannot mint an admin on its own: `DEMO_USER_ROLE` is
  typed `"practitioner" | "gym_owner"` in `env.mts` and deliberately excludes
  `"admin"`. To use the bypass locally, point `DEMO_USER_ID` at a seeded user
  whose `role` is `"admin"`.

This is a deliberate property worth keeping: compromising the bypass secret
does not by itself grant admin.

### Portal access

The Angular admin portal sends no credential — it had no interceptor, because
the API needed none. It now attaches `Authorization: Bearer <devToken>` via
`apps/admin/src/app/core/api/auth.interceptor.ts`, scoped to
`environment.apiBaseUrl` so the token cannot leak to another host.

`devToken` is empty in `environment.ts` (production) and empty in git for
`environment.development.ts`; a developer fills in the local
`AUTH_BYPASS_SECRET` and does not commit it.

## Consequences

- **The portal cannot be deployed as-is.** A shipped build carries no token, so
  a hosted portal would 401 on every page. Deploying it requires real Auth0
  login in the Angular app — an SPA-type public client with PKCE, a token
  interceptor, and route guards. That work is deliberately not in this change.
- **An admin user must exist.** If no production user has `role: "admin"`, the
  admin surface is now closed to everyone, including its owner. Verify before
  relying on it.
- `admin-routes.test.mts` now pins the ladder: `401` unauthenticated across all
  13 routes, `403` for an authenticated practitioner, `200` for an admin. The
  regression cannot return silently.

## Alternatives rejected

- **Per-route `{ requireAdmin: true }`**, matching `gym-claim.routes.mts`. It is
  the established local style, but it reintroduces exactly the omission risk
  that caused the incident — thirteen chances to forget instead of zero.
- **Wiring Auth0 into the portal in the same change.** Correct end state, but it
  turns a same-day fix into a multi-day one while the write surface stays open.
