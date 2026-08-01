import { describe, expect, it } from "bun:test";
import { FcmPushSender } from "../src/push/fcm-push-sender.mts";
import type { PushPayload } from "../src/push/push.types.mts";

const payload: PushPayload = { title: "T", body: "B", data: { type: "message", conversationId: "c1" } };

describe("FcmPushSender", () => {
  it("marks a token unregistered when FCM returns UNREGISTERED", async () => {
    const calls: string[] = [];
    const fetchImpl = (async (_url: string, init: RequestInit) => {
      const parsed = JSON.parse(init.body as string) as { message: { token: string } };
      calls.push(parsed.message.token);
      if (parsed.message.token === "dead") {
        return new Response(JSON.stringify({ error: { status: "UNREGISTERED" } }), { status: 404 });
      }
      return new Response(JSON.stringify({ name: "ok" }), { status: 200 });
    }) as unknown as typeof fetch;

    const sender = new FcmPushSender({ projectId: "p1", accessToken: async () => "tok", fetchImpl });
    const res = await sender.send(["live", "dead"], payload);

    expect(calls.sort()).toEqual(["dead", "live"]);
    expect(res.unregistered).toEqual(["dead"]);
  });
});
