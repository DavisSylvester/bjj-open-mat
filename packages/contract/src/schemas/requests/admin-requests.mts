import { type Static, Type as t } from "@sinclair/typebox";

export const AddGymOwnerRequest = t.Object(
  { userId: t.String({ minLength: 1 }) },
  { $id: "AddGymOwnerRequest" },
);
export type AddGymOwnerRequest = Static<typeof AddGymOwnerRequest>;

export const GymMemberInviteRequest = t.Object(
  { emails: t.Array(t.String({ format: "email" }), { minItems: 1 }) },
  { $id: "GymMemberInviteRequest" },
);
export type GymMemberInviteRequest = Static<typeof GymMemberInviteRequest>;
