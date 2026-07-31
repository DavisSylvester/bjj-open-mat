import type { Db } from "mongodb";
import type { MessageReport, MessageReportStatus } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ReportDoc extends MessageReport {
  _id: string;
}

export class MessageReportRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).createIndex({ gymId: 1, status: 1, createdAt: -1 });
  }

  public async insert(r: MessageReport): Promise<MessageReport> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).insertOne({ ...r, _id: r.id });
    return r;
  }

  public async findById(id: string): Promise<MessageReport | null> {
    return stripId<MessageReport>(await this.collection<ReportDoc>(COLLECTIONS.messageReports).findOne({ _id: id }));
  }

  public async listByGym(gymId: string, status: MessageReportStatus | undefined): Promise<MessageReport[]> {
    const filter: Record<string, unknown> = { gymId };
    if (status !== undefined) filter["status"] = status;
    const docs = await this.collection<ReportDoc>(COLLECTIONS.messageReports).find(filter).sort({ createdAt: -1 }).toArray();
    return docs.map((d) => stripId<MessageReport>(d) as MessageReport);
  }

  public async updateStatus(id: string, status: MessageReportStatus, reviewedAt: string): Promise<void> {
    await this.collection<ReportDoc>(COLLECTIONS.messageReports).updateOne({ _id: id }, { $set: { status, reviewedAt } });
  }
}
