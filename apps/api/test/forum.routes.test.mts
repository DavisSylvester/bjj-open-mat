import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import type { ForumQuestion, ForumAnswer, ForumQuestionDetail } from "@bjj/contract";
import { registerErrorHandler } from "../src/http/error-handler.mts";
import { forumRoutes } from "../src/routes/forum.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null): { app: Elysia; calls: string[] } {
  const calls: string[] = [];
  const q1: ForumQuestion = { id: "q1", gymId: "g1", authorId: "u1", category: "general", title: "T", body: "B", pinned: false, locked: false, answerCount: 0 };
  const a1: ForumAnswer = { id: "a1", questionId: "q1", gymId: "g1", authorId: "u1", body: "b", accepted: false };
  const forumFacade = {
    createQuestion: async (u: string, g: string): Promise<ForumQuestion> => { calls.push(`create:${u}:${g}`); return { ...q1, gymId: g, authorId: u }; },
    listQuestions: async (): Promise<{ items: ForumQuestion[]; total: number }> => ({ items: [], total: 0 }),
    getDetail: async (): Promise<ForumQuestionDetail> => ({ question: q1, answers: [] }),
    updateQuestion: async (): Promise<ForumQuestion> => ({ ...q1, pinned: true }),
    deleteQuestion: async (): Promise<void> => { calls.push("delq"); },
    createAnswer: async (u: string, q: string): Promise<ForumAnswer> => { calls.push(`ans:${u}:${q}`); return { ...a1, questionId: q, authorId: u }; },
    updateAnswer: async (): Promise<ForumAnswer> => ({ ...a1, body: "b2" }),
    deleteAnswer: async (): Promise<void> => { calls.push("dela"); },
    accept: async (): Promise<void> => { calls.push("accept"); },
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    forumFacade,
  } as unknown as Container;
  const app = registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined }).use(forumRoutes(container));
  return { app, calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("forum routes", () => {
  it("POST question requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/forum/questions", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ category: "general", title: "T", body: "B" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST question calls facade with caller id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/forum/questions", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ category: "general", title: "T", body: "B" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("create:u1:g1");
  });
  it("POST answer calls facade with caller + question id", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/forum/questions/q1/answers", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ body: "hi" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("ans:u1:q1");
  });
});
