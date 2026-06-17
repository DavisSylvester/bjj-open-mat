import { Elysia } from "elysia";
import { NotificationListQuery } from "@bjj/contract";
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
export function notificationRoutes(container: Container) {
  const { notificationFacade } = container;

  return new Elysia({ prefix: "/api/v1/notifications" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/",
      async ({ identity, query }) => {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const { items, total } = await notificationFacade.list(
          requireId(identity).userId,
          query.unread ?? false,
          (page - 1) * limit,
          limit,
        );
        return list(items, { page, limit, total });
      },
      { requireAuth: true, query: NotificationListQuery },
    )
    .post(
      "/:id/read",
      async ({ identity, params }) => {
        await notificationFacade.markRead(params.id, requireId(identity).userId);
        return data({ read: true });
      },
      { requireAuth: true },
    )
    .post(
      "/read-all",
      async ({ identity }) => {
        await notificationFacade.markAllRead(requireId(identity).userId);
        return data({ read: true });
      },
      { requireAuth: true },
    );
}
