import { describe, expect, it, afterEach } from "bun:test";
import { rmSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CheckpointStore } from "../lib/checkpoint.mjs";

const dirs: string[] = [];
function tmpFile(): string {
  const d = mkdtempSync(join(tmpdir(), "cp-"));
  dirs.push(d);
  return join(d, "checkpoints.json");
}
afterEach(() => { for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true }); });

describe("CheckpointStore", () => {
  it("returns null for an unseen group and persists updates", () => {
    const path = tmpFile();
    const store = new CheckpointStore(path);
    expect(store.get("gA")).toBeNull();
    store.set("gA", "2026-07-01T00:00:00.000Z");
    store.save();
    const reloaded = new CheckpointStore(path);
    expect(reloaded.get("gA")).toBe("2026-07-01T00:00:00.000Z");
  });
});
