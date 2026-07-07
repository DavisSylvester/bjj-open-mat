import { describe, expect, it } from "bun:test";
import { WhisperTranscriptionService } from "../src/services/transcription.mts";

describe("WhisperTranscriptionService", () => {
  it("posts audio to the translations endpoint and returns text", async () => {
    let calledUrl = ""; let auth = "";
    const fakeFetch = (async (url: string, init: RequestInit) => {
      calledUrl = String(url);
      auth = String((init.headers as Record<string, string>)["Authorization"]);
      return new Response(JSON.stringify({ text: "hello in english" }), { status: 200 });
    }) as unknown as typeof fetch;

    const svc = new WhisperTranscriptionService("sk-test", fakeFetch);
    const out = await svc.translateToEnglish(new Uint8Array([1, 2, 3]), "audio.m4a");

    expect(calledUrl).toBe("https://api.openai.com/v1/audio/translations");
    expect(auth).toBe("Bearer sk-test");
    expect(out.text).toBe("hello in english");
    expect(out.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("throws on a non-200 response", async () => {
    const fakeFetch = (async () => new Response("bad", { status: 500 })) as unknown as typeof fetch;
    const svc = new WhisperTranscriptionService("sk-test", fakeFetch);
    await expect(svc.translateToEnglish(new Uint8Array([1]), "a.m4a")).rejects.toBeDefined();
  });
});
