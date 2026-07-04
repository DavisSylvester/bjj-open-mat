import { createRemoteJWKSet, jwtVerify } from "jose";
import type { UserRole } from "@bjj/contract";
import type { AuthIdentity } from "./auth.types.mts";

export interface JwtVerifierConfig {
  readonly bypassSecret: string;
  readonly demoUser: { readonly id: string; readonly role: UserRole; readonly email: string };
  readonly auth0Domain: string | undefined;
  readonly auth0Audience: string | undefined;
}

type Jwks = ReturnType<typeof createRemoteJWKSet>;

export class JwtVerifier {

  private readonly jwks: Jwks | undefined;

  public constructor(private readonly config: JwtVerifierConfig) {
    this.jwks = config.auth0Domain
      ? createRemoteJWKSet(new URL(`https://${config.auth0Domain}/.well-known/jwks.json`))
      : undefined;
  }

  // Returns null when no token is present; throws when a present token is invalid.
  public async verify(token: string | undefined): Promise<AuthIdentity | null> {
    if (!token) return null;

    if (token === this.config.bypassSecret) {
      const { id, role, email } = this.config.demoUser;
      return { userId: id, role, email, viaBypass: true };
    }

    if (!this.jwks) {
      throw new Error("Auth0 not configured and token is not the bypass secret");
    }

    const { payload } = await jwtVerify(token, this.jwks, {
      issuer: `https://${this.config.auth0Domain}/`,
      audience: this.config.auth0Audience,
    });

    const role = (payload["https://bjj/role"] as UserRole | undefined) ?? "practitioner";
    return {
      userId: String(payload.sub),
      role,
      email: String(payload["email"] ?? ""),
      viaBypass: false,
    };
  }
}
