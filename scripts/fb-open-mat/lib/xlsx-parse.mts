import * as XLSX from 'xlsx';
import type { Candidate } from './types.mjs';
import { parseSchedule, parseGiType, parseSkillLevel, parseFeeCents } from './parse.mjs';

function pick(row: Record<string, unknown>, keys: string[]): string {
  for (const k of Object.keys(row)) {
    if (keys.some((want) => k.toLowerCase().includes(want))) {
      const v = row[k];
      if (v != null && String(v).trim() !== '') return String(v).trim();
    }
  }
  return '';
}

export function rowsToCandidates(sheet: XLSX.WorkSheet, sourceUrl: string): Candidate[] {
  const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet);
  const out: Candidate[] = [];
  for (const row of rows) {
    const gymName = pick(row, ['gym', 'name', 'academy']);
    const dayTime = `${pick(row, ['day'])} ${pick(row, ['time', 'schedule', 'when'])}`.trim();
    if (!gymName || !dayTime.trim()) continue;
    const sched = parseSchedule(dayTime);
    if (!sched) continue;
    const blob = `${gymName} ${dayTime} ${pick(row, ['type', 'gi', 'notes'])}`;
    out.push({
      sourceUrl, author: 'group-file',
      gymName,
      address: pick(row, ['address', 'street']) || undefined,
      city: pick(row, ['city']) || undefined,
      state: pick(row, ['state']) || undefined,
      postalCode: pick(row, ['zip', 'postal']) || undefined,
      dayOfWeek: sched.dayOfWeek, specificDate: sched.specificDate,
      isRecurring: sched.isRecurring, startTime: sched.startTime, endTime: sched.endTime,
      giType: parseGiType(blob), skillLevel: parseSkillLevel(blob), feeCents: parseFeeCents(blob),
      confidence: 0.9, rawSnippet: JSON.stringify(row),
    });
  }
  return out;
}
