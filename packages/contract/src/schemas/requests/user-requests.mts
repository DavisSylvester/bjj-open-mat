import { type Static, Type as t } from "@sinclair/typebox";
import { BeltRank } from "../../enums/belt-rank.mts";
import { UserRole } from "../../enums/user-role.mts";
import { UserSettings } from "../user.mts";

export const UpdateUserRequest = t.Partial(
  t.Object({
    displayName: t.String(),
    role: UserRole,
    beltRank: BeltRank,
    beltStripes: t.Integer({ minimum: 0, maximum: 4 }),
    weight: t.String(),
    bio: t.String(),
    avatarUrl: t.String(),
    homeGymId: t.String(),
  }),
  { $id: "UpdateUserRequest" },
);
export type UpdateUserRequest = Static<typeof UpdateUserRequest>;

export const UpdateSettingsRequest = t.Partial(UserSettings, { $id: "UpdateSettingsRequest" });
export type UpdateSettingsRequest = Static<typeof UpdateSettingsRequest>;
