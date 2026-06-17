import type { HealthResponse, ReadyResponse } from "@bjj/contract";
import { Elysia } from "elysia";
import type { Db } from "mongodb";

const startedAt = Date.now();

// Liveness at /health, readiness at /ready (per project convention — never /healthz).
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function healthRoutes(db: Db) {
  return new Elysia()
    .get("/health", (): HealthResponse => ({ status: "ok", uptimeSeconds: (Date.now() - startedAt) / 1000 }))
    .get("/ready", async (): Promise<ReadyResponse> => {
      let mongoOk = false;
      try {
        await db.command({ ping: 1 });
        mongoOk = true;
      } catch {
        mongoOk = false;
      }
      return { status: mongoOk ? "ready" : "degraded", checks: { mongo: mongoOk } };
    });
}
