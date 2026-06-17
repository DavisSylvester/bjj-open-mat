import { Elysia } from "elysia";
import { createContainer } from "./container.mts";
import { buildOpenApiDocument } from "./openapi.mts";
import { healthRoutes } from "./routes/health.routes.mts";
import { openMatRoutes } from "./routes/open-mat.routes.mts";

// Builds the Elysia application graph. Pure (no .listen), so tests can boot it
// on an ephemeral port. Return type is inferred — Elysia encodes the route map
// in its generics, so a bare `: Elysia` annotation would discard it.
export function buildApp() {
  const container = createContainer();

  return new Elysia()
    .get("/openapi.json", () => buildOpenApiDocument())
    .use(healthRoutes)
    .use(openMatRoutes(container));
}
