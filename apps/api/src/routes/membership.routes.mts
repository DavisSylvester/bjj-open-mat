import { Elysia } from "elysia";
import { UpdateMembershipRequest, UpdateMyMembershipRequest, PromoteBeltRequest } from "@bjj/contract";
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
export function membershipRoutes(container: Container) {
  const { membershipFacade } = container;

  // Gym membership routes use prefix "/api/v1/gyms" with ":id" for gymId
  // to avoid param-name conflicts with the existing gym.routes.mts ("/:id").
  const gymMemberRoutes = new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/:id/members",
      async ({ identity, params }) => data(await membershipFacade.join(requireId(identity).userId, params.id)),
      { requireAuth: true },
    )
    .delete(
      "/:id/members/me",
      async ({ identity, params }) => {
        await membershipFacade.leave(requireId(identity).userId, params.id);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .get(
      "/:id/members",
      async ({ params }) => {
        const roster = await membershipFacade.roster(params.id);
        return list(roster, { page: 1, limit: roster.length, total: roster.length });
      },
    )
    .patch(
      "/:id/members/me",
      async ({ identity, params, body }) =>
        data(await membershipFacade.updateMyMembership(requireId(identity).userId, params.id, body)),
      { requireAuth: true, body: UpdateMyMembershipRequest },
    )
    .patch(
      "/:id/members/:userId",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await membershipFacade.updateMembership(caller.userId, params.id, params.userId, body, caller.role));
      },
      { requireAuth: true, body: UpdateMembershipRequest },
    )
    .post(
      "/:id/members/:userId/promotions",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await membershipFacade.promote(caller.userId, params.id, params.userId, body, caller.role));
      },
      { requireAuth: true, body: PromoteBeltRequest },
    );

  // User routes use ":id" to match the existing user.routes.mts param name convention.
  const userMemberRoutes = new Elysia({ prefix: "/api/v1/users" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/:id/promotions",
      async ({ params }) => {
        const promotions = await membershipFacade.listPromotions(params.id);
        return list(promotions, { page: 1, limit: promotions.length, total: promotions.length });
      },
    )
    .get(
      "/me/memberships",
      async ({ identity }) => {
        const memberships = await membershipFacade.listMyMemberships(requireId(identity).userId);
        return list(memberships, { page: 1, limit: memberships.length, total: memberships.length });
      },
      { requireAuth: true },
    );

  return new Elysia()
    .use(gymMemberRoutes)
    .use(userMemberRoutes);
}
