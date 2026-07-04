import { type Static, Type as t } from "@sinclair/typebox";

export const Favorite = t.Object(
  { userId: t.String(), gymId: t.String(), createdAt: t.String() },
  { $id: "Favorite" },
);
export type Favorite = Static<typeof Favorite>;
