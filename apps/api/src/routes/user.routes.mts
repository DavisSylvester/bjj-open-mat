import { Elysia } from "elysia";
import { AuthSyncRequest, UpdateSettingsRequest, UpdateUserRequest } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data } from "../http/envelope.mts";
import { isSocial } from "../auth/is-social.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function userRoutes(container: Container) {
  const { userFacade } = container;

  return new Elysia()
    .use(authPlugin(container.verifier, container.roleLookup))
    .get("/api/v1/auth/me", async ({ identity }) => data(await userFacade.getOrCreate(requireId(identity))), {
      requireAuth: true,
    })
    .get("/api/v1/users/me", async ({ identity }) => data(await userFacade.getById(requireId(identity).userId)), {
      requireAuth: true,
    })
    .put(
      "/api/v1/users/me",
      async ({ identity, body }) => {
        const id = requireId(identity).userId;
        return data(await userFacade.updateProfile(id, body, isSocial(id)));
      },
      { requireAuth: true, body: UpdateUserRequest },
    )
    .post(
      "/api/v1/auth/sync",
      async ({ identity, body }) => data(await userFacade.syncFromProvider(requireId(identity), body)),
      { requireAuth: true, body: AuthSyncRequest },
    )
    .get(
      "/api/v1/users/me/settings",
      async ({ identity }) => data(await userFacade.getSettings(requireId(identity).userId)),
      { requireAuth: true },
    )
    .put(
      "/api/v1/users/me/settings",
      async ({ identity, body }) => data(await userFacade.updateSettings(requireId(identity).userId, body)),
      { requireAuth: true, body: UpdateSettingsRequest },
    )
    .get("/api/v1/users/:id", async ({ params }) => data(await userFacade.getById(params.id)))
    .delete(
      "/api/v1/users/me",
      async ({ identity }) => {
        const id = requireId(identity).userId;
        await container.accountDeletionService.deleteAccount(id);
        return data({ deleted: true });
      },
      { requireAuth: true },
    );
}
