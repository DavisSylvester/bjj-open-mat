import type { Db } from "mongodb";
import type { ForumAnswer } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface AnswerDoc extends ForumAnswer {
  _id: string;
}

export class ForumAnswerRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    const col = this.collection<AnswerDoc>(COLLECTIONS.forumAnswers);
    await col.createIndex({ questionId: 1, createdAt: 1 });
    await col.createIndex({ gymId: 1 });
  }

  public async insert(a: ForumAnswer): Promise<ForumAnswer> {
    await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers).insertOne({ ...a, _id: a.id });
    return a;
  }

  public async findById(id: string): Promise<ForumAnswer | null> {
    return stripId<ForumAnswer>(await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers).findOne({ _id: id }));
  }

  public async listByQuestion(questionId: string): Promise<ForumAnswer[]> {
    const docs = await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers)
      .find({ questionId }).sort({ accepted: -1, createdAt: 1 }).toArray();
    return docs.map((d) => stripId<ForumAnswer>(d) as ForumAnswer);
  }

  public async update(id: string, patch: Partial<ForumAnswer>): Promise<ForumAnswer | null> {
    if (Object.keys(patch).length === 0) return this.findById(id);
    await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers).updateOne({ _id: id }, { $set: patch });
    return this.findById(id);
  }

  public async setAcceptedForQuestion(questionId: string, answerId: string): Promise<void> {
    const col = this.collection<AnswerDoc>(COLLECTIONS.forumAnswers);
    await col.updateMany({ questionId, _id: { $ne: answerId } }, { $set: { accepted: false } });
    await col.updateOne({ _id: answerId }, { $set: { accepted: true } });
  }

  public async clearAcceptedForQuestion(questionId: string): Promise<void> {
    await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers).updateMany({ questionId }, { $set: { accepted: false } });
  }

  public async delete(id: string): Promise<void> {
    await this.collection<AnswerDoc>(COLLECTIONS.forumAnswers).deleteOne({ _id: id });
  }
}
