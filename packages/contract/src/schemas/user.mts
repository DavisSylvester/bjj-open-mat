import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../enums/belt-rank.mts";
import { UserRole } from "../enums/user-role.mts";

export const UserSettings = t.Object(
  {
    theme: t.Union([t.Literal("sport"), t.Literal("glass")], { default: "glass" }),
    notifyRsvp: t.Boolean({ default: true }),
    notifySessionUpdates: t.Boolean({ default: true }),
  },
  { $id: "UserSettings" },
);
export type UserSettings = Static<typeof UserSettings>;

export const User = t.Object(
  {
    id: t.String(),
    auth0Id: t.Optional(t.String()),
    email: t.String({ format: "email" }),
    displayName: t.String(),
    role: UserRole,
    beltRank: t.Optional(BeltRank),
    beltStripes: t.Optional(t.Integer({ minimum: 0, maximum: 4 })),
    weight: t.Optional(t.String()),
    bio: t.Optional(t.String()),
    avatarUrl: t.Optional(t.String()),
    homeGymId: t.Optional(t.String()),
    settings: t.Optional(UserSettings),
    createdAt: t.Optional(t.String()),
  },
  { $id: "User" },
);
export type User = Static<typeof User>;
