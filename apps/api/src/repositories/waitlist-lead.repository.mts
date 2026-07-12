import type { Db } from "mongodb";
import type { WaitlistLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class WaitlistLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<WaitlistLead>(COLLECTIONS.waitlistLeads).createIndex({ email: 1 }, { unique: true });
  }

  // Idempotent: a re-submit of the same email inserts nothing new. Returns true
  // when this call created the record (first sign-up), false when it already existed.
  public async upsertByEmail(lead: WaitlistLead): Promise<boolean> {
    const res = await this.collection<WaitlistLead>(COLLECTIONS.waitlistLeads).updateOne(
      { email: lead.email },
      { $setOnInsert: lead },
      { upsert: true },
    );
    return res.upsertedCount === 1;
  }
}
