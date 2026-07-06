import type { Db } from "mongodb";
import type { Report } from "@bjj/contract";
import { COLLECTIONS } from "../db/collections.mts";
import { BaseRepository, stripId } from "./base.repository.mts";

interface ReportDoc extends Report {
  _id: string;
}

export class ReportRepository extends BaseRepository {
  public constructor(db: Db) {
    super(db);
  }

  public async ensureIndexes(): Promise<void> {
    await this.collection<ReportDoc>(COLLECTIONS.reports).createIndex({ userId: 1, createdAt: -1 });
  }

  public async insert(report: Report): Promise<Report> {
    await this.collection<ReportDoc>(COLLECTIONS.reports).insertOne({ ...report, _id: report.id });
    return report;
  }

  public async update(id: string, patch: Partial<Report>): Promise<Report | null> {
    const doc = await this.collection<ReportDoc>(COLLECTIONS.reports).findOneAndUpdate(
      { _id: id },
      { $set: patch },
      { returnDocument: "after" },
    );
    return stripId<Report>(doc);
  }

  public async findById(id: string): Promise<Report | null> {
    const doc = await this.collection<ReportDoc>(COLLECTIONS.reports).findOne({ _id: id });
    return stripId<Report>(doc);
  }

  public async listByUser(userId: string): Promise<Report[]> {
    const docs = await this.collection<ReportDoc>(COLLECTIONS.reports)
      .find({ userId })
      .sort({ createdAt: -1 })
      .toArray();
    return docs.map((d) => stripId<Report>(d) as Report);
  }
}
