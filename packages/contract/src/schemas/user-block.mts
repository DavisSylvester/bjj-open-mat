import { type Static, Type as t } from "@sinclair/typebox";

export const UserBlock = t.Object(
  {
    id: t.String(),
    blockerId: t.String(),
    blockedId: t.String(),
    createdAt: t.Optional(t.String()),
  },
  { $id: "UserBlock" },
);
export type UserBlock = Static<typeof UserBlock>;
