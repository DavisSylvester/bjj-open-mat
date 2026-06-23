# Open Mat Detail + RSVP — API Contract

**Date:** 2026-06-17
**Status:** Accepted. Executable reference implemented in `apps/api` against in-memory seed data.
**Source of truth:** `packages/contract/src/index.mts` (TypeBox). This doc is the human-readable summary; the schemas there are authoritative and emitted at `GET /openapi.json`.

## Purpose

Backend contract for the Flutter "Open Mat detail + Open Mat Finder" feature. The next backend session replaces the seed repository with a real datastore + auth, keeping these shapes.

## Base

- Base URL (dev): `http://localhost:3100`
- Versioned prefix: `/api/v1`
- Auth: Bearer JWT (existing pattern). RSVP/attendee identity comes from the authenticated user. The seed scaffold uses a fixed demo user (`u-me`) until auth is wired.

## Enumerations

- `BeltRank`: `white | blue | purple | brown | black`
- `SkillLevel`: `all | beginner | intermediate | advanced`

## Resources

### OpenMat (list item)
`id, gymId, hostId?, title, description?, dayOfWeek? (0=Sun…6=Sat), startTime ("HH:mm" 24h), endTime, isRecurring, specificDate? ("YYYY-MM-DD"), maxParticipants?, skillLevel, isGiSession, isCancelled, feeCents? (0/absent = free), attendeeCount?, gymName?, distanceKm?, createdAt?`

### OpenMatDetail (adds location for directions)
All of `OpenMat`, plus: `latitude, longitude, address, city, state, postalCode?, gymRating?`
> **New fields the backend must provide** beyond the current `OpenMat`: `latitude`, `longitude`, `address`, `city`, `state`, `postalCode?`, `feeCents?`, `attendeeCount?`. Directions deep-links are built client-side from `latitude/longitude` (+ `address` fallback), so detail must return them — no extra gym fetch.

### Attendee
`userId, name, beltRank, beltStripes? (0–4), skillLevel, avatarUrl?, rsvpAt (ISO timestamp)`

## Endpoints

| Method | Path | Purpose | Response |
|---|---|---|---|
| `GET` | `/api/v1/open-mats?dayOfWeek=&lat=&lng=&radiusKm=&page=&limit=` | List/finder. Filter by `dayOfWeek`; server sorts by `startTime` asc, client tiebreaks nearest-first. | `OpenMatListResponse { data: OpenMat[], count }` |
| `GET` | `/api/v1/open-mats/:id` | Detail incl. location. | `OpenMatDetail` · `404` if missing |
| `GET` | `/api/v1/open-mats/:id/attendees?sessionDate=YYYY-MM-DD` | RSVP'd attendees for an occurrence. | `AttendeesResponse { data: Attendee[], count }` |
| `POST` | `/api/v1/open-mats/:id/rsvp` body `{ sessionDate }` | Current user RSVPs to that occurrence (idempotent). | `RsvpResponse { ok: true, attendeeCount, attending: true }` |
| `DELETE` | `/api/v1/open-mats/:id/rsvp?sessionDate=` | Current user cancels RSVP. | `RsvpResponse { ok: true, attendeeCount, attending: false }` |
| `GET` | `/health` / `/ready` | Liveness / readiness. | `HealthResponse` / `ReadyResponse` |
| `GET` | `/openapi.json` | OpenAPI 3.1 doc (component schemas = the contract). | OpenAPI document |

## RSVP vs. Check-in (important)

These are **distinct** concepts and must not be conflated:
- **RSVP** (this contract): "I plan to attend this occurrence." Forward-looking, builds the shared attendee list ahead of the session. Endpoints above.
- **Check-in** (existing `/open-mats/:id/checkin`, `CheckIn` model): "I showed up." Post-session, unlocks the 48h review window. Unchanged.

A user may RSVP and later check in; the backend should keep both records.

## Backend implementation notes for next session

- Persist RSVPs keyed by `(openMatId, sessionDate, userId)`; idempotent insert; `attendeeCount` is the count for that occurrence.
- `attendees` joins user profile for `name`, `beltRank`, `beltStripes`, `skillLevel`, `avatarUrl`.
- Recurring sessions: `sessionDate` selects the occurrence; one-off sessions use `specificDate`.
- Replace `apps/api/src/data/seed.mts` + `OpenMatRepository` internals with the datastore; service/route layers stay as-is.
- Fix the health path: the Flutter `apps/mobile/lib/core/api/endpoints.dart` currently points at `/healthz` — change to `/health` (+ add `/ready`).

## Flutter consumption (next feature session)

Repository pattern (`OpenMatRepository` abstract → `ApiOpenMatRepository` / `MockOpenMatRepository`), selected by `--dart-define=USE_MOCK`. Providers: `openMatDetailProvider(id)`, `attendeesProvider((id, sessionDate))`, `rsvpControllerProvider`, `finderProvider(dayOfWeek)`, `currentLocationProvider` (geolocator). See the feature design spec.
