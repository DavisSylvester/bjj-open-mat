import { describe, expect, it } from "bun:test";
import { ReportFacade } from "../src/facades/report.facade.mts";
import type { ReportRepository } from "../src/repositories/report.repository.mts";
import type { Report } from "@bjj/contract";

type FakeRepo = Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser" | "ensureIndexes">;
function repo(): { fake: FakeRepo; store: Map<string, Report> } {
  const store = new Map<string, Report>();
  const fake: FakeRepo = {
    insert: async (r) => { store.set(r.id, r); return r; },
    update: async (id, patch) => { const cur = store.get(id); if (!cur) return null; const next = { ...cur, ...patch }; store.set(id, next); return next; },
    findById: async (id) => store.get(id) ?? null,
    listByUser: async (u) => [...store.values()].filter((r) => r.userId === u),
    ensureIndexes: async () => {},
  };
  return { fake, store };
}
const nextId = (): string => "r-1";

describe("ReportFacade audio", () => {
  it("persists audioKeys on create", async () => {
    const { fake, store } = repo();
    const facade = new ReportFacade(fake, null, null, null, nextId, "owner/repo");
    await facade.create("u-1", { type: "bug", title: "Crash bug", description: "Crashes on the map screen.", audioKeys: ["reports/audio/u-1/a.m4a"] });
    expect(store.get("r-1")?.audioKeys).toEqual(["reports/audio/u-1/a.m4a"]);
  });

  it("transcribe reads audio and returns English text", async () => {
    const { fake } = repo();
    const audio = {
      presignUpload: async (): Promise<{ uploadUrl: string; audioKey: string }> => ({ uploadUrl: "", audioKey: "" }),
      getObject: async (): Promise<Uint8Array> => new Uint8Array([1]),
      signedDownloadUrl: async (): Promise<string> => "",
    };
    const transcription = {
      translateToEnglish: async (): Promise<{ text: string; durationMs: number }> => ({ text: "hola -> hello", durationMs: 5 }),
    };
    const facade = new ReportFacade(fake, null, audio, transcription, nextId, "owner/repo");
    const out = await facade.transcribe("u-1", "reports/audio/u-1/a.m4a");
    expect(out.text).toBe("hola -> hello");
  });

  it("transcribe throws when transcription is not configured", async () => {
    const { fake } = repo();
    const facade = new ReportFacade(fake, null, null, null, nextId, "owner/repo");
    await expect(facade.transcribe("u-1", "k")).rejects.toBeDefined();
  });
});
