import type { Db } from "mongodb";
import type { GymClaim, GymClaimStatus } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface GymClaimDoc extends GymClaim {
  _id: string;
}

export class GymClaimRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<GymClaimDoc>(COLLECTIONS.gymClaims);
    await col.createIndex({ gymId: 1, claimantId: 1 });
    await col.createIndex({ status: 1, createdAt: 1 });
    await col.createIndex({ claimantId: 1 });
  }

  public async insert(c: GymClaim): Promise<GymClaim> {
    await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).insertOne({ ...c, _id: c.id });
    return c;
  }

  public async findById(id: string): Promise<GymClaim | null> {
    return stripId<GymClaim>(await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).findOne({ _id: id }));
  }

  public async findPendingByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null> {
    return stripId<GymClaim>(
      await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).findOne({ gymId, claimantId, status: "pending" }),
    );
  }

  public async findLatestByGymAndClaimant(gymId: string, claimantId: string): Promise<GymClaim | null> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ gymId, claimantId })
      .sort({ createdAt: -1 })
      .limit(1)
      .toArray();
    return docs.length > 0 ? (stripId<GymClaim>(docs[0]) as GymClaim) : null;
  }

  public async listByStatus(status: GymClaimStatus): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ status })
      .sort({ createdAt: 1 })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async listByClaimant(claimantId: string): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ claimantId })
      .sort({ createdAt: -1 })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async listPendingByGym(gymId: string): Promise<GymClaim[]> {
    const docs = await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims)
      .find({ gymId, status: "pending" })
      .toArray();
    return docs.map((d) => stripId<GymClaim>(d) as GymClaim);
  }

  public async updateStatus(id: string, patch: Partial<GymClaim>): Promise<GymClaim | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<GymClaimDoc>(COLLECTIONS.gymClaims).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }
}
