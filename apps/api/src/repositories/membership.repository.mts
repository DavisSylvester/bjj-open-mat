// apps/api/src/repositories/membership.repository.mts
import type { Db, Filter } from "mongodb";
import type { GymMembership } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface MembershipDoc extends GymMembership {
  _id: string;
}

export interface GymMemberCounts {
  gymId: string;
  memberCount: number;
  pendingCount: number;
}

export class MembershipRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    await col.createIndex({ gymId: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
    await col.createIndex({ gymId: 1, status: 1 });
  }

  public async upsertJoin(m: GymMembership): Promise<GymMembership> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const existing = await col.findOne({ gymId: m.gymId, userId: m.userId });
    if (existing) return stripId<GymMembership>(existing) as GymMembership;
    await col.insertOne({ ...m, _id: m.id });
    return m;
  }

  public async find(gymId: string, userId: string): Promise<GymMembership | null> {
    return stripId<GymMembership>(
      await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).findOne({ gymId, userId }),
    );
  }

  public async remove(gymId: string, userId: string): Promise<void> {
    await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).deleteOne({ gymId, userId });
  }

  public async listByGym(gymId: string, includeHidden: boolean): Promise<GymMembership[]> {
    // `$nin` / `$ne` also match documents where `status` is absent, which is how
    // legacy rows written before the field existed stay visible. Same reason
    // `visibleInRoster` uses `$ne: false` rather than `true`.
    const filter: Filter<MembershipDoc> = includeHidden
      ? { gymId, status: { $ne: "pending" } }
      : { gymId, status: { $nin: ["pending", "hidden", "inactive"] }, visibleInRoster: { $ne: false } };
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships)
      .find(filter)
      .toArray();
    return docs.map((d) => stripId<GymMembership>(d) as GymMembership);
  }

  public async listByUser(userId: string): Promise<GymMembership[]> {
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).find({ userId }).toArray();
    return docs.map((d) => stripId<GymMembership>(d) as GymMembership);
  }

  public async update(gymId: string, userId: string, patch: Partial<GymMembership>): Promise<GymMembership | null> {
    if (Object.keys(patch).length === 0) return this.find(gymId, userId);
    await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).updateOne({ gymId, userId }, { $set: patch });
    return this.find(gymId, userId);
  }

  public async setHome(userId: string, gymId: string): Promise<void> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    await col.updateMany({ userId, gymId: { $ne: gymId } }, { $set: { isHome: false } });
    await col.updateOne({ userId, gymId }, { $set: { isHome: true } });
  }

  public async listAll(skip: number, limit: number): Promise<{ items: GymMembership[]; total: number }> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const [docs, total] = await Promise.all([
      col.find({}).skip(skip).limit(limit).toArray(),
      col.countDocuments({}),
    ]);
    return { items: docs.map((d) => stripId<GymMembership>(d) as GymMembership), total };
  }

  /// Counts every membership per gym, in Mongo rather than in memory — the
  /// page needs group totals without loading every row, which is the defect
  /// this replaces. Gyms with no memberships are absent, not zero-valued.
  public async countsByGym(): Promise<GymMemberCounts[]> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const docs = await col
      .aggregate<{ _id: string; memberCount: number; pendingCount: number }>([
        {
          $group: {
            _id: "$gymId",
            memberCount: { $sum: 1 },
            pendingCount: { $sum: { $cond: [{ $eq: ["$status", "pending"] }, 1, 0] } },
          },
        },
      ])
      .toArray();
    return docs.map((d) => ({
      gymId: d._id,
      memberCount: d.memberCount,
      pendingCount: d.pendingCount,
    }));
  }

  /// Every membership for a gym, all statuses, paged.
  ///
  /// `listByGym` cannot serve the admin view: it excludes `pending` in both
  /// branches and is unpaged. Reusing it would hide pending members from the
  /// page that approves them, and its count would never reach `memberCount`,
  /// leaving the UI's "Load more" permanently visible.
  public async listByGymForAdmin(
    gymId: string,
    skip: number,
    limit: number,
  ): Promise<{ items: GymMembership[]; total: number }> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    const [docs, total] = await Promise.all([
      col.find({ gymId }).sort({ joinedAt: 1, _id: 1 }).skip(skip).limit(limit).toArray(),
      col.countDocuments({ gymId }),
    ]);
    return { items: docs.map((d) => stripId<GymMembership>(d) as GymMembership), total };
  }
}
