import type { HealthResponse, ReadyResponse } from "@bjj/contract";
import { Elysia } from "elysia";

const startedAt = Date.now();

// Liveness at /health, readiness at /ready (per project convention — never
// /healthz or /readyz).
export const healthRoutes = new Elysia()
  .get("/health", (): HealthResponse => ({
    status: "ok",
    uptimeSeconds: (Date.now() - startedAt) / 1000,
  }))
  .get("/ready", (): ReadyResponse => ({
    status: "ready",
    checks: { seedData: true },
  }));
