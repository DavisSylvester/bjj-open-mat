import { type Db, MongoClient } from "mongodb";
import type { AppEnv } from "../config/env.mts";

export interface MongoContext {
  readonly client: MongoClient;
  readonly db: Db;
}

// v7 driver: timeoutMS applies CSOT across the whole operation chain.
export function createMongoContext(env: AppEnv): MongoContext {
  const client = new MongoClient(env.mongoUri, { timeoutMS: 10_000 });
  const db = client.db(env.mongoDb);
  return { client, db };
}
