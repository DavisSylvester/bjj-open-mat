import type { Db } from "mongodb";
import type { GymLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

interface GymLeadDoc extends GymLead {
  _id: string;
}

export class GymLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<GymLeadDoc>(COLLECTIONS.gymLeads).createIndex({ createdAt: -1 });
  }

  public async insert(lead: GymLead): Promise<void> {
    await this.collection<GymLeadDoc>(COLLECTIONS.gymLeads).insertOne({ ...lead, _id: lead.id });
  }
}
