import { Elysia } from "elysia";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function favoriteRoutes(container: Container) {
  const { gymFacade } = container;

  return new Elysia()
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/api/v1/users/me/favorites",
      async ({ identity }) => {
        const gyms = await gymFacade.listFavorites(requireId(identity).userId);
        return list(gyms, { page: 1, limit: gyms.length, total: gyms.length });
      },
      { requireAuth: true },
    );
}
