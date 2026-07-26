export type GiType = 'gi' | 'nogi' | 'both';
export type SkillLevel = 'all' | 'beginner' | 'intermediate' | 'advanced';

export interface GroupEntry {
  readonly url: string;
  readonly type: 'group' | 'post';
  readonly region: 'US';
}

// A single Facebook post captured by Stage 1 (collect).
export interface RawPost {
  readonly sourceUrl: string;   // permalink to the post
  readonly groupUrl: string;
  readonly author: string;
  readonly postedAt: string;    // ISO timestamp of the post
  readonly text: string;
}

// A structured open-mat candidate produced by Stage 2 (parse).
export interface Candidate {
  readonly sourceUrl: string;
  readonly author: string;
  readonly gymName: string;
  readonly address?: string;
  readonly city?: string;
  readonly state?: string;      // 2-letter US state
  readonly postalCode?: string;
  readonly dayOfWeek?: number;  // 0=Sun..6=Sat (recurring)
  readonly specificDate?: string; // YYYY-MM-DD (one-off)
  readonly isRecurring: boolean;
  readonly startTime: string;   // HH:mm 24h
  readonly endTime: string;     // HH:mm 24h
  readonly giType: GiType;
  readonly skillLevel: SkillLevel;
  readonly feeCents: number;    // 0 = free
  readonly confidence: number;  // 0..1
  readonly rawSnippet: string;
}

// The request body for POST /api/v1/open-mats (matches CreateOpenMatRequest).
export interface CreateOpenMatBody {
  gymId?: string;
  newGym?: {
    name: string;
    address: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  title: string;
  description?: string;
  dayOfWeek?: number;
  startTime: string;
  endTime: string;
  isRecurring?: boolean;
  specificDate?: string;
  skillLevel?: SkillLevel;
  giType?: GiType;
  feeCents?: number;
}
