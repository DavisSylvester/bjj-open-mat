import { describe, expect, it } from "bun:test";
import { chooseCanonical, groupDuplicates, normalizeKey, ownedCount, type DedupeGym } from "../scripts/gym-dedupe.mjs";

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
