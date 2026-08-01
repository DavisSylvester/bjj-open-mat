import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import type { Db } from "mongodb";
import type { DeviceToken } from "@bjj/contract";

// Shim for Bun 1.3.x bson v7 compatibility
if (globalThis.process) {
  const originalGetBuiltinModule = globalThis.process.getBuiltinModule as (name: string) => unknown;
  globalThis.process.getBuiltinModule = (name: string): unknown => {
    if (name === "v8") {
      return {
        startupSnapshot: {
          isBuildingSnapshot: () => false,
        },
      };
    }
    return originalGetBuiltinModule?.(name);
  };
}

// Dynamic imports after shim
const { MongoMemoryServer } = await import("mongodb-memory-server");
const { MongoClient } = await import("mongodb");
const { DeviceTokenRepository } = await import("../src/repositories/device-token.repository.mts");

let mongod: unknown;
let client: unknown;
let db: Db;
let repo: InstanceType<typeof DeviceTokenRepository>;

const tok = (id: string, userId: string, token: string): DeviceToken => ({
  id, userId, token, platform: "ios", createdAt: "t",
});

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  const mongoClient = new MongoClient((mongod as {getUri(): string}).getUri());
  client = mongoClient;
  await client.connect();
  db = client.db("test");
  repo = new DeviceTokenRepository(db);
  await repo.ensureIndexes();
});

afterAll(async (): Promise<void> => { await (client as unknown as {close(): Promise<void>}).close(); await (mongod as unknown as {stop(): Promise<void>}).stop(); });

describe("DeviceTokenRepository", () => {
  it("upsertByToken re-points an existing token to a new user", async () => {
    await repo.upsertByToken(tok("d1", "u1", "same-token"));
    await repo.upsertByToken(tok("d2", "u2", "same-token"));
    const forU1 = await repo.listByUser("u1");
    const forU2 = await repo.listByUser("u2");
    expect(forU1).toHaveLength(0);
    expect(forU2).toHaveLength(1);
    expect(forU2[0].token).toBe("same-token");
  });

  it("pruneTokens removes only listed tokens", async () => {
    await repo.upsertByToken(tok("d3", "u3", "keep"));
    await repo.upsertByToken(tok("d4", "u3", "drop"));
    await repo.pruneTokens(["drop"]);
    const rows = await repo.listByUser("u3");
    expect(rows.map((r) => r.token)).toEqual(["keep"]);
  });
});
