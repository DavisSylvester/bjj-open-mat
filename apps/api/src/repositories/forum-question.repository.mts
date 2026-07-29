import type { Db } from "mongodb";
import type { ForumCategory, ForumQuestion } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface QuestionDoc extends ForumQuestion {
  _id: string;
}

export class ForumQuestionRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<QuestionDoc>(COLLECTIONS.forumQuestions);
    await col.createIndex({ gymId: 1, pinned: -1, createdAt: -1 });
    await col.createIndex({ gymId: 1, category: 1 });
  }

  public async insert(q: ForumQuestion): Promise<ForumQuestion> {
    await this.collection<QuestionDoc>(COLLECTIONS.forumQuestions).insertOne({ ...q, _id: q.id });
    return q;
  }

  public async findById(id: string): Promise<ForumQuestion | null> {
    return stripId<ForumQuestion>(await this.collection<QuestionDoc>(COLLECTIONS.forumQuestions).findOne({ _id: id }));
  }

  public async listByGym(
    gymId: string, category: ForumCategory | undefined, skip: number, limit: number,
  ): Promise<{ items: ForumQuestion[]; total: number }> {
    const filter: Record<string, unknown> = { gymId };
    if (category !== undefined) filter["category"] = category;
    const col = this.collection<QuestionDoc>(COLLECTIONS.forumQuestions);
    const [docs, total] = await Promise.all([
      col.find(filter).sort({ pinned: -1, createdAt: -1 }).skip(skip).limit(limit).toArray(),
      col.countDocuments(filter),
    ]);
    return { items: docs.map((d) => stripId<ForumQuestion>(d) as ForumQuestion), total };
  }

  public async update(id: string, patch: Partial<ForumQuestion>): Promise<ForumQuestion | null> {
    const keys = Object.keys(patch);
    if (keys.length === 0) return this.findById(id);

    const $set: Record<string, unknown> = {};
    const $unset: Record<string, unknown> = {};

    for (const key of keys) {
      if (patch[key as keyof ForumQuestion] === undefined) {
        $unset[key] = "";
      } else {
        $set[key] = patch[key as keyof ForumQuestion];
      }
    }

    const updates: Record<string, Record<string, unknown>> = {};
    if (Object.keys($set).length > 0) updates["$set"] = $set;
    if (Object.keys($unset).length > 0) updates["$unset"] = $unset;

    if (Object.keys(updates).length > 0) {
      await this.collection<QuestionDoc>(COLLECTIONS.forumQuestions).updateOne({ _id: id }, updates);
    }

    return this.findById(id);
  }

  public async incAnswerCount(id: string, delta: number): Promise<void> {
    await this.collection<QuestionDoc>(COLLECTIONS.forumQuestions).updateOne({ _id: id }, { $inc: { answerCount: delta } });
  }

  public async delete(id: string): Promise<void> {
    await this.collection<QuestionDoc>(COLLECTIONS.forumQuestions).deleteOne({ _id: id });
  }
}
