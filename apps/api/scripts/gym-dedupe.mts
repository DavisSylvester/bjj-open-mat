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
