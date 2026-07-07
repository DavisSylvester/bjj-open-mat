import type { CreateReportRequest, Report } from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { ReportRepository } from "../repositories/report.repository.mts";
import type { GitHubIssueService } from "../services/github-issue.service.mts";
import type { AudioStorage } from "../services/audio-storage.mts";
import type { TranscriptionService } from "../services/transcription.mts";
import { AppError } from "../http/errors.mts";

type IdFactory = () => string;

export class ReportFacade {

  public constructor(
    private readonly reports: Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser">,
    private readonly issues: GitHubIssueService | null,
    private readonly audio: AudioStorage | null,
    private readonly transcription: TranscriptionService | null,
    private readonly newId: IdFactory,
    private readonly repo: string,
  ) {}

  public async create(userId: string, req: CreateReportRequest): Promise<Report> {
    const report: Report = {
      id: this.newId(),
      userId,
      type: req.type,
      title: req.title,
      description: req.description,
      status: "open",
      createdAt: new Date().toISOString(),
      audioKeys: req.audioKeys ?? [],
    };
    await this.reports.insert(report);

    if (!this.issues) return report;

    const label = req.type === "feature" ? "enhancement" : "bug";
    const kind = req.type === "feature" ? "Feature" : "Bug";
    try {
      const issue = await this.issues.createIssue({
        title: `[${kind}] ${req.title}`,
        body: `${req.description}\n\nReported by ${userId}`,
        labels: [label],
      });
      const patched = await this.reports.update(report.id, {
        githubIssueNumber: issue.number,
        githubIssueUrl: issue.url,
      });
      return patched ?? { ...report, githubIssueNumber: issue.number, githubIssueUrl: issue.url };
    } catch (err: unknown) {
      logger.warn(`Failed to file GitHub issue for report ${report.id} in ${this.repo}`, { err });
      return report;
    }
  }

  public async listMine(userId: string): Promise<Report[]> {
    return this.reports.listByUser(userId);
  }

  public async transcribe(userId: string, audioKey: string): Promise<{ text: string; durationMs: number }> {
    if (!this.audio || !this.transcription) {
      throw new AppError("service_unavailable", "Voice transcription is not configured");
    }
    if (!audioKey.startsWith(`reports/audio/${userId}/`)) {
      throw new AppError("not_found", "Audio not found");
    }
    const bytes = await this.audio.getObject(audioKey);
    return this.transcription.translateToEnglish(bytes, "audio.m4a");
  }
}
