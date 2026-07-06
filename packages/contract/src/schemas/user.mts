import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { UserRole } from "../enums/user-role.mts";
import { Gender } from "../enums/gender.mts";
import { WeightDivision } from "../enums/weight-division.mts";

export const UserSettings = t.Object(
  {
    theme: t.Union([t.Literal("sport"), t.Literal("glass")], { default: "glass" }),
    notifyRsvp: t.Boolean({ default: true }),
    notifySessionUpdates: t.Boolean({ default: true }),
  },
  { $id: "UserSettings" },
);
export type UserSettings = Static<typeof UserSettings>;

export const UserPreferences = t.Object(
  {
    defaultWhen: t.Optional(t.String()),
    defaultWithinMi: t.Optional(t.Number({ minimum: 1, maximum: 100 })),
    defaultGiType: t.Optional(t.String()),
  },
  { $id: "UserPreferences" },
);
export type UserPreferences = Static<typeof UserPreferences>;

export const User = t.Object(
  {
    id: t.String(),
    auth0Id: t.Optional(t.String()),
    email: t.String({ format: "email" }),
    displayName: t.String(),
    role: t.Optional(UserRole),
    beltRank: t.Optional(BeltRank),
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    weight: t.Optional(t.String()),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    gender: t.Optional(Gender),
    weightValue: t.Optional(t.Number()),
    weightUnit: t.Optional(t.Union([t.Literal("lb"), t.Literal("kg")])),
    weightDivision: t.Optional(WeightDivision),
    weightDivisionContext: t.Optional(t.Union([t.Literal("gi"), t.Literal("nogi")])),
    bio: t.Optional(t.String()),
    avatarUrl: t.Optional(t.String()),
    homeGymId: t.Optional(t.String()),
    birthday: t.Optional(t.String()), // ISO YYYY-MM-DD
    settings: t.Optional(UserSettings),
    preferences: t.Optional(UserPreferences),
    createdAt: t.Optional(t.String()),
  },
  { $id: "User" },
);
export type User = Static<typeof User>;
