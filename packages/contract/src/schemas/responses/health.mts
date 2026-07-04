import { type Static, Type as t } from "@sinclair/typebox";

export const HealthResponse = t.Object(
  { status: t.Literal("ok"), uptimeSeconds: t.Number() },
  { $id: "HealthResponse" },
);
export type HealthResponse = Static<typeof HealthResponse>;

export const ReadyResponse = t.Object(
  { status: t.Union([t.Literal("ready"), t.Literal("degraded")]), checks: t.Record(t.String(), t.Boolean()) },
  { $id: "ReadyResponse" },
);
export type ReadyResponse = Static<typeof ReadyResponse>;
