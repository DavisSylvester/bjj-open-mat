import { Elysia } from "elysia";
import {
  CheckinRequest,
  CreateOpenMatRequest,
  NearbyQuery,
  OpenMatListQuery,
  RsvpRequest,
  SessionDateQuery,
  UpdateOpenMatRequest,
} from "@bjj/contract";
import type { OpenMatFilter } from "../repositories/open-mat.repository.mts";
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
export function openMatRoutes(container: Container) {
  const { openMatFacade, userFacade, checkInFacade } = container;

  return new Elysia({ prefix: "/api/v1/open-mats" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/",
      async ({ identity, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const filter: OpenMatFilter = {
          dayOfWeek: query.dayOfWeek,
          giType: query.giType,
          skillLevel: query.skillLevel,
        };
        if (query.mine) filter.gymOwnerId = requireId(identity).userId;
        const { items, total } = await openMatFacade.list(filter, (page - 1) * limit, limit);
        return list(items, { page, limit, total });
      },
      { query: OpenMatListQuery },
    )
    .post("/", async ({ identity, body }) => data(await openMatFacade.create(requireId(identity).userId, body)), {
      requireOwner: true,
      body: CreateOpenMatRequest,
    })
    .get(
      "/nearby",
      async ({ query }) => {
        const mats = await openMatFacade.nearby(query.lat, query.lng, query.radiusKm ?? 25);
        return list(mats, { page: 1, limit: mats.length, total: mats.length });
      },
      { query: NearbyQuery },
    )
    .get("/:id", async ({ params }) => data(await openMatFacade.detail(params.id)))
    .put(
      "/:id",
      async ({ identity, params, body }) =>
        data(await openMatFacade.update(requireId(identity).userId, params.id, body)),
      { requireOwner: true, body: UpdateOpenMatRequest },
    )
    .post(
      "/:id/rsvp",
      async ({ identity, params, body }) =>
        data(await openMatFacade.rsvp(params.id, body.sessionDate, requireId(identity).userId)),
      { requireAuth: true, body: RsvpRequest },
    )
    .delete(
      "/:id/rsvp",
      async ({ identity, params, query }) => {
        const sessionDate = query.sessionDate ?? query.date;
        if (!sessionDate) throw new AppError("bad_request", "sessionDate query param required");
        return data(await openMatFacade.cancelRsvp(params.id, sessionDate, requireId(identity).userId));
      },
      { requireAuth: true, query: SessionDateQuery },
    )
    .get(
      "/:id/attendees",
      async ({ params, query }) => {
        const sessionDate = query.sessionDate ?? query.date;
        if (!sessionDate) throw new AppError("bad_request", "sessionDate query param required");
        const userIds = await openMatFacade.attendeeUserIds(params.id, sessionDate);
        const users = await Promise.all(userIds.map((uid) => userFacade.getById(uid).catch(() => null)));
        const attendees = users
          .filter((u): u is NonNullable<typeof u> => u !== null)
          .map((u) => ({
            userId: u.id,
            name: u.displayName,
            beltRank: u.beltRank ?? "white",
            beltStripes: u.beltStripes,
            skillLevel: "all" as const,
            avatarUrl: u.avatarUrl,
            rsvpAt: "",
          }));
        return list(attendees, { page: 1, limit: attendees.length, total: attendees.length });
      },
      { query: SessionDateQuery },
    )
    .post(
      "/:id/checkin",
      async ({ identity, params, body }) =>
        data(await checkInFacade.checkIn(params.id, requireId(identity).userId, body.sessionDate)),
      { requireAuth: true, body: CheckinRequest },
    )
    .get(
      "/:id/checkins",
      async ({ identity, params, query }) => {
        await openMatFacade.assertOwner(requireId(identity).userId, params.id);
        const sessionDate = query.sessionDate ?? query.date;
        const checkins = await checkInFacade.listForSession(params.id, sessionDate);
        return list(checkins, { page: 1, limit: checkins.length, total: checkins.length });
      },
      { requireOwner: true, query: SessionDateQuery },
    );
}
