/**
 * Backfills gym memberships for users whose profile names a home gym but who
 * have no matching membership — the divergence caused by the profile path
 * writing `users.homeGymId` without joining the gym.
 *
 * Dry run by default. Pass --commit to write, matching the gate used by
 * scripts/fb-open-mat/insert.mts.
 */
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
    for (const p of plan.toCreate) {
      // membership.repository.mts:28 stores `{ ...m, _id: m.id }`, so `_id` and
      // `id` MUST be the same value. Two different UUIDs writes a row the app
      // reads back with the wrong id.
      const membershipId: string = crypto.randomUUID();
      await db.collection("gymMemberships").insertOne({
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
    console.log(`\nWrote ${plan.toCreate.length} membership(s).`);
  }

  await client.close();
}
