import { Elysia, t } from "elysia";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data } from "../http/envelope.mts";

// Route-local body schema: avoids the nested $id on DevicePlatform that causes
// Elysia/Ajv to silently drop the route during compilation. Matches the shape
// of RegisterDeviceRequest from @bjj/contract.
const RegisterDeviceBody = t.Object({
  token: t.String({ minLength: 1 }),
  platform: t.Union([t.Literal("ios"), t.Literal("android")]),
});

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function deviceRoutes(container: Container) {
  const { deviceTokenRepo, id } = container;
  return new Elysia({ prefix: "/api/v1" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/devices",
      async ({ identity, body }) => {
        const userId = requireId(identity).userId;
        await deviceTokenRepo.upsertByToken({
          id: id(), userId, token: body.token, platform: body.platform, createdAt: new Date().toISOString(),
        });
        return data({ registered: true });
      },
      { requireAuth: true, body: RegisterDeviceBody },
    )
    .delete(
      "/devices/:token",
      async ({ identity, params }) => {
        requireId(identity);
        await deviceTokenRepo.deleteByToken(params.token);
        return data({ registered: false });
      },
      { requireAuth: true },
    );
}
