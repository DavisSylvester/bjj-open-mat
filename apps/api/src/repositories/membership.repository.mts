// apps/api/src/repositories/membership.repository.mts
import type { Db } from "mongodb";
import type { GymMembership } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface MembershipDoc extends GymMembership {
  _id: string;
}

export class MembershipRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<MembershipDoc>(COLLECTIONS.gymMemberships);
    await col.createIndex({ gymId: 1, userId: 1 }, { unique: true });
    await col.createIndex({ userId: 1 });
    await col.createIndex({ gymId: 1 });
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
    // `visibleInRoster: { $ne: false }` also keeps legacy docs missing the field.
    const filter = includeHidden ? { gymId } : { gymId, visibleInRoster: { $ne: false } };
    const docs = await this.collection<MembershipDoc>(COLLECTIONS.gymMemberships).find(filter).toArray();
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
}
