import type { Collection, Db, Document } from "mongodb";
// Side-effect import: registers TypeBox string formats (email, uri) so every
// repository's Value.Parse recognizes them.
import "../config/formats.mts";

// Strips Mongo's _id from a fetched doc, returning the domain shape.
export function stripId<T extends Document>(doc: (T & { _id?: unknown }) | null): T | null {
  if (!doc) return null;
  const { _id, ...rest } = doc;
  return rest as unknown as T;
}

export abstract class BaseRepository {
  protected readonly db: Db;

  protected constructor(db: Db) {
    this.db = db;
  }

  protected collection<T extends Document>(name: string): Collection<T> {
    return this.db.collection<T>(name);
  }
}
