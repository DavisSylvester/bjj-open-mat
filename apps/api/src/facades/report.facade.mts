import type { CreateReportRequest, Report } from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { ReportRepository } from "../repositories/report.repository.mts";
import type { GitHubIssueService } from "../services/github-issue.service.mts";

type IdFactory = () => string;

export class ReportFacade {

  public constructor(
    private readonly reports: Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser">,
    private readonly issues: GitHubIssueService | null,
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
}
