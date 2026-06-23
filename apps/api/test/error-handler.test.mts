import { describe, expect, it } from "bun:test";
import { Elysia, t } from "elysia";
import { registerErrorHandler } from "../src/http/error-handler.mts";

describe("error handler", () => {
  it("logs validation failures with VALIDATION: prefix and returns 400 envelope", async () => {
    const lines: string[] = [];
    const app = registerErrorHandler(
      new Elysia(),
      { warn: (m: string) => lines.push(m), error: () => {} },
    ).post("/echo", ({ body }) => body, { body: t.Object({ name: t.String() }) });

    const res = await app.handle(
      new Request("http://localhost/echo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: 123 }),
      }),
    );

    expect(res.status).toBe(400);
    const json = await res.json();
    expect(json.error.code).toBe("bad_request");
    expect(lines.some((l) => l.startsWith("VALIDATION: "))).toBe(true);
  });

  it("maps AppError not_found to 404", async () => {
    const { AppError } = await import("../src/http/errors.mts");
    const app = registerErrorHandler(new Elysia(), { warn: () => {}, error: () => {} }).get("/x", () => {
      throw new AppError("not_found", "nope");
    });
    const res = await app.handle(new Request("http://localhost/x"));
    expect(res.status).toBe(404);
  });
});
