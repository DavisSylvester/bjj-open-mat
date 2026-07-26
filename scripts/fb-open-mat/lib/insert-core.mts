import type { CreatedSession } from './api-client.mjs';
import type { ResolvedSession } from './resolve-core.mjs';

export interface InsertApi {
  createSession(body: ResolvedSession): Promise<CreatedSession>;
}

export interface InsertLog {
  planned: number;
  inserted: Array<{ id: string; verified: boolean; gymName: string; sourceUrl: string }>;
  errors: Array<{ gymName: string; sourceUrl: string; error: string }>;
}

export async function insertSessions(sessions: ResolvedSession[], api: InsertApi, commit: boolean): Promise<InsertLog> {
  const log: InsertLog = { planned: sessions.length, inserted: [], errors: [] };
  if (!commit) return log;
  for (const s of sessions) {
    try {
      const created = await api.createSession(s);
      log.inserted.push({ id: created.id, verified: created.verified, gymName: s.gymNameForLog, sourceUrl: s.sourceUrl });
    } catch (e) {
      log.errors.push({ gymName: s.gymNameForLog, sourceUrl: s.sourceUrl, error: e instanceof Error ? e.message : String(e) });
    }
  }
  return log;
}
