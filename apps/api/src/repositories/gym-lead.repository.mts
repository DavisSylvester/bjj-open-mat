import type { Db } from "mongodb";
import type { GymLead } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository } from "./base.repository.mts";

export class GymLeadRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<GymLead>(COLLECTIONS.gymLeads).createIndex({ createdAt: -1 });
  }

  public async insert(lead: GymLead): Promise<void> {
    await this.collection<GymLead>(COLLECTIONS.gymLeads).insertOne(lead);
  }
}
