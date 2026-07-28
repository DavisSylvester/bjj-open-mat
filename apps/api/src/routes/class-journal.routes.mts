import { Elysia } from "elysia";
import {
  UpsertJournalRequest,
  OccurrenceJournalQuery,
  JournalRangeQuery,
  UpsertInstructorRatingRequest,
  InstructorFeedbackQuery,
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
export function classJournalRoutes(container: Container) {
  const { classJournalFacade } = container;

  // Class-scoped journal + rating routes: prefix "/api/v1/classes".
  const classJournalDetailRoutes = new Elysia({ prefix: "/api/v1/classes" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/:id/journal",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await classJournalFacade.upsertJournal(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: UpsertJournalRequest },
    )
    .get(
      "/:id/journal",
      async ({ identity, params, query }) => {
        const caller = requireId(identity);
        const entries = await classJournalFacade.sharedForOccurrence(caller.userId, params.id, query.date, caller.role);
        return list(entries, { page: 1, limit: entries.length, total: entries.length });
      },
      { requireAuth: true, query: OccurrenceJournalQuery },
    )
    .post(
      "/:id/instructor-rating",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await classJournalFacade.rateInstructor(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: UpsertInstructorRatingRequest },
    );

  // User-scoped journal routes: prefix "/api/v1/users".
  // Splitting into a separate prefixed instance avoids memoirist param-name conflicts
  // with the existing user.routes.mts "/:id" routes.
  const userJournalRoutes = new Elysia({ prefix: "/api/v1/users" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/me/journal",
      async ({ identity, query }) => {
        const caller = requireId(identity);
        const entries = await classJournalFacade.myJournal(caller.userId, query.from, query.to);
        return list(entries, { page: 1, limit: entries.length, total: entries.length });
      },
      { requireAuth: true, query: JournalRangeQuery },
    )
    .get(
      "/:id/instructor-rating",
      async ({ params }) => {
        return data(await classJournalFacade.instructorSummary(params.id));
      },
    );

  // Gym-scoped instructor feedback routes: prefix "/api/v1/gyms".
  const gymFeedbackRoutes = new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/:id/instructor-feedback",
      async ({ identity, params, query }) => {
        const caller = requireId(identity);
        const items = await classJournalFacade.gymInstructorFeedback(
          caller.userId,
          params.id,
          query.instructorUserId,
          query.from,
          query.to,
          caller.role,
        );
        return list(items, { page: 1, limit: items.length, total: items.length });
      },
      { requireAuth: true, query: InstructorFeedbackQuery },
    );

  return new Elysia()
    .use(classJournalDetailRoutes)
    .use(userJournalRoutes)
    .use(gymFeedbackRoutes);
}
