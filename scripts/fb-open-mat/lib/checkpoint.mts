import { readFileSync, writeFileSync, existsSync } from 'node:fs';

export class CheckpointStore {

  private readonly path: string;
  private data: Record<string, string>;

  public constructor(path: string) {
    this.path = path;
    this.data = existsSync(path) ? (JSON.parse(readFileSync(path, 'utf8')) as Record<string, string>) : {};
  }

  public get(groupUrl: string): string | null {
    return this.data[groupUrl] ?? null;
  }

  public set(groupUrl: string, isoTimestamp: string): void {
    this.data[groupUrl] = isoTimestamp;
  }

  public save(): void {
    writeFileSync(this.path, JSON.stringify(this.data, null, 2));
  }
}
