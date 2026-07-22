import { describe, expect, it } from "bun:test";
import {
  HttpAuth0ManagementService,
  UnconfiguredAuth0ManagementService,
} from "../src/services/auth0-management.service.mts";

describe("HttpAuth0ManagementService", () => {
  it("fetches a management token then deletes the user by id", async () => {
    const calls: { url: string; init?: RequestInit }[] = [];
    const fetchFn = async (url: string | URL, init?: RequestInit): Promise<Response> => {
      const href = url.toString();
      calls.push({ url: href, init });
      if (href.endsWith("/oauth/token")) {
        return new Response(JSON.stringify({ access_token: "mgmt-token" }), { status: 200 });
      }
      if (href.includes("/api/v2/users/")) {
        return new Response(null, { status: 204 });
      }
      throw new Error(`unexpected fetch: ${href}`);
    };

    const svc = new HttpAuth0ManagementService("tenant.us.auth0.com", "client-id", "client-secret", fetchFn as typeof fetch);
    await svc.deleteUser("auth0|abc123");

    expect(calls).toHaveLength(2);
    expect(calls[0].url).toBe("https://tenant.us.auth0.com/oauth/token");
    expect(calls[1].url).toBe("https://tenant.us.auth0.com/api/v2/users/auth0%7Cabc123");
    expect(calls[1].init?.method).toBe("DELETE");
    expect((calls[1].init?.headers as Record<string, string>)["Authorization"]).toBe("Bearer mgmt-token");
  });

  it("throws when the delete call fails", async () => {
    const fetchFn = async (url: string | URL): Promise<Response> => {
      if (url.toString().endsWith("/oauth/token")) {
        return new Response(JSON.stringify({ access_token: "mgmt-token" }), { status: 200 });
      }
      return new Response("nope", { status: 500 });
    };
    const svc = new HttpAuth0ManagementService("tenant.us.auth0.com", "id", "secret", fetchFn as typeof fetch);
    await expect(svc.deleteUser("auth0|abc")).rejects.toThrow();
  });
});

describe("UnconfiguredAuth0ManagementService", () => {
  it("no-ops without throwing when Auth0 management credentials are absent", async () => {
    const svc = new UnconfiguredAuth0ManagementService();
    await expect(svc.deleteUser("auth0|abc")).resolves.toBeUndefined();
  });
});
