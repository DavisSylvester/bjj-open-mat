// Side-effect shim MUST load before mongodb (see bson-bun-shim.mts). mongodb
// itself is brought in via a dynamic import inside createMongoContext so the
// shim is guaranteed to have run first under Bun.
import "./bson-bun-shim.mjs";
import type { Db, MongoClient } from "mongodb";
import type { AppEnv } from "../config/env.mts";

export interface MongoContext {
  readonly client: MongoClient;
  readonly db: Db;
}

// v7 driver: timeoutMS applies CSOT across the whole operation chain.
export async function createMongoContext(env: AppEnv): Promise<MongoContext> {
  const { MongoClient } = await import("mongodb");
  const client = new MongoClient(env.mongoUri, { timeoutMS: 10_000 });
  const db = client.db(env.mongoDb);
  return { client, db };
}
