import type { GiType, SkillLevel } from './types.mjs';

export function parseTime(input: string): string | null {
  const m = input.trim().toLowerCase().match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$/);
  if (!m) return null;
  let hour = Number(m[1]);
  const min = m[2] ? Number(m[2]) : 0;
  const mer = m[3];
  if (hour < 1 || hour > 12 || min > 59) return null;
  if (mer === 'am') hour = hour === 12 ? 0 : hour;
  else hour = hour === 12 ? 12 : hour + 12;
  return `${String(hour).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
}

const DAYS: ReadonlyArray<readonly [RegExp, number]> = [
  [/\bsun(day)?s?\b/i, 0], [/\bmon(day)?s?\b/i, 1], [/\btue(s|sday)?s?\b/i, 2],
  [/\bwed(s|nesday)?s?\b/i, 3], [/\bthu(r|rs|rsday)?s?\b/i, 4],
  [/\bfri(day)?s?\b/i, 5], [/\bsat(urday)?s?\b/i, 6],
];

export function parseDayOfWeek(input: string): number | null {
  for (const [re, n] of DAYS) if (re.test(input)) return n;
  return null;
}

export function parseGiType(input: string): GiType {
  const t = input.toLowerCase();
  const hasNogi = /no[-\s]?gi/.test(t);
  const hasGi = /\bgi\b/.test(t.replace(/no[-\s]?gi/g, ''));
  if (hasNogi && hasGi) return 'both';
  if (hasNogi) return 'nogi';
  if (hasGi) return 'gi';
  return 'both';
}

export function parseSkillLevel(input: string): SkillLevel {
  const t = input.toLowerCase();
  if (/\bbeginner|white belt|fundamental/.test(t)) return 'beginner';
  if (/\badvanced|black belt/.test(t)) return 'advanced';
  if (/\bintermediate/.test(t)) return 'intermediate';
  return 'all';
}

export function parseFeeCents(input: string): number {
  const t = input.toLowerCase();
  if (/\bfree\b/.test(t)) return 0;
  const m = t.match(/\$\s?(\d{1,3})(?:\.(\d{2}))?/);
  if (m) return Number(m[1]) * 100 + (m[2] ? Number(m[2]) : 0);
  return 0;
}

export interface Schedule {
  isRecurring: boolean;
  dayOfWeek?: number;
  specificDate?: string;
  startTime: string;
  endTime: string;
}

function addMinutes(hhmm: string, minutes: number): string {
  const [h, m] = hhmm.split(':').map(Number);
  const total = (h * 60 + m + minutes) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

// Finds "10am-12pm" or "at 10am" and a weekday. Specific ISO dates (YYYY-MM-DD)
// win over weekday and mark the session one-off.
export function parseSchedule(text: string): Schedule | null {
  const range = text.match(/(\d{1,2}(?::\d{2})?\s*(?:am|pm))\s*[-–to]+\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm))/i);
  let startTime: string | null = null;
  let endTime: string | null = null;
  if (range) {
    startTime = parseTime(range[1].replace(/\s+/g, ''));
    endTime = parseTime(range[2].replace(/\s+/g, ''));
  } else {
    const single = text.match(/\b(?:at\s*)?(\d{1,2}(?::\d{2})?\s*(?:am|pm))/i);
    if (single) startTime = parseTime(single[1].replace(/\s+/g, ''));
  }
  if (!startTime) return null;
  if (!endTime) endTime = addMinutes(startTime, 90);

  const isoDate = text.match(/\b(\d{4}-\d{2}-\d{2})\b/);
  if (isoDate) {
    return { isRecurring: false, specificDate: isoDate[1], startTime, endTime };
  }
  const dow = parseDayOfWeek(text);
  return { isRecurring: dow !== null, dayOfWeek: dow ?? undefined, specificDate: undefined, startTime, endTime };
}
