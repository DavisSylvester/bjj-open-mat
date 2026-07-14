import { type Static, Type as t } from "@sinclair/typebox";
import { GiType } from "../../enums/gi-type.mts";
import { OpenMatStatus } from "../../enums/open-mat-status.mts";
import { SkillLevel } from "../../enums/skill-level.mts";

export const NewGymInput = t.Object(
  {
    name: t.String({ minLength: 1 }),
    address: t.String({ minLength: 1 }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    postalCode: t.Optional(t.String()),
    country: t.Optional(t.String()),
    latitude: t.Optional(t.Number({ minimum: -90, maximum: 90 })),
    longitude: t.Optional(t.Number({ minimum: -180, maximum: 180 })),
  },
  { $id: "NewGymInput" },
);
export type NewGymInput = Static<typeof NewGymInput>;

export const CreateOpenMatRequest = t.Object(
  {
    gymId: t.Optional(t.String()),
    newGym: t.Optional(NewGymInput),
    hostId: t.Optional(t.String()),
    title: t.String({ minLength: 1 }),
    description: t.Optional(t.String()),
    dayOfWeek: t.Optional(t.Integer({ minimum: 0, maximum: 6 })),
    startTime: t.String(),
    endTime: t.String(),
    isRecurring: t.Optional(t.Boolean()),
    specificDate: t.Optional(t.String()),
    maxParticipants: t.Optional(t.Integer({ minimum: 0 })),
    skillLevel: t.Optional(SkillLevel),
    giType: t.Optional(GiType),
    feeCents: t.Optional(t.Integer({ minimum: 0 })),
  },
  { $id: "CreateOpenMatRequest" },
);
export type CreateOpenMatRequest = Static<typeof CreateOpenMatRequest>;

export const UpdateOpenMatRequest = t.Partial(t.Omit(CreateOpenMatRequest, ["newGym"]), { $id: "UpdateOpenMatRequest" });
export type UpdateOpenMatRequest = Static<typeof UpdateOpenMatRequest>;

export const OpenMatListQuery = t.Object(
  {
    dayOfWeek: t.Optional(t.Number({ minimum: 0, maximum: 6 })),
    giType: t.Optional(GiType),
    skillLevel: t.Optional(SkillLevel),
    mine: t.Optional(t.Boolean({ description: "sessions at gyms the caller owns" })),
    gymId: t.Optional(t.String({ description: "sessions at a specific gym" })),
    page: t.Optional(t.Number({ minimum: 1, default: 1 })),
    limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })),
    status: t.Optional(OpenMatStatus),
    verified: t.Optional(t.Boolean()),
    submittedByMe: t.Optional(t.Boolean({ description: "sessions the caller submitted (hostId)" })),
    q: t.Optional(t.String({ description: "free-text: title + gymName" })),
    free: t.Optional(t.Boolean({ description: "feeCents 0 or absent" })),
    startDate: t.Optional(t.String({ description: "ISO date; When range start" })),
    endDate: t.Optional(t.String({ description: "ISO date; When range end" })),
    lat: t.Optional(t.Number({ minimum: -90, maximum: 90 })),
    lng: t.Optional(t.Number({ minimum: -180, maximum: 180 })),
    radiusKm: t.Optional(t.Number({ minimum: 1, maximum: 500 })),
    zip: t.Optional(t.String({ description: "geocoded to a point server-side" })),
    city: t.Optional(t.String({ description: "exact (case-insensitive) city match" })),
    state: t.Optional(t.String({ description: "exact (case-insensitive) state match" })),
  },
  { $id: "OpenMatListQuery" },
);
export type OpenMatListQuery = Static<typeof OpenMatListQuery>;

export const RsvpRequest = t.Object({ sessionDate: t.String() }, { $id: "RsvpRequest" });
export type RsvpRequest = Static<typeof RsvpRequest>;
