import { AppError } from "../http/errors.mts";
import { logger } from "../config/logger.mts";

export interface Auth0ManagementService {
  deleteUser(auth0UserId: string): Promise<void>;
}

interface TokenResponse {
  access_token: string;
}

// Deletes a user's Auth0 identity via the Management API using a client
// credentials grant. Used so account deletion removes the user's login, not
// just their app data.
export class HttpAuth0ManagementService implements Auth0ManagementService {

  public constructor(
    private readonly domain: string,
    private readonly clientId: string,
    private readonly clientSecret: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  private async getToken(): Promise<string> {
    const res = await this.fetchFn(`https://${this.domain}/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        grant_type: "client_credentials",
        client_id: this.clientId,
        client_secret: this.clientSecret,
        audience: `https://${this.domain}/api/v2/`,
      }),
    });
    if (res.status < 200 || res.status >= 300) {
      throw new AppError("service_unavailable", `Auth0 management token request failed (${res.status})`);
    }
    const parsed = (await res.json()) as TokenResponse;
    return parsed.access_token;
  }

  public async deleteUser(auth0UserId: string): Promise<void> {
    const token = await this.getToken();
    const res = await this.fetchFn(`https://${this.domain}/api/v2/users/${encodeURIComponent(auth0UserId)}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status < 200 || res.status >= 300) {
      throw new AppError("service_unavailable", `Auth0 user deletion failed (${res.status})`);
    }
  }
}

// Used in local dev / tests when Auth0 Management API credentials are not
// configured. Logs and no-ops so account deletion still proceeds for app data.
export class UnconfiguredAuth0ManagementService implements Auth0ManagementService {

  public async deleteUser(auth0UserId: string): Promise<void> {
    logger.info(`[auth0-management:noop] would delete Auth0 user ${auth0UserId}`);
  }
}
