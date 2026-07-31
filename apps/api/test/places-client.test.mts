import { afterEach, describe, expect, test } from "bun:test";
import { GooglePlacesClient } from "../src/services/places-client.mts";

describe("GooglePlacesClient.writeAReviewUri", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  function installMockFetch(impl: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>): void {
    globalThis.fetch = Object.assign(impl, originalFetch) as typeof fetch;
  }

  test("returns null instead of throwing when the fetch is aborted/errors", async () => {
    installMockFetch(async (): Promise<Response> => {
      throw new DOMException("The operation was aborted.", "TimeoutError");
    });

    const client = new GooglePlacesClient("test-key");
    await expect(client.writeAReviewUri("place-1")).resolves.toBeNull();
  });

  test("passes a 5s abort signal on the outgoing request", async () => {
    let sawSignal: AbortSignal | undefined;
    installMockFetch(async (_input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
      sawSignal = init?.signal ?? undefined;
      return new Response(JSON.stringify({ googleMapsLinks: { writeAReviewUri: "https://maps.example/review" } }), {
        status: 200,
      });
    });

    const client = new GooglePlacesClient("test-key");
    const uri = await client.writeAReviewUri("place-1");

    expect(uri).toBe("https://maps.example/review");
    expect(sawSignal).toBeInstanceOf(AbortSignal);
  });
});
