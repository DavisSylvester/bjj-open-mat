import { type Static, Type as t } from "@sinclair/typebox";

export const Gender = t.Union([t.Literal("male"), t.Literal("female")], { $id: "Gender" });
export type Gender = Static<typeof Gender>;
