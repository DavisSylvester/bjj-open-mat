import { type Static, Type as t } from "@sinclair/typebox";
import { Value } from "@sinclair/typebox/value";
import type { Db } from "mongodb";
import { User } from "@bjj/contract";
import type { User as UserType } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface UserDoc extends UserType {
  _id: string;
}

const UserDocSchema = t.Composite([User, t.Object({ _id: t.String() })]);
type ParsedUserDoc = Static<typeof UserDocSchema>;

export interface NewUser {
  id: string;
  email: string;
  displayName: string;
  role: UserType["role"];
}

export class UserRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    await col.createIndex({ auth0Id: 1 }, { unique: true, sparse: true });
    await col.createIndex({ email: 1 }, { unique: true });
  }

  public async findById(id: string): Promise<UserType | null> {
    const doc = await this.collection<UserDoc>(COLLECTIONS.users).findOne({ _id: id });
    return stripId<UserType>(doc);
  }

  public async upsertByAuth0Id(auth0Id: string, user: NewUser): Promise<UserType> {
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    const existing = await col.findOne({ auth0Id });
    if (existing) return stripId<UserType>(existing) as UserType;

    const doc: ParsedUserDoc = Value.Parse(UserDocSchema, {
      _id: user.id,
      id: user.id,
      auth0Id,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      amenities: undefined,
      createdAt: new Date().toISOString(),
    });
    await col.insertOne(doc as unknown as UserDoc);
    return stripId<UserType>(doc as unknown as UserDoc) as UserType;
  }

  public async update(id: string, patch: Partial<UserType>): Promise<UserType | null> {
    // MongoDB rejects an empty $set ("'$set' is empty"). Nothing to change -> no-op.
    if (Object.keys(patch).length === 0) return this.findById(id);
    const col = this.collection<UserDoc>(COLLECTIONS.users);
    await col.updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }

  public async insert(user: UserType): Promise<UserType> {
    await this.collection<UserDoc>(COLLECTIONS.users).insertOne({ ...user, _id: user.id });
    return user;
  }
}
