import { Elysia, t } from "elysia";
import type { Container } from "../container.mts";

// Open Mat routes. Inbound params/query/body validated with Elysia's `t`;
// handler return shapes are guaranteed by the @bjj/contract static types.
// Return type inferred so Elysia keeps its route-map generics.
export function openMatRoutes(container: Container) {
  const { openMatService } = container;

  return new Elysia({ prefix: "/api/v1/open-mats" })
    .get(
      "/",
      ({ query }) =>
        openMatService.list({
          dayOfWeek: query.dayOfWeek,
          page: query.page,
          limit: query.limit,
        }),
      {
        query: t.Object({
          dayOfWeek: t.Optional(t.Numeric()),
          lat: t.Optional(t.Numeric()),
          lng: t.Optional(t.Numeric()),
          radiusKm: t.Optional(t.Numeric()),
          page: t.Optional(t.Numeric()),
          limit: t.Optional(t.Numeric()),
        }),
      },
    )
    .get(
      "/:id",
      ({ params, set }) => {
        const detail = openMatService.detail(params.id);
        if (!detail) {
          set.status = 404;
          return { error: "open_mat_not_found", id: params.id };
        }
        return detail;
      },
      { params: t.Object({ id: t.String() }) },
    )
    .get(
      "/:id/attendees",
      ({ params }) => openMatService.attendees(params.id),
      { params: t.Object({ id: t.String() }) },
    )
    .post(
      "/:id/rsvp",
      ({ params, body }) => openMatService.rsvp(params.id, body.sessionDate, new Date().toISOString()),
      {
        params: t.Object({ id: t.String() }),
        body: t.Object({ sessionDate: t.String() }),
      },
    )
    .delete(
      "/:id/rsvp",
      ({ params }) => openMatService.cancelRsvp(params.id),
      { params: t.Object({ id: t.String() }) },
    );
}
