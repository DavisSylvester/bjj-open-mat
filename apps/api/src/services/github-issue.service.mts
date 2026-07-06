import { AppError } from "../http/errors.mts";

export interface GitHubIssue {
  number: number;
  url: string;
}

export interface CreateIssueInput {
  title: string;
  body: string;
  labels: string[];
}

export interface GitHubIssueService {
  createIssue(input: CreateIssueInput): Promise<GitHubIssue>;
}

interface GitHubIssueResponse {
  number: number;
  html_url: string;
}

/// Files GitHub issues against a configured repository using a personal/app
/// token. Used to mirror in-app reports to the project's issue tracker.
export class HttpGitHubIssueService implements GitHubIssueService {

  public constructor(
    private readonly token: string,
    private readonly repo: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  public async createIssue(input: CreateIssueInput): Promise<GitHubIssue> {
    const url = `https://api.github.com/repos/${this.repo}/issues`;
    const res = await this.fetchFn(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: "application/vnd.github+json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ title: input.title, body: input.body, labels: input.labels }),
    });

    if (res.status < 200 || res.status >= 300) {
      const detail: unknown = await res.text().catch(() => "");
      throw new AppError("service_unavailable", `GitHub issue creation failed (${res.status})`, detail);
    }

    const parsed = (await res.json()) as GitHubIssueResponse;
    return { number: parsed.number, url: parsed.html_url };
  }
}
