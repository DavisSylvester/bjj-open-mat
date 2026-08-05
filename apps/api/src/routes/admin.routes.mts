import { Elysia } from "elysia";
import {
  AddGymOwnerRequest,
  CreateGymRequest,
  GymMemberInviteRequest,
  UpdateGymRequest,
  UpdateMembershipRequest,
  UpdateOpenMatRequest,
} from "@bjj/contract";
import type { Container } from "../container.mts";
import { data, list } from "../http/envelope.mts";

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function adminRoutes(container: Container) {
  const { adminFacade, gymFacade, openMatFacade } = container;

  return new Elysia({ prefix: "/api/v1/admin" })
    .get("/stats/overview", async () => data(await adminFacade.overview(new Date())))
    .get("/stats/open-mats-by-state", async ({ query }) => {
      const limit = Math.min(50, Math.max(1, Number(query["limit"] ?? 10)));
      return data(await adminFacade.openMatsByState(limit));
    })
    .get("/users", async ({ query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 20)));
      const { items, total } = await adminFacade.listUsers((page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .get("/gyms", async ({ query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 20)));
      const { items, total } = await gymFacade.list({ skip: (page - 1) * limit, limit });
      return list(items, { page, limit, total });
    })
    .get("/open-mats", async ({ query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 20)));
      const { items, total } = await openMatFacade.list({}, (page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .get("/memberships", async ({ query }) => {
      const page = Math.max(1, Number(query["page"] ?? 1));
      const limit = Math.min(100, Math.max(1, Number(query["limit"] ?? 50)));
      const { items, total } = await adminFacade.listMemberships((page - 1) * limit, limit);
      return list(items, { page, limit, total });
    })
    .post("/gyms", async ({ body }) => data(await gymFacade.create("admin", body)), {
      body: CreateGymRequest,
    })
    .put("/gyms/:id", async ({ params, body }) => data(await gymFacade.adminUpdate(params.id, body)), {
      body: UpdateGymRequest,
    })
    .patch(
      "/memberships/:gymId/:userId",
      async ({ params, body }) => data(await adminFacade.updateMembership(params.gymId, params.userId, body)),
      { body: UpdateMembershipRequest },
    )
    .post("/gyms/:id/verify", async ({ params }) => data(await adminFacade.verifyGym(params.id, new Date())))
    .post("/gyms/:id/owner", async ({ params, body }) => data(await adminFacade.addOwner(params.id, body.userId)), {
      body: AddGymOwnerRequest,
    })
    .post("/gyms/:id/invite", async ({ params, body }) => data(await adminFacade.invite(params.id, body.emails)), {
      body: GymMemberInviteRequest,
    })
    .put(
      "/open-mats/:id",
      async ({ params, body }) => data(await openMatFacade.update("admin", "admin", params.id, body)),
      { body: UpdateOpenMatRequest },
    );
}
