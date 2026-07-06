import { Elysia } from "elysia";
import {
  AttendeesQuery,
  CreateCheckInRequest,
  CreateOpenMatRequest,
  NearbyQuery,
  OpenMatListQuery,
  PageQuery,
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
        const isAdmin = identity?.role === "admin";
        const filter: OpenMatFilter & { zip?: string } = {
          dayOfWeek: query.dayOfWeek,
          giType: query.giType,
          skillLevel: query.skillLevel,
          status: isAdmin ? query.status : "live",
          verified: query.verified,
          q: query.q,
          free: query.free,
          startDate: query.startDate,
          endDate: query.endDate,
          lat: query.lat,
          lng: query.lng,
          radiusKm: query.radiusKm,
          zip: query.zip,
          city: query.city,
          state: query.state,
        };
        if (query.mine) filter.gymOwnerId = requireId(identity).userId;
        if (query.submittedByMe) filter.hostId = requireId(identity).userId;
        const { items, total } = await openMatFacade.list(filter, (page - 1) * limit, limit);
        return list(items, { page, limit, total });
      },
      { query: OpenMatListQuery },
    )
    .post(
      "/",
      async ({ identity, body }) => {
        const id = requireId(identity);
        return data(await openMatFacade.create(id.userId, id.role, body));
      },
      { requireAuth: true, body: CreateOpenMatRequest },
    )
    .get(
      "/nearby",
      async ({ query }) => {
        const mats = await openMatFacade.nearby(query.lat, query.lng, query.radiusKm ?? 25);
        return list(mats, { page: 1, limit: mats.length, total: mats.length });
      },
      { query: NearbyQuery },
    )
    .get("/:id", async ({ params }) => data(await openMatFacade.detail(params.id)))
    .post(
      "/:id/verify",
      async ({ identity, params }) => {
        const id = requireId(identity);
        return data(await openMatFacade.verify(id.userId, id.role, params.id));
      },
      { requireAuth: true },
    )
    .post(
      "/:id/hide",
      async ({ identity, params }) => {
        const id = requireId(identity);
        return data(await openMatFacade.setHidden(id.userId, id.role, params.id, true));
      },
      { requireAuth: true },
    )
    .post(
      "/:id/unhide",
      async ({ identity, params }) => {
        const id = requireId(identity);
        return data(await openMatFacade.setHidden(id.userId, id.role, params.id, false));
      },
      { requireAuth: true },
    )
    .put(
      "/:id",
      async ({ identity, params, body }) => {
        const id = requireId(identity);
        return data(await openMatFacade.update(id.userId, id.role, params.id, body));
      },
      { requireAuth: true, body: UpdateOpenMatRequest },
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
        const page = query.page ?? 1;
        const limit = query.limit ?? 12;
        const { ids, total } = await openMatFacade.attendeeUserIds(params.id, sessionDate, {
          skip: (page - 1) * limit,
          limit,
        });
        // Hydrate each RSVP to a profile, but never DROP one whose profile is
        // missing — otherwise the "going" count under-reports. Fall back to a
        // minimal attendee keyed by the userId.
        const attendees = await Promise.all(
          ids.map(async (uid) => {
            const u = await userFacade.getById(uid).catch(() => null);
            return {
              userId: uid,
              name: u?.displayName ?? "BJJ Practitioner",
              beltRank: u?.beltRank ?? "white",
              beltStripes: u?.beltStripes,
              skillLevel: "all" as const,
              avatarUrl: u?.avatarUrl,
              rsvpAt: "",
            };
          }),
        );
        return list(attendees, { page, limit, total });
      },
      { query: AttendeesQuery },
    )
    .post(
      "/:id/checkin",
      async ({ identity, params, body }) =>
        data(await checkInFacade.checkIn(params.id, requireId(identity).userId, body)),
      { requireAuth: true, body: CreateCheckInRequest },
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
    )
    .get(
      "/:id/reviews",
      async ({ params, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await checkInFacade.reviewsForOpenMat(params.id, (page - 1) * limit, limit);
        return list(items, { page, limit, total });
      },
      { query: PageQuery },
    );
}
