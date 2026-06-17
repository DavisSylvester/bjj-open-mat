import { Elysia } from "elysia";
import { PageQuery, ReviewRequest } from "@bjj/contract";
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
export function checkInRoutes(container: Container) {
  const { checkInFacade } = container;

  return new Elysia()
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/api/v1/checkins/:id/review",
      async ({ identity, params, body }) =>
        data(await checkInFacade.review(params.id, requireId(identity).userId, body)),
      { requireAuth: true, body: ReviewRequest },
    )
    .get(
      "/api/v1/users/me/checkins",
      async ({ identity, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await checkInFacade.listForUser(
          requireId(identity).userId,
          (page - 1) * limit,
          limit,
        );
        return list(items, { page, limit, total });
      },
      { requireAuth: true, query: PageQuery },
    );
}
