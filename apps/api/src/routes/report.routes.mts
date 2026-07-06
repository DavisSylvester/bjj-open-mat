import { Elysia } from "elysia";
import { CreateReportRequest } from "@bjj/contract";
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
export function reportRoutes(container: Container) {
  const { reportFacade } = container;

  return new Elysia({ prefix: "/api/v1/reports" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/",
      async ({ identity, body }) => data(await reportFacade.create(requireId(identity).userId, body)),
      { requireAuth: true, body: CreateReportRequest },
    )
    .get(
      "/",
      async ({ identity }) => {
        const items = await reportFacade.listMine(requireId(identity).userId);
        return list(items, { page: 1, limit: items.length, total: items.length });
      },
      { requireAuth: true },
    );
}
