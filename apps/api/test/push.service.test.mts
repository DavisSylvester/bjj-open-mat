import { describe, expect, it } from "bun:test";
import { PushService } from "../src/push/push.service.mts";
import type { PushPayload, PushSender, PushSendResult } from "../src/push/push.types.mts";
import type { DeviceToken } from "@bjj/contract";

function fakeTokens(rows: DeviceToken[]) {
  const pruned: string[][] = [];
  return {
    repo: {
      listByUser: async (userId: string) => rows.filter((r) => r.userId === userId),
      pruneTokens: async (tokens: string[]) => { pruned.push(tokens); },
    },
    pruned,
  };
}

const payload: PushPayload = { title: "T", body: "B", data: { type: "message" } };
const tok = (userId: string, token: string): DeviceToken => ({ id: token, userId, token, platform: "ios", createdAt: "t" });

describe("PushService", () => {
  it("sends to all of the users' tokens", async () => {
    const { repo } = fakeTokens([tok("u1", "a"), tok("u1", "b"), tok("u2", "c")]);
    const sent: string[][] = [];
    const sender: PushSender = { send: async (tokens) => { sent.push(tokens); return { unregistered: [] }; } };
    await new PushService(repo, sender).pushToUsers(["u1", "u2"], payload);
    expect(sent[0].sort()).toEqual(["a", "b", "c"]);
  });

  it("prunes tokens the sender reports unregistered", async () => {
    const { repo, pruned } = fakeTokens([tok("u1", "a"), tok("u1", "dead")]);
    const sender: PushSender = { send: async (): Promise<PushSendResult> => ({ unregistered: ["dead"] }) };
    await new PushService(repo, sender).pushToUsers(["u1"], payload);
    expect(pruned).toEqual([["dead"]]);
  });

  it("no tokens -> does not call the sender", async () => {
    const { repo } = fakeTokens([]);
    let called = false;
    const sender: PushSender = { send: async () => { called = true; return { unregistered: [] }; } };
    await new PushService(repo, sender).pushToUsers(["nobody"], payload);
    expect(called).toBe(false);
  });

  it("swallows sender errors (never throws)", async () => {
    const { repo } = fakeTokens([tok("u1", "a")]);
    const sender: PushSender = { send: async () => { throw new Error("fcm down"); } };
    // Direct await — must resolve, not reject.
    await new PushService(repo, sender).pushToUsers(["u1"], payload);
    expect(true).toBe(true);
  });
});
