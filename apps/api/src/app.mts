import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import type { Container } from "./container.mts";
import { logger } from "./config/logger.mts";
import { registerErrorHandler } from "./http/error-handler.mts";
import { buildOpenApiDocument } from "./openapi.mts";
import { checkInRoutes } from "./routes/check-in.routes.mts";
import { favoriteRoutes } from "./routes/favorite.routes.mts";
import { gymRoutes } from "./routes/gym.routes.mts";
import { healthRoutes } from "./routes/health.routes.mts";
import { notificationRoutes } from "./routes/notification.routes.mts";
import { openMatRoutes } from "./routes/open-mat.routes.mts";
import { userRoutes } from "./routes/user.routes.mts";

// The auth plugin (identity resolve + requireAuth/requireOwner macros) is applied
// inside each route module. Elysia encapsulates a plugin's macros and resolve by
// default, so a single top-level `.use(authPlugin())` would not propagate them to
// the separately-constructed route-module instances. Applying it per module keeps
// the macros and `identity` in scope where they are consumed (and the shared
// `name: "auth"` lets Elysia dedupe the instance at runtime).
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function buildApp(container: Container) {
  const base = registerErrorHandler(new Elysia(), logger)
    .use(cors())
    .onAfterResponse(({ request, path, set }): void => {
      logger.info(`${request.method} ${path} -> ${set.status ?? ""}`);
    });

  return base
    .get("/openapi.json", () => buildOpenApiDocument())
    .use(healthRoutes(container.db))
    .use(userRoutes(container))
    .use(gymRoutes(container))
    .use(openMatRoutes(container))
    .use(checkInRoutes(container))
    .use(favoriteRoutes(container))
    .use(notificationRoutes(container));
}
