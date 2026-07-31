import { type Static, Type as t } from "@sinclair/typebox";

export const ConversationKind = t.Union(
  [t.Literal("direct"), t.Literal("group"), t.Literal("gym_channel")],
  { $id: "ConversationKind" },
);
export type ConversationKind = Static<typeof ConversationKind>;
