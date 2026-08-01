import { describe, expect, it } from "bun:test";
import {
  applyMerges,
  chooseCanonical,
  groupDuplicates,
  normalizeKey,
  ownedCount,
  planMerge,
  type DedupeGym,
  type DedupeWriter,
  type MergeApplyResult,
  type MergePlan,
} from "../scripts/gym-dedupe.mjs";

const g = (id: string, name: string, address: string, extra: Partial<DedupeGym> = {}): DedupeGym =>
  ({ id, name, address, ...extra });

describe("normalizeKey", (): void => {
  it("keys by google place id, ignoring the gpl- prefix", (): void => {
    const a: string = normalizeKey(g("uuid-1", "RM Elite", "1 Main St", { googlePlaceId: "ChIJ123" }));
    const b: string = normalizeKey(g("gpl-ChIJ123", "RM Elite BJJ", "1 Main Street", { googlePlaceId: "gpl-ChIJ123" }));
    expect(a).toBe(b);
  });

  it("falls back to normalized name+address when no place id", (): void => {
    const a: string = normalizeKey(g("uuid-1", "Gracie  Barra.", "10 Oak St., #2"));
    const b: string = normalizeKey(g("uuid-2", "gracie barra", "10 oak st #2"));
    expect(a).toBe(b);
  });

  it("keeps genuinely different gyms apart", (): void => {
    expect(normalizeKey(g("1", "Alliance", "1 A St"))).not.toBe(normalizeKey(g("2", "Atos", "2 B St")));
  });
});

describe("groupDuplicates", (): void => {
  it("returns only groups of size >= 2", (): void => {
    const groups: DedupeGym[][] = groupDuplicates([
      g("1", "RM Elite", "1 Main St", { googlePlaceId: "ChIJ9" }),
      g("gpl-ChIJ9", "RM Elite BJJ", "1 Main Street", { googlePlaceId: "gpl-ChIJ9" }),
      g("3", "Unique Gym", "99 Solo Rd"),
    ]);
    expect(groups.length).toBe(1);
    expect(groups[0]!.map((x) => x.id).sort()).toEqual(["1", "gpl-ChIJ9"]);
  });
});

describe("ownedCount", (): void => {
  it("counts records with a non-empty ownerId", (): void => {
    expect(ownedCount([
      g("a", "X", "1", { ownerId: "owner-1" }),
      g("b", "X", "1"),
      g("c", "X", "1", { ownerId: "" }),
    ])).toBe(1);
  });

  it("returns 0 when no record is owned", (): void => {
    expect(ownedCount([g("a", "X", "1"), g("b", "X", "1")])).toBe(0);
  });
});

describe("chooseCanonical", (): void => {
  it("prefers an owned record", (): void => {
    const c = chooseCanonical([
      g("a", "X", "1", { createdAt: "2020-01-01" }),
      g("b", "X", "1", { ownerId: "owner-1", createdAt: "2024-01-01" }),
    ]);
    expect(c.id).toBe("b");
  });

  it("prefers a record with a logo when none owned", (): void => {
    const c = chooseCanonical([
      g("a", "X", "1", { createdAt: "2020-01-01" }),
      g("b", "X", "1", { logoUrl: "https://cdn/x.png", createdAt: "2021-01-01" }),
    ]);
    expect(c.id).toBe("b");
  });

  it("prefers the oldest when neither owned nor logo'd", (): void => {
    const c = chooseCanonical([
      g("a", "X", "1", { createdAt: "2022-01-01" }),
      g("b", "X", "1", { createdAt: "2020-01-01" }),
    ]);
    expect(c.id).toBe("b");
  });

  it("falls back to smallest id", (): void => {
    const c = chooseCanonical([g("zzz", "X", "1"), g("aaa", "X", "1")]);
    expect(c.id).toBe("aaa");
  });
});

describe("planMerge", (): void => {
  it("plans a merge for a normal duplicate pair", (): void => {
    const plan: MergePlan = planMerge([
      g("keep", "X", "1", { logoUrl: "u" }),
      g("dup", "X", "1"),
      g("solo", "Y", "2"),
    ]);
    expect(plan.merges.length).toBe(1);
    expect(plan.merges[0]!.canonicalId).toBe("keep");
    expect(plan.merges[0]!.mergedIds).toEqual(["dup"]);
    expect(plan.conflicts).toEqual([]);
  });

  it("routes two-owned groups to conflicts, never merges", (): void => {
    const plan: MergePlan = planMerge([
      g("o1", "X", "1", { ownerId: "a" }),
      g("o2", "X", "1", { ownerId: "b" }),
    ]);
    expect(plan.merges).toEqual([]);
    expect(plan.conflicts.length).toBe(1);
    expect(plan.conflicts[0]!.map((x) => x.id).sort()).toEqual(["o1", "o2"]);
  });

  it("yields empty plan when there are no duplicates", (): void => {
    const plan: MergePlan = planMerge([g("a", "X", "1"), g("b", "Y", "2")]);
    expect(plan.merges).toEqual([]);
    expect(plan.conflicts).toEqual([]);
  });
});

describe("applyMerges", (): void => {
  it("repoints references then deletes merged gyms", async (): Promise<void> => {
    const rows = { gymMemberships: [{ gymId: "dup" }, { gymId: "other" }] } as Record<string, Array<Record<string, string>>>;
    const deleted: string[] = [];
    const writer: DedupeWriter = {
      repointRefs: async (c, f, from, to): Promise<number> => {
        let n = 0;
        for (const r of rows[c] ?? []) if (from.includes(r[f]!)) { r[f] = to; n++; }
        return n;
      },
      deleteGyms: async (ids): Promise<void> => { deleted.push(...ids); },
    };
    const plan: MergePlan = { merges: [{ canonicalId: "keep", mergedIds: ["dup"], canonicalName: "X" }], conflicts: [] };
    const result: MergeApplyResult = await applyMerges(plan, writer, [{ collection: "gymMemberships", field: "gymId" }]);
    expect(rows.gymMemberships[0]!.gymId).toBe("keep");
    expect(rows.gymMemberships[1]!.gymId).toBe("other");
    expect(result.deletedGyms).toBe(1);
    expect(deleted).toEqual(["dup"]);
  });
});
