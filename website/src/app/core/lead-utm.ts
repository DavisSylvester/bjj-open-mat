import type { Utm } from './models/i-lead';

export type FormState = 'idle' | 'submitting' | 'success' | 'error';

// Reads utm_source/medium/campaign from the current URL query (undefined when absent).
export function readUtm(): Utm {
  const p = new URLSearchParams(window.location.search);
  return {
    source: p.get('utm_source') ?? undefined,
    medium: p.get('utm_medium') ?? undefined,
    campaign: p.get('utm_campaign') ?? undefined,
  };
}
