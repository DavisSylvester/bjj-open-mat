import type { Db } from "mongodb";
import type { WaitlistLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface WaitlistLeadDoc extends WaitlistLead {
  _id: string;
}

export class WaitlistLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<WaitlistLeadDoc>(COLLECTIONS.waitlistLeads).createIndex({ email: 1 }, { unique: true });
  }

  // Idempotent: a re-submit of the same email inserts nothing new. Returns true
  // when this call created the record (first sign-up), false when it already existed.
  public async upsertByEmail(lead: WaitlistLead): Promise<boolean> {
    const res = await this.collection<WaitlistLeadDoc>(COLLECTIONS.waitlistLeads).updateOne(
      { email: lead.email },
      { $setOnInsert: { ...lead, _id: lead.id } },
      { upsert: true },
    );
    return res.upsertedCount === 1;
  }
}
