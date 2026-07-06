import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { UserRole } from "../../enums/user-role.mts";
import { UserSettings, UserPreferences } from "../user.mts";
import { Gender } from "../../enums/gender.mts";
import { WeightDivision } from "../../enums/weight-division.mts";

export const UpdateUserRequest = t.Partial(
  t.Object({
    displayName: t.String(),
    role: UserRole,
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    weight: t.String(),
    city: t.String(),
    state: t.String(),
    gender: Gender,
    weightValue: t.Number(),
    weightUnit: t.Union([t.Literal("lb"), t.Literal("kg")]),
    weightDivision: WeightDivision,
    weightDivisionContext: t.Union([t.Literal("gi"), t.Literal("nogi")]),
    bio: t.String(),
    avatarUrl: t.String(),
    homeGymId: t.String(),
    preferences: UserPreferences,
  }),
  { $id: "UpdateUserRequest" },
);
export type UpdateUserRequest = Static<typeof UpdateUserRequest>;

export const UpdateSettingsRequest = t.Partial(UserSettings, { $id: "UpdateSettingsRequest" });
export type UpdateSettingsRequest = Static<typeof UpdateSettingsRequest>;
