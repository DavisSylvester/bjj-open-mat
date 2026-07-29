import { type Static, Type as t } from "@sinclair/typebox";

export const ParticipantRole = t.Union(
  [t.Literal("member"), t.Literal("admin")],
  { $id: "ParticipantRole" },
);
export type ParticipantRole = Static<typeof ParticipantRole>;
