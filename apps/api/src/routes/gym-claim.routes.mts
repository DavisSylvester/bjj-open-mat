import { Elysia } from "elysia";
import { SubmitGymClaimRequest, RejectGymClaimRequest, AdminGymClaimsQuery } from "@bjj/contract";
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
export function gymClaimRoutes(container: Container) {
  const { gymClaimFacade } = container;

  const claimantRoutes = new Elysia({ prefix: "/api/v1" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/gyms/:id/claims",
      async ({ identity, params, body }) =>
        data(await gymClaimFacade.submit(requireId(identity).userId, params.id, body)),
      { requireAuth: true, body: SubmitGymClaimRequest },
    )
    .get(
      "/gyms/:id/claims/me",
      async ({ identity, params }) =>
        data(await gymClaimFacade.getMyClaimForGym(requireId(identity).userId, params.id)),
      { requireAuth: true },
    )
    .delete(
      "/gyms/:id/claims/me",
      async ({ identity, params }) => {
        await gymClaimFacade.cancel(requireId(identity).userId, params.id);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .get(
      "/users/me/gym-claims",
      async ({ identity }) => {
        const claims = await gymClaimFacade.listMyClaims(requireId(identity).userId);
        return list(claims, { page: 1, limit: claims.length, total: claims.length });
      },
      { requireAuth: true },
    );

  const adminRoutes = new Elysia({ prefix: "/api/v1/admin" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/gym-claims",
      async ({ query }) => {
        const views = await gymClaimFacade.listForAdminEnriched(query.status ?? "pending");
        return list(views, { page: 1, limit: views.length, total: views.length });
      },
      { requireAdmin: true, query: AdminGymClaimsQuery },
    )
    .post(
      "/gym-claims/:claimId/approve",
      async ({ identity, params }) =>
        data(await gymClaimFacade.approve(requireId(identity).userId, params.claimId)),
      { requireAdmin: true },
    )
    .post(
      "/gym-claims/:claimId/reject",
      async ({ identity, params, body }) =>
        data(await gymClaimFacade.reject(requireId(identity).userId, params.claimId, body.note)),
      { requireAdmin: true, body: RejectGymClaimRequest },
    );

  return new Elysia().use(claimantRoutes).use(adminRoutes);
}
