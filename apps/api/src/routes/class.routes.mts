import { Elysia } from "elysia";
import {
  CreateClassRequest,
  UpdateClassRequest,
  OccurrenceOverrideRequest,
  ClassRsvpRequest,
  ScheduleQuery,
  ClassAttendeesQuery,
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
export function classRoutes(container: Container) {
  const { classFacade } = container;

  // Gym-scoped class routes: prefix "/api/v1/gyms" with ":id" for gymId.
  // Splitting into two prefixed instances avoids memoirist param-name conflicts
  // with the existing gym.routes.mts "/:id" route.
  const gymClassRoutes = new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/:id/classes",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await classFacade.create(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: CreateClassRequest },
    )
    .get(
      "/:id/classes",
      async ({ params }) => {
        const defs = await classFacade.listDefinitions(params.id);
        return list(defs, { page: 1, limit: defs.length, total: defs.length });
      },
    )
    .get(
      "/:id/schedule",
      async ({ params, query }) => {
        const schedule = await classFacade.schedule(params.id, query.from, query.to);
        return list(schedule, { page: 1, limit: schedule.length, total: schedule.length });
      },
      { query: ScheduleQuery },
    );

  // Class-scoped routes: prefix "/api/v1/classes" with ":id" for classId.
  const classDetailRoutes = new Elysia({ prefix: "/api/v1/classes" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .patch(
      "/:id",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await classFacade.update(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: UpdateClassRequest },
    )
    .delete(
      "/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await classFacade.archive(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .put(
      "/:id/occurrences/:date",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await classFacade.overrideOccurrence(caller.userId, params.id, params.date, body, caller.role));
      },
      { requireAuth: true, body: OccurrenceOverrideRequest },
    )
    .post(
      "/:id/rsvp",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await classFacade.rsvp(caller.userId, params.id, body.date);
        return data({ ok: true });
      },
      { requireAuth: true, body: ClassRsvpRequest },
    )
    .delete(
      "/:id/rsvp",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await classFacade.unrsvp(caller.userId, params.id, body.date);
        return data({ ok: true });
      },
      { requireAuth: true, body: ClassRsvpRequest },
    )
    .get(
      "/:id/attendees",
      async ({ params, query }) => {
        const attendees = await classFacade.attendees(params.id, query.date);
        return list(attendees, { page: 1, limit: attendees.length, total: attendees.length });
      },
      { query: ClassAttendeesQuery },
    );

  return new Elysia()
    .use(gymClassRoutes)
    .use(classDetailRoutes);
}
