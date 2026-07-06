import { Elysia } from "elysia";
import {
  CreateGymRequest,
  GymListQuery,
  LogoUploadUrlRequest,
  NearbyQuery,
  UpdateGymRequest,
} from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function gymRoutes(container: Container) {
  const { gymFacade, assetStorage } = container;

  return new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/",
      async ({ query, identity }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const ownerId = query.mine ? requireId(identity).userId : undefined;
        const { items, total } = await gymFacade.list({ ownerId, skip: (page - 1) * limit, limit });
        return list(items, { page, limit, total });
      },
      { query: GymListQuery },
    )
    .post("/", async ({ identity, body }) => data(await gymFacade.create(requireId(identity).userId, body)), {
      requireOwner: true,
      body: CreateGymRequest,
    })
    .post(
      "/logo-upload-url",
      async ({ identity, body }) =>
        data(await assetStorage.presignLogoUpload(requireId(identity).userId, body.contentType)),
      { requireOwner: true, body: LogoUploadUrlRequest },
    )
    .get(
      "/nearby",
      async ({ query }) => {
        const gyms = await gymFacade.nearby(query.lat, query.lng, query.radiusKm ?? 25);
        return list(gyms, { page: 1, limit: gyms.length, total: gyms.length });
      },
      { query: NearbyQuery },
    )
    .get("/:id", async ({ params }) => data(await gymFacade.getById(params.id)))
    .put(
      "/:id",
      async ({ identity, params, body }) => data(await gymFacade.update(requireId(identity).userId, params.id, body)),
      { requireOwner: true, body: UpdateGymRequest },
    )
    .get("/:id/directions", async ({ params }) => data(await gymFacade.directions(params.id)))
    .post(
      "/:id/favorite",
      async ({ identity, params }) => {
        await gymFacade.favorite(requireId(identity).userId, params.id);
        return data({ favorited: true });
      },
      { requireAuth: true },
    )
    .delete(
      "/:id/favorite",
      async ({ identity, params }) => {
        await gymFacade.unfavorite(requireId(identity).userId, params.id);
        return data({ favorited: false });
      },
      { requireAuth: true },
    );
}
