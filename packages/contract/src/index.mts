// @bjj/contract — single source of truth for the BJJ Open Mat API.
// Framework-agnostic TypeBox schemas + derived static types. The Elysia API
// consumes these for runtime validation + OpenAPI; the Flutter app's Dart
// models are generated/hand-mirrored from the emitted OpenAPI document.

import { type Static, Type as t } from "@sinclair/typebox";

// ── Enumerations ──────────────────────────────────────────────────────────
export const BeltRank = t.Union(
  [
    t.Literal("white"),
    t.Literal("blue"),
    t.Literal("purple"),
    t.Literal("brown"),
    t.Literal("black"),
  ],
  { $id: "BeltRank" },
);
export type BeltRank = Static<typeof BeltRank>;

export const SkillLevel = t.Union(
  [
    t.Literal("all"),
    t.Literal("beginner"),
    t.Literal("intermediate"),
    t.Literal("advanced"),
  ],
  { $id: "SkillLevel" },
);
export type SkillLevel = Static<typeof SkillLevel>;

// ── Open Mat (list item) ──────────────────────────────────────────────────
export const OpenMat = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    hostId: t.Optional(t.String()),
    title: t.String(),
    description: t.Optional(t.String()),
    // 0 = Sunday … 6 = Saturday. Null/absent for one-off sessions.
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String({ description: "24h HH:mm, e.g. 19:00" }),
    endTime: t.String({ description: "24h HH:mm, e.g. 21:00" }),
    isRecurring: t.Boolean({ default: true }),
    specificDate: t.Optional(t.String({ description: "ISO date YYYY-MM-DD for one-off sessions" })),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: SkillLevel,
    isGiSession: t.Boolean(),
    isCancelled: t.Boolean({ default: false }),
    feeCents: t.Optional(t.Integer({ minimum: 0, description: "Mat fee in cents; 0 or absent = free" })),
    attendeeCount: t.Optional(t.Integer({ minimum: 0 })),
    gymName: t.Optional(t.String()),
    distanceKm: t.Optional(t.Number({ minimum: 0 })),
    createdAt: t.Optional(t.String()),
  },
  { $id: "OpenMat" },
);
export type OpenMat = Static<typeof OpenMat>;

// ── Open Mat detail (adds location for directions) ────────────────────────
export const OpenMatDetail = t.Composite(
  [
    OpenMat,
    t.Object({
      latitude: t.Number(),
      longitude: t.Number(),
      address: t.String(),
      city: t.String(),
      state: t.String(),
      postalCode: t.Optional(t.String()),
      gymRating: t.Optional(t.Number({ minimum: 0, maximum: 5 })),
    }),
  ],
  { $id: "OpenMatDetail" },
);
export type OpenMatDetail = Static<typeof OpenMatDetail>;

// ── Attendee (RSVP'd practitioner) ────────────────────────────────────────
export const Attendee = t.Object(
  {
    userId: t.String(),
    name: t.String(),
    beltRank: BeltRank,
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    skillLevel: SkillLevel,
    avatarUrl: t.Optional(t.String({ format: "uri" })),
    rsvpAt: t.String({ description: "ISO timestamp the user RSVP'd" }),
  },
  { $id: "Attendee" },
);
export type Attendee = Static<typeof Attendee>;

export const AttendeesResponse = t.Object(
  {
    data: t.Array(Attendee),
    count: t.Integer({ minimum: 0 }),
  },
  { $id: "AttendeesResponse" },
);
export type AttendeesResponse = Static<typeof AttendeesResponse>;

// ── RSVP request / response ───────────────────────────────────────────────
// RSVP = "I plan to attend this occurrence." Distinct from check-in
// (post-session attendance that unlocks the 48h review window).
export const RsvpRequest = t.Object(
  {
    sessionDate: t.String({ description: "ISO date YYYY-MM-DD of the occurrence being attended" }),
  },
  { $id: "RsvpRequest" },
);
export type RsvpRequest = Static<typeof RsvpRequest>;

export const RsvpResponse = t.Object(
  {
    ok: t.Literal(true),
    attendeeCount: t.Integer({ minimum: 0 }),
    attending: t.Boolean({ description: "Current user's RSVP state after the operation" }),
  },
  { $id: "RsvpResponse" },
);
export type RsvpResponse = Static<typeof RsvpResponse>;

// ── List query / response ─────────────────────────────────────────────────
export const OpenMatListQuery = t.Object(
  {
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    lat: t.Optional(t.Number()),
    lng: t.Optional(t.Number()),
    radiusKm: t.Optional(t.Integer({ minimum: 1, maximum: 500, default: 25 })),
    page: t.Optional(t.Integer({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Integer({ minimum: 1, maximum: 100, default: 20 })),
  },
  { $id: "OpenMatListQuery" },
);
export type OpenMatListQuery = Static<typeof OpenMatListQuery>;

export const OpenMatListResponse = t.Object(
  {
    data: t.Array(OpenMat),
    count: t.Integer({ minimum: 0 }),
  },
  { $id: "OpenMatListResponse" },
);
export type OpenMatListResponse = Static<typeof OpenMatListResponse>;

// ── Health ────────────────────────────────────────────────────────────────
export const HealthResponse = t.Object(
  {
    status: t.Literal("ok"),
    uptimeSeconds: t.Number(),
  },
  { $id: "HealthResponse" },
);
export type HealthResponse = Static<typeof HealthResponse>;

export const ReadyResponse = t.Object(
  {
    status: t.Union([t.Literal("ready"), t.Literal("degraded")]),
    checks: t.Record(t.String(), t.Boolean()),
  },
  { $id: "ReadyResponse" },
);
export type ReadyResponse = Static<typeof ReadyResponse>;
