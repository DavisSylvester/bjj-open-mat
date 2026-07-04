import { Elysia } from "elysia";
import type { UserRole } from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import type { AuthIdentity } from "./auth.types.mts";
import type { JwtVerifier } from "./jwt-verifier.mts";

function bearer(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const [scheme, value] = header.split(" ");
  return scheme === "Bearer" ? value : undefined;
}

// roleLookup returns the stored role for a userId, or null if the user doesn't exist yet.
export type RoleLookup = (userId: string) => Promise<UserRole | null>;

// `resolve` attaches `identity` (possibly null) to context. Guards throw AppError.
// The concrete Elysia plugin type (macros + resolve) is inferred by design and is
// not practically hand-writable, so the return type is intentionally inferred here.
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function authPlugin(verifier: JwtVerifier, roleLookup: RoleLookup) {
  return new Elysia({ name: "auth" })
    .resolve(async ({ headers }): Promise<{ identity: AuthIdentity | null }> => {
      const token = bearer(headers["authorization"]);
      // An invalid/expired token throws in verify(); treat it as unauthenticated
      // (identity null) so protected routes return 401 — which the client's
      // refresh-on-401 interceptor relies on — rather than a 500.
      let verified: AuthIdentity | null;
      try {
        verified = await verifier.verify(token);
      } catch {
        return { identity: null };
      }
      if (!verified) return { identity: null };
      const dbRole = await roleLookup(verified.userId);
      return { identity: { ...verified, role: dbRole ?? verified.role } };
    })
    .macro({
      requireAuth(enabled: boolean) {
        return {
          beforeHandle({ identity }): void {
            if (enabled && !identity) throw new AppError("unauthorized", "Authentication required");
          },
        };
      },
      requireOwner(enabled: boolean) {
        return {
          beforeHandle({ identity }): void {
            if (!enabled) return;
            if (!identity) throw new AppError("unauthorized", "Authentication required");
            if (identity.role !== "gym_owner") throw new AppError("forbidden", "Gym owner role required");
          },
        };
      },
      requireAdmin(enabled: boolean) {
        return {
          beforeHandle({ identity }): void {
            if (!enabled) return;
            if (!identity) throw new AppError("unauthorized", "Authentication required");
            if (identity.role !== "admin") throw new AppError("forbidden", "Admin role required");
          },
        };
      },
    })
    // Promote `resolve` (identity) and the macros from the plugin's encapsulated
    // scope up to the instance that `.use`s this plugin, so the route modules that
    // apply it see `identity` and can use the requireAuth/requireOwner macros.
    .as("scoped");
}
