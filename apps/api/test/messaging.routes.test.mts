import { describe, expect, it } from "bun:test";
import { Elysia } from "elysia";
import { registerErrorHandler } from "../src/http/error-handler.mts";
import { messagingRoutes } from "../src/routes/messaging.routes.mts";
import type { Container } from "../src/container.mts";
import type { AuthIdentity } from "../src/auth/auth.types.mts";

function testApp(identity: AuthIdentity | null) {
  const calls: string[] = [];
  const messagingFacade = {
    startDirect: async (u: string, r: string) => { calls.push(`direct:${u}:${r}`); return { id: "c1", kind: "direct", pairKey: `${u}|${r}`, createdBy: u }; },
    createGroup: async (u: string, g: string) => { calls.push(`group:${u}:${g}`); return { id: "c2", kind: "group", gymId: g, title: "S", createdBy: u }; },
    createChannel: async (u: string, g: string) => { calls.push(`channel:${u}:${g}`); return { id: "c3", kind: "gym_channel", gymId: g, title: "General", createdBy: u }; },
    listChannels: async () => [],
    listConversations: async () => ({ items: [], total: 0 }),
    getMessages: async () => [],
    sendMessage: async (u: string, c: string) => { calls.push(`send:${u}:${c}`); return { id: "m1", conversationId: c, authorId: u, body: "hi" }; },
    markRead: async (): Promise<void> => { calls.push("read"); },
    setMuted: async (): Promise<void> => { calls.push("mute"); },
    leaveConversation: async (): Promise<void> => { calls.push("leave"); },
    addParticipants: async (): Promise<void> => { calls.push("addp"); },
    editMessage: async () => ({ id: "m1", conversationId: "c1", authorId: "u1", body: "e" }),
    deleteMessage: async (): Promise<void> => { calls.push("delmsg"); },
    reportMessage: async () => ({ id: "r1", reportedUserId: "u2", reporterId: "u1", gymId: "g1", reason: "spam", status: "open" }),
    listReports: async (u: string, g: string, s: string | undefined) => { calls.push(`reports:${g}:${s}`); return []; },
    resolveReport: async (): Promise<void> => { calls.push("resolve"); },
    listBlocks: async () => [],
    blockUser: async (): Promise<void> => { calls.push("block"); },
    unblockUser: async (): Promise<void> => { calls.push("unblock"); },
  };
  const container = {
    verifier: { verify: async (t?: string): Promise<AuthIdentity | null> => (t ? identity : null) },
    roleLookup: async (): Promise<"practitioner"> => "practitioner",
    messagingFacade,
  } as unknown as Container;
  const app = registerErrorHandler(new Elysia(), { warn: (): void => undefined, error: (): void => undefined }).use(messagingRoutes(container));
  return { app, calls };
}
const id: AuthIdentity = { userId: "u1", role: "practitioner", email: "u@x.co", viaBypass: true };

describe("messaging routes", () => {
  it("POST /direct requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/direct", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ recipientId: "u2" }),
    }));
    expect(res.status).toBe(401);
  });
  it("POST /direct calls facade with caller + recipient", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/direct", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ recipientId: "u2" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("direct:u1:u2");
  });
  it("POST send message calls facade with caller + conversation", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/messaging/conversations/c9/messages", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ body: "hi" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("send:u1:c9");
  });
  it("POST channel create is gym-scoped", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/channels", {
      method: "POST", headers: { authorization: "Bearer t", "content-type": "application/json" }, body: JSON.stringify({ title: "Announcements" }),
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("channel:u1:g1");
  });
  it("GET /:id/message-reports requires auth", async () => {
    const { app } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/message-reports?status=open"));
    expect(res.status).toBe(401);
  });
  it("GET /:id/message-reports passes gymId and status to facade", async () => {
    const { app, calls } = testApp(id);
    const res = await app.handle(new Request("http://localhost/api/v1/gyms/g1/message-reports?status=open", {
      headers: { authorization: "Bearer t" },
    }));
    expect(res.status).toBe(200);
    expect(calls).toContain("reports:g1:open");
  });
});
