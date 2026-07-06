import { describe, expect, it } from "bun:test";
import { HttpGitHubIssueService } from "../src/services/github-issue.service.mts";
import { AppError } from "../src/http/errors.mts";

interface CapturedRequest {
  url: string;
  init: RequestInit;
}

function fakeFetch(
  captured: CapturedRequest[],
  response: { status: number; body: unknown },
): typeof fetch {
  return (async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    captured.push({ url: String(url), init: init ?? {} });
    return new Response(JSON.stringify(response.body), {
      status: response.status,
      headers: { "Content-Type": "application/json" },
    });
  }) as unknown as typeof fetch;
}

describe("HttpGitHubIssueService", () => {
  it("POSTs to the repo issues endpoint with bearer auth and JSON body, returning number + url", async () => {
    const captured: CapturedRequest[] = [];
    const fetchFn = fakeFetch(captured, { status: 201, body: { number: 42, html_url: "https://github.com/DavisSylvester/bjj-open-mat/issues/42" } });
    const service = new HttpGitHubIssueService("tok-123", "DavisSylvester/bjj-open-mat", fetchFn);

    const result = await service.createIssue({ title: "T", body: "B", labels: ["bug"] });

    expect(result).toEqual({ number: 42, url: "https://github.com/DavisSylvester/bjj-open-mat/issues/42" });
    expect(captured).toHaveLength(1);
    const [req] = captured;
    expect(req.url).toBe("https://api.github.com/repos/DavisSylvester/bjj-open-mat/issues");
    expect(req.init.method).toBe("POST");
    const headers = req.init.headers as Record<string, string>;
    expect(headers["Authorization"]).toBe("Bearer tok-123");
    expect(headers["Accept"]).toBe("application/vnd.github+json");
    expect(headers["Content-Type"]).toBe("application/json");
    expect(JSON.parse(req.init.body as string)).toEqual({ title: "T", body: "B", labels: ["bug"] });
  });

  it("throws an AppError on a non-2xx response", async () => {
    const captured: CapturedRequest[] = [];
    const fetchFn = fakeFetch(captured, { status: 403, body: { message: "forbidden" } });
    const service = new HttpGitHubIssueService("tok-123", "DavisSylvester/bjj-open-mat", fetchFn);

    await expect(service.createIssue({ title: "T", body: "B", labels: ["bug"] })).rejects.toBeInstanceOf(AppError);
  });
});
