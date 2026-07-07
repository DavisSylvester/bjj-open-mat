import { describe, expect, it } from "bun:test";
import { ReportFacade } from "../src/facades/report.facade.mts";
import type { ReportRepository } from "../src/repositories/report.repository.mts";
import type { GitHubIssueService, GitHubIssue, CreateIssueInput } from "../src/services/github-issue.service.mts";
import type { Report } from "@bjj/contract";

type FakeReportRepo = Pick<ReportRepository, "insert" | "update" | "findById" | "listByUser" | "ensureIndexes">;

function repo(): FakeReportRepo {
  const map = new Map<string, Report>();
  return {
    insert: async (r: Report): Promise<Report> => { map.set(r.id, r); return r; },
    update: async (id: string, patch: Partial<Report>): Promise<Report | null> => {
      const existing = map.get(id);
      if (!existing) return null;
      const updated = { ...existing, ...patch };
      map.set(id, updated);
      return updated;
    },
    findById: async (id: string): Promise<Report | null> => map.get(id) ?? null,
    listByUser: async (userId: string): Promise<Report[]> => [...map.values()].filter((r) => r.userId === userId),
    ensureIndexes: async (): Promise<void> => {},
  };
}

function okIssueService(captured: CreateIssueInput[]): GitHubIssueService {
  return {
    createIssue: async (input: CreateIssueInput): Promise<GitHubIssue> => {
      captured.push(input);
      return { number: 99, url: "https://github.com/DavisSylvester/bjj-open-mat/issues/99" };
    },
  };
}

function failingIssueService(): GitHubIssueService {
  return {
    createIssue: async (): Promise<GitHubIssue> => { throw new Error("boom"); },
  };
}

let n = 0;
const nextId = (): string => `r-${++n}`;

describe("ReportFacade", () => {
  it("saves a bug report, files an issue with 'bug' label, and patches issue fields back", async () => {
    const r = repo();
    const captured: CreateIssueInput[] = [];
    const facade = new ReportFacade(r, okIssueService(captured), null, null, nextId, "DavisSylvester/bjj-open-mat");

    const created = await facade.create("u-1", { type: "bug", title: "Crash on open", description: "It crashes when I open." });

    expect(captured).toHaveLength(1);
    expect(captured[0]?.labels).toEqual(["bug"]);
    expect(created.githubIssueNumber).toBe(99);
    expect(created.githubIssueUrl).toBe("https://github.com/DavisSylvester/bjj-open-mat/issues/99");
    const stored = await r.findById(created.id);
    expect(stored?.githubIssueNumber).toBe(99);
  });

  it("uses the 'enhancement' label for feature reports", async () => {
    const r = repo();
    const captured: CreateIssueInput[] = [];
    const facade = new ReportFacade(r, okIssueService(captured), null, null, nextId, "DavisSylvester/bjj-open-mat");

    await facade.create("u-2", { type: "feature", title: "Add dark mode", description: "Please add a dark theme." });

    expect(captured[0]?.labels).toEqual(["enhancement"]);
  });

  it("still saves the report (no issue fields) when the issue service throws", async () => {
    const r = repo();
    const facade = new ReportFacade(r, failingIssueService(), null, null, nextId, "DavisSylvester/bjj-open-mat");

    const created = await facade.create("u-3", { type: "bug", title: "Bad thing", description: "Something is broken." });

    expect(created.githubIssueNumber).toBeUndefined();
    expect(created.githubIssueUrl).toBeUndefined();
    const stored = await r.findById(created.id);
    expect(stored).not.toBeNull();
    expect(stored?.title).toBe("Bad thing");
  });

  it("still saves the report when no issue service is configured (null)", async () => {
    const r = repo();
    const facade = new ReportFacade(r, null, null, null, nextId, "DavisSylvester/bjj-open-mat");

    const created = await facade.create("u-4", { type: "bug", title: "No token", description: "Mongo only path." });

    expect(created.githubIssueNumber).toBeUndefined();
    const stored = await r.findById(created.id);
    expect(stored).not.toBeNull();
  });

  it("listMine returns only the caller's reports", async () => {
    const r = repo();
    const facade = new ReportFacade(r, null, null, null, nextId, "DavisSylvester/bjj-open-mat");
    await facade.create("owner", { type: "bug", title: "Mine one", description: "Belongs to owner." });
    await facade.create("other", { type: "bug", title: "Not mine", description: "Belongs to other." });

    const mine = await facade.listMine("owner");
    expect(mine).toHaveLength(1);
    expect(mine[0]?.userId).toBe("owner");
  });
});
