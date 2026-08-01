/**
 * Gym deduplication helpers — normalization and grouping (pure functions).
 *
 * No I/O in this module. Canonical-record selection and DB writes live in
 * later tasks.
 */

export interface DedupeGym {
  readonly id: string;
  readonly name: string;
  readonly address: string;
  readonly googlePlaceId?: string;
  readonly ownerId?: string;
  readonly logoUrl?: string;
  readonly createdAt?: string;
}

function norm(s: string): string {
  return s
    .toLowerCase()
    .replace(/[.,#'"()]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Returns the grouping key for a gym record.
 *
 * Two-tier strategy:
 * 1. If `googlePlaceId` is present and non-empty, strip a leading `gpl-`
 *    prefix and key by the resulting place id — the strong signal.
 * 2. Otherwise key by `normalize(name) + "|" + normalize(address)`.
 */
export function normalizeKey(g: DedupeGym): string {
  if (g.googlePlaceId !== undefined && g.googlePlaceId !== "") {
    const placeId: string = g.googlePlaceId.replace(/^gpl-/, "");
    return `gpl:${placeId}`;
  }
  return `na:${norm(g.name)}|${norm(g.address)}`;
}

/**
 * Buckets gyms by their normalization key and returns only the groups that
 * contain at least two records (i.e., genuine duplicates).
 */
export function groupDuplicates(gyms: DedupeGym[]): DedupeGym[][] {
  const map = new Map<string, DedupeGym[]>();
  for (const gym of gyms) {
    const key: string = normalizeKey(gym);
    const bucket: DedupeGym[] = map.get(key) ?? [];
    bucket.push(gym);
    map.set(key, bucket);
  }
  return [...map.values()].filter((grp): boolean => grp.length >= 2);
}

/**
 * Counts the number of records in a group that have a non-empty `ownerId`.
 */
export function ownedCount(group: DedupeGym[]): number {
  return group.filter((g): boolean => g.ownerId !== undefined && g.ownerId !== "").length;
}

/**
 * Picks the canonical (surviving) record from a duplicate group.
 *
 * Priority (first match wins):
 * 1. Owned record (`ownerId` present and non-empty). If two are owned, the
 *    caller is responsible for routing the group to conflicts — this function
 *    does NOT throw.
 * 2. Record with a `logoUrl` (curated).
 * 3. Earliest `createdAt` (records missing `createdAt` sort last).
 * 4. Lexicographically smallest `id` (stable tiebreak).
 */
export function chooseCanonical(group: DedupeGym[]): DedupeGym {
  const sorted: DedupeGym[] = [...group].sort((a: DedupeGym, b: DedupeGym): number => {
    const aOwned: boolean = a.ownerId !== undefined && a.ownerId !== "";
    const bOwned: boolean = b.ownerId !== undefined && b.ownerId !== "";
    if (aOwned !== bOwned) {
      return aOwned ? -1 : 1;
    }

    const aHasLogo: boolean = a.logoUrl !== undefined && a.logoUrl !== "";
    const bHasLogo: boolean = b.logoUrl !== undefined && b.logoUrl !== "";
    if (aHasLogo !== bHasLogo) {
      return aHasLogo ? -1 : 1;
    }

    const aDate: string = a.createdAt ?? "￿";
    const bDate: string = b.createdAt ?? "￿";
    if (aDate !== bDate) {
      return aDate < bDate ? -1 : 1;
    }

    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  return sorted[0]!;
}
