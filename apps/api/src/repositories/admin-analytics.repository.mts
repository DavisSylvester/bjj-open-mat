// apps/api/src/repositories/admin-analytics.repository.mts
import type { Db } from "mongodb";
import type { SignupWindows, StateOpenMatCount } from "@bjj/contract";
import { BaseRepository } from "./base.repository.mjs";
import { COLLECTIONS } from "../db/collections.mjs";

interface UserCreatedDoc {
  readonly createdAt?: string;
}

export class AdminAnalyticsRepository extends BaseRepository {

  public constructor(db: Db) {
    super(db);
  }

  private startOfUtcDay(now: Date): Date {
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  }

  private daysAgo(now: Date, days: number): Date {
    return new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  }

  /**
   * Returns signup counts for several time windows relative to `now`.
   *
   * - `today`          — from midnight UTC of the current day (`startOfUtcDay`)
   * - `last3Days`      — rolling 3-day window (N × 24 h back via `daysAgo`)
   * - `last7Days`      — rolling 7-day window
   * - `last14Days`     — rolling 14-day window
   * - `monthToDate`    — from the 1st of the current calendar month (UTC)
   * - `yearToDate`     — from 1 Jan of the current calendar year (UTC)
   */
  public async signupWindows(now: Date): Promise<SignupWindows> {
    const col = this.collection<UserCreatedDoc>(COLLECTIONS.users);
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
    const yearStart = new Date(Date.UTC(now.getUTCFullYear(), 0, 1)).toISOString();
    const since = async (iso: string): Promise<number> =>
      col.countDocuments({ createdAt: { $gte: iso } });
    const [today, last3Days, last7Days, last14Days, monthToDate, yearToDate] = await Promise.all([
      since(this.startOfUtcDay(now).toISOString()),
      since(this.daysAgo(now, 3).toISOString()),
      since(this.daysAgo(now, 7).toISOString()),
      since(this.daysAgo(now, 14).toISOString()),
      since(monthStart),
      since(yearStart),
    ]);
    return { today, last3Days, last7Days, last14Days, monthToDate, yearToDate };
  }

  public async totals(): Promise<{ totalUsers: number; totalGyms: number; totalOpenMats: number }> {
    const [totalUsers, totalGyms, totalOpenMats] = await Promise.all([
      this.collection(COLLECTIONS.users).countDocuments({}),
      this.collection(COLLECTIONS.gyms).countDocuments({}),
      this.collection(COLLECTIONS.openMats).countDocuments({}),
    ]);
    return { totalUsers, totalGyms, totalOpenMats };
  }

  public async topStates(limit: number): Promise<StateOpenMatCount[]> {
    const rows = await this.collection(COLLECTIONS.openMats)
      .aggregate<{ _id: string; count: number }>([
        { $lookup: { from: COLLECTIONS.gyms, localField: "gymId", foreignField: "_id", as: "gym" } },
        { $unwind: "$gym" },
        { $match: { "gym.state": { $type: "string", $ne: "" } } },
        { $group: { _id: "$gym.state", count: { $sum: 1 } } },
        { $sort: { count: -1, _id: 1 } },
        { $limit: limit },
      ])
      .toArray();
    return rows.map((r) => ({ state: r._id, count: r.count }));
  }
}
