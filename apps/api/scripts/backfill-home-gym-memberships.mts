/**
 * Backfills gym memberships for users whose profile names a home gym but who
 * have no matching membership — the divergence caused by the profile path
 * writing `users.homeGymId` without joining the gym.
 *
 * Dry run by default. Pass --commit to write, matching the gate used by
 * scripts/fb-open-mat/insert.mts.
 */
import type { GymMembership } from "@bjj/contract";

/// Mirrors `MembershipDoc` in membership.repository.mts:7-9 — the driver
/// infers `_id: ObjectId` from an untyped collection, which rejects the
/// string UUIDs this app uses as ids. Typing the collection this way keeps
/// `_id` and `id` both `string`, matching `upsertJoin`'s `{ ...m, _id: m.id }`.
export interface MembershipDoc extends GymMembership {
  readonly _id: string;
}

export interface BackfillUser {
  readonly id: string;
  readonly homeGymId?: string;
}

export interface BackfillPair {
  readonly userId: string;
  readonly gymId: string;
}

export interface BackfillPlan {
  readonly toCreate: BackfillPair[];
  readonly skippedExisting: BackfillPair[];
  readonly skippedMissingGym: BackfillPair[];
}

/// Pure planner. `membershipKeys` holds `${gymId}::${userId}` for every
/// existing membership.
export function planBackfill(
  users: BackfillUser[],
  gymIds: Set<string>,
  membershipKeys: Set<string>,
): BackfillPlan {
  const toCreate: BackfillPair[] = [];
  const skippedExisting: BackfillPair[] = [];
  const skippedMissingGym: BackfillPair[] = [];

  for (const u of users) {
    const gymId: string | undefined = u.homeGymId;
    if (gymId === undefined || gymId === "") continue;
    const pair: BackfillPair = { userId: u.id, gymId };
    if (!gymIds.has(gymId)) {
      skippedMissingGym.push(pair);
    } else if (membershipKeys.has(`${gymId}::${u.id}`)) {
      skippedExisting.push(pair);
    } else {
      toCreate.push(pair);
    }
  }
  return { toCreate, skippedExisting, skippedMissingGym };
}

/// Minimal write surface the commit branch needs — narrow enough to fake in a
/// test without a live database, matching what `MembershipRepository.setHome`
/// (membership.repository.mts:60-64) does before every home-gym write.
export interface MembershipWriter {
  clearOtherHomes(userId: string, gymId: string): Promise<void>;
  insertMembership(doc: MembershipDoc): Promise<void>;
}

/// Applies a plan's `toCreate` pairs through `writer`, holding the same
/// single-home-gym invariant the rest of the app assumes: every user's other
/// memberships have `isHome` cleared before the new home membership is
/// inserted. Extracted from the `--commit` branch so the ordering and the
/// exclusivity behaviour are testable without a live database.
export async function applyBackfill(plan: BackfillPlan, writer: MembershipWriter, now: string): Promise<void> {
  for (const p of plan.toCreate) {
    await writer.clearOtherHomes(p.userId, p.gymId);
    const membershipId: string = crypto.randomUUID();
    // membership.repository.mts:28 stores `{ ...m, _id: m.id }`, so `_id` and
    // `id` MUST be the same value. Two different UUIDs writes a row the app
    // reads back with the wrong id.
    await writer.insertMembership({
      _id: membershipId,
      id: membershipId,
      gymId: p.gymId,
      userId: p.userId,
      status: "active",
      verifiedMember: false,
      gymRole: "member",
      isHome: true,
      visibleInRoster: true,
      joinMethod: "self",
      joinedAt: now,
      createdAt: now,
    });
  }
}

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

  const users = (await db.collection("users")
    .find({ homeGymId: { $exists: true, $ne: null } }, { projection: { homeGymId: 1 } })
    .toArray()).map((u): BackfillUser => ({ id: String(u["_id"]), homeGymId: u["homeGymId"] as string }));

  const gymIds = new Set<string>(
    (await db.collection("gyms").find({}, { projection: { _id: 1 } }).toArray()).map((g) => String(g["_id"])),
  );

  const membershipKeys = new Set<string>(
    (await db.collection("gymMemberships").find({}, { projection: { gymId: 1, userId: 1 } }).toArray())
      .map((m) => `${String(m["gymId"])}::${String(m["userId"])}`),
  );

  const plan: BackfillPlan = planBackfill(users, gymIds, membershipKeys);

  console.log(`users with a home gym : ${users.length}`);
  console.log(`  to create           : ${plan.toCreate.length}`);
  console.log(`  already a member    : ${plan.skippedExisting.length}`);
  console.log(`  home gym missing    : ${plan.skippedMissingGym.length}`);
  for (const p of plan.toCreate) console.log(`   + ${p.userId} -> ${p.gymId}`);
  for (const p of plan.skippedMissingGym) console.log(`   ! ${p.userId} -> ${p.gymId} (gym not found)`);

  if (!COMMIT) {
    console.log(`\nDRY RUN — nothing written. Re-run with --commit to apply.`);
  } else {
    const now: string = new Date().toISOString();
    const membershipsCol = db.collection<MembershipDoc>("gymMemberships");
    const writer: MembershipWriter = {
      clearOtherHomes: async (userId: string, gymId: string): Promise<void> => {
        // Mirrors MembershipRepository.setHome (membership.repository.mts:60-64):
        // clear isHome on this user's other memberships before the new one is
        // inserted, so we never leave two gyms simultaneously marked home.
        await membershipsCol.updateMany({ userId, gymId: { $ne: gymId } }, { $set: { isHome: false } });
      },
      insertMembership: async (doc: MembershipDoc): Promise<void> => {
        await membershipsCol.insertOne(doc);
      },
    };
    await applyBackfill(plan, writer, now);
    console.log(`\nWrote ${plan.toCreate.length} membership(s).`);
  }

  await client.close();
}
