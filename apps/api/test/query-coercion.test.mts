import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { ConversationListQuery, MessageListQuery, ForumListQuery } from "@bjj/contract";

// Regression: query params arrive as STRINGS. Elysia coerces t.Number but NOT
// t.Integer — so a list query typed with t.Integer 422s on every real request
// ("Expected integer"). These schemas must use t.Number for page/limit so the
// mobile client's `?page=1&limit=20` is accepted. See the bug where the
// conversations screen showed "Couldn't load conversations".

const cases: Array<{ name: string; schema: Parameters<Elysia["get"]>[2] extends never ? never : object; url: string }> = [
  { name: "ConversationListQuery", schema: ConversationListQuery, url: "/c?page=1&limit=20" },
  { name: "MessageListQuery", schema: MessageListQuery, url: "/c?limit=30&before=abc" },
  { name: "ForumListQuery", schema: ForumListQuery, url: "/c?page=2&limit=10" },
];

describe("list query schemas coerce string page/limit", () => {
  for (const c of cases) {
    it(`${c.name} accepts string query params`, async () => {
      const app = new Elysia().get("/c", ({ query }) => query, { query: c.schema as object });
      const res = await app.handle(new Request(`http://localhost${c.url}`));
      expect(res.status).toBe(200);
    });

    it(`${c.name} also accepts a request with no query params`, async () => {
      const app = new Elysia().get("/c", ({ query }) => query, { query: c.schema as object });
      const res = await app.handle(new Request("http://localhost/c"));
      expect(res.status).toBe(200);
    });
  }
});
