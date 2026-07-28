import type { Db } from "mongodb";
import type { BeltPromotion } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface PromotionDoc extends BeltPromotion {
  _id: string;
}

export class PromotionRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<PromotionDoc>(COLLECTIONS.beltPromotions);
    await col.createIndex({ userId: 1, promotedAt: -1 });
    await col.createIndex({ gymId: 1 });
  }

  public async insert(p: BeltPromotion): Promise<BeltPromotion> {
    await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions).insertOne({ ...p, _id: p.id });
    return p;
  }

  public async listByUser(userId: string): Promise<BeltPromotion[]> {
    const docs = await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions)
      .find({ userId }).sort({ promotedAt: -1 }).toArray();
    return docs.map((d) => stripId<BeltPromotion>(d) as BeltPromotion);
  }

  public async latestForUser(userId: string): Promise<BeltPromotion | null> {
    const docs = await this.collection<PromotionDoc>(COLLECTIONS.beltPromotions)
      .find({ userId }).sort({ promotedAt: -1 }).limit(1).toArray();
    return docs[0] ? (stripId<BeltPromotion>(docs[0]) as BeltPromotion) : null;
  }
}
