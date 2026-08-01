/**
 * Gym deduplication helpers — normalization, grouping, merge planning, and
 * DB write runner (reference repointer + commit gate).
 *
 * The module is structured so that all pure functions are importable without
 * any DB connection. The `import.meta.main` block handles the CLI entry point
 * and the v8-snapshot / bson@7 shim must be applied BEFORE dynamic-importing
 * mongodb — see the comment on `isMain`.
 */
import type { Db } from "mongodb";

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
export interface MergeAction {
  readonly canonicalId: string;
  readonly mergedIds: string[];
  readonly canonicalName: string;
}

export interface MergePlan {
  readonly merges: MergeAction[];
  readonly conflicts: DedupeGym[][];
}

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

/**
 * Produces a merge plan from a flat list of gyms.
 *
 * Groups duplicates with `groupDuplicates`, then for each group:
 * - If `ownedCount > 1`, the group is ambiguous — push to `conflicts`.
 * - Otherwise, pick a canonical with `chooseCanonical` and record a
 *   `MergeAction` listing the IDs of the non-canonical records.
 */
export function planMerge(gyms: DedupeGym[]): MergePlan {
  const merges: MergeAction[] = [];
  const conflicts: DedupeGym[][] = [];

  for (const group of groupDuplicates(gyms)) {
    if (ownedCount(group) > 1) {
      conflicts.push(group);
    } else {
      const canonical: DedupeGym = chooseCanonical(group);
      const mergedIds: string[] = group
        .filter((g): boolean => g.id !== canonical.id)
        .map((g): string => g.id);
      merges.push({ canonicalId: canonical.id, mergedIds, canonicalName: canonical.name });
    }
  }

  return { merges, conflicts };
}

// ---------------------------------------------------------------------------
// A4 — Reference repointer + commit runner
// ---------------------------------------------------------------------------

/**
 * All collections that carry a gym foreign-key field, confirmed against
 * `apps/api/src/repositories/`. Collections are listed in the order that
 * minimises risk of dangling references: high-frequency leaf docs first,
 * then participation/state docs, then meta/admin docs.
 *
 * Confirmed via `grep -rn "gymId|homeGymId" apps/api/src/repositories`:
 *   - gymMemberships / gymId    — membership.repository.mts
 *   - openMats / gymId          — open-mat.repository.mts
 *   - checkins / gymId          — check-in.repository.mts
 *   - favorites / gymId         — favorite.repository.mts
 *   - beltPromotions / gymId    — promotion.repository.mts
 *   - gymClasses / gymId        — class.repository.mts
 *   - classOccurrences / gymId  — class-occurrence.repository.mts
 *   - instructorRatings / gymId — instructor-rating.repository.mts (confirmed)
 *   - forumQuestions / gymId    — forum-question.repository.mts (confirmed)
 *   - forumAnswers / gymId      — forum-answer.repository.mts
 *   - conversations / gymId     — conversation.repository.mts
 *   - messageReports / gymId    — message-report.repository.mts
 *   - gymClaims / gymId         — gym-claim.repository.mts
 *   - users / homeGymId         — users collection (via facade/user.repository)
 *
 * Dropped: classRsvps, classJournals, rsvps, notifications, reports,
 *   userBlocks, conversationParticipants, channelReadStates, waitlistLeads,
 *   gymLeads — none carry a gymId or homeGymId field in their repositories.
 */
export const GYM_REF_COLLECTIONS: ReadonlyArray<{ readonly collection: string; readonly field: string }> = [
  { collection: "gymMemberships", field: "gymId" },
  { collection: "openMats", field: "gymId" },
  { collection: "checkins", field: "gymId" },
  { collection: "favorites", field: "gymId" },
  { collection: "beltPromotions", field: "gymId" },
  { collection: "gymClasses", field: "gymId" },
  { collection: "classOccurrences", field: "gymId" },
  { collection: "instructorRatings", field: "gymId" },
  { collection: "forumQuestions", field: "gymId" },
  { collection: "forumAnswers", field: "gymId" },
  { collection: "conversations", field: "gymId" },
  { collection: "messageReports", field: "gymId" },
  { collection: "gymClaims", field: "gymId" },
  { collection: "users", field: "homeGymId" },
] as const;

/**
 * Narrow write surface that can be faked in tests without a live database.
 *
 * `repointRefs` — updates all documents in `collection` where `field` is in
 *   `fromIds`, setting `field` to `toId`. Returns the number of documents
 *   modified.
 * `deleteGyms` — removes the gym documents with the given `_id` values from
 *   the `gyms` collection.
 */
export interface DedupeWriter {
  repointRefs(collection: string, field: string, fromIds: string[], toId: string): Promise<number>;
  deleteGyms(ids: string[]): Promise<void>;
}

/**
 * Per-run summary returned by `applyMerges`.
 */
export interface MergeApplyResult {
  readonly repointed: Record<string, number>;
  readonly deletedGyms: number;
}

/**
 * Applies a `MergePlan` through the given `writer`.
 *
 * For each `MergeAction` (non-conflict only — conflicts are skipped):
 *   1. For each ref collection, repoint all references from `mergedIds` to
 *      `canonicalId`. Repointing happens BEFORE deletion so no document is
 *      ever left with a dangling gym id.
 *   2. After all ref collections for the action are repointed, delete the
 *      merged gym docs.
 *
 * Accumulates modified-document counts per collection across all merges and
 * returns them in `repointed`.
 */
export async function applyMerges(
  plan: MergePlan,
  writer: DedupeWriter,
  refs: ReadonlyArray<{ readonly collection: string; readonly field: string }>,
): Promise<MergeApplyResult> {
  const repointed: Record<string, number> = {};
  let deletedGyms: number = 0;

  for (const action of plan.merges) {
    if (action.mergedIds.length === 0) continue;

    // Repoint all ref collections BEFORE deleting so no row is orphaned.
    for (const ref of refs) {
      const count: number = await writer.repointRefs(ref.collection, ref.field, action.mergedIds, action.canonicalId);
      if (count > 0) {
        repointed[ref.collection] = (repointed[ref.collection] ?? 0) + count;
      }
    }

    await writer.deleteGyms(action.mergedIds);
    deletedGyms += action.mergedIds.length;
  }

  return { repointed, deletedGyms };
}

/**
 * Builds the production `DedupeWriter` backed by a live MongoDB `Db` instance.
 *
 * String-UUID collections are typed with `{ _id: string }` so the driver
 * does not coerce `_id` to `ObjectId` (mirrors the pattern in
 * `backfill-home-gym-memberships.mts`).
 */
export function createMongoDedupeWriter(db: Db): DedupeWriter {
  return {
    repointRefs: async (collection: string, field: string, fromIds: string[], toId: string): Promise<number> => {
      const result = await db
        .collection<{ _id: string }>(collection)
        .updateMany({ [field]: { $in: fromIds } }, { $set: { [field]: toId } });
      return result.modifiedCount;
    },
    deleteGyms: async (ids: string[]): Promise<void> => {
      await db.collection<{ _id: string }>("gyms").deleteMany({ _id: { $in: ids } });
    },
  };
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

const isMain: boolean = import.meta.main === true;

if (isMain) {
  const COMMIT: boolean = process.argv.includes("--commit");

  // Bun 1.3.x exposes v8.startupSnapshot.isBuildingSnapshot as a throwing stub,
  // which bson@7 calls at module load. Shim it, THEN dynamic-import mongodb.
  const v8 = (globalThis as unknown as { process: { getBuiltinModule?: (m: string) => unknown } })
    .process.getBuiltinModule?.("v8") as { startupSnapshot?: Record<string, unknown> } | undefined;
  if (v8) {
    v8.startupSnapshot = { ...(v8.startupSnapshot ?? {}), isBuildingSnapshot: (): boolean => false };
  }
  const { MongoClient } = await import("mongodb");

  const uri: string = process.env["MONGODB_URI"] ?? "";
  const dbName: string = process.env["MONGODB_DB"] ?? "";
  if (!uri || !dbName) {
    console.error("MONGODB_URI and MONGODB_DB are required.");
    process.exit(1);
  }

  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db(dbName);

  const gymDocs = await db
    .collection<{ _id: string; name: string; address: string; googlePlaceId?: string; ownerId?: string; logoUrl?: string; createdAt?: string }>("gyms")
    .find({}, { projection: { _id: 1, name: 1, address: 1, googlePlaceId: 1, ownerId: 1, logoUrl: 1, createdAt: 1 } })
    .toArray();

  const gyms: DedupeGym[] = gymDocs.map((doc): DedupeGym => ({
    id: String(doc["_id"]),
    name: doc.name,
    address: doc.address,
    googlePlaceId: doc.googlePlaceId,
    ownerId: doc.ownerId,
    logoUrl: doc.logoUrl,
    createdAt: doc.createdAt,
  }));

  const plan: MergePlan = planMerge(gyms);

  console.log(`total gyms          : ${gyms.length}`);
  console.log(`duplicate groups    : ${plan.merges.length + plan.conflicts.length}`);
  console.log(`gyms to merge away  : ${plan.merges.reduce((acc, m) => acc + m.mergedIds.length, 0)}`);
  console.log(`conflicts (manual)  : ${plan.conflicts.length}`);

  if (plan.conflicts.length > 0) {
    console.log("\nConflicts — two or more owned records; resolve manually:");
    for (const group of plan.conflicts) {
      const ids: string = group.map((g) => g.id).join(", ");
      console.log(`  [${ids}]`);
    }
  }

  if (plan.merges.length > 0) {
    console.log("\nMerge plan:");
    for (const m of plan.merges) {
      console.log(`  keep ${m.canonicalId} (${m.canonicalName})  <- [${m.mergedIds.join(", ")}]`);
    }
  }

  if (!COMMIT) {
    console.log("\nDRY RUN — nothing written. Re-run with --commit to apply.");
  } else {
    const writer: DedupeWriter = createMongoDedupeWriter(db);
    const result: MergeApplyResult = await applyMerges(plan, writer, GYM_REF_COLLECTIONS);
    console.log("\nMerge applied:");
    for (const [col, count] of Object.entries(result.repointed)) {
      console.log(`  ${col}: ${count} doc(s) repointed`);
    }
    console.log(`  gyms deleted: ${result.deletedGyms}`);
  }

  await client.close();
}
