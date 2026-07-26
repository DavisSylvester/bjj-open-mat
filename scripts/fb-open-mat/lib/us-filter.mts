const US_STATES: ReadonlySet<string> = new Set([
  'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS',
  'KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY',
  'NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV',
  'WI','WY','DC',
]);

export function isUsState(state: string): boolean {
  return US_STATES.has(state.trim().toUpperCase());
}

export function isUsZip(zip: string): boolean {
  return /^\d{5}$/.test(zip.trim());
}

export function isUsCandidate(c: { state?: string; postalCode?: string }): boolean {
  if (c.state && isUsState(c.state)) return true;
  if (c.postalCode && isUsZip(c.postalCode)) return true;
  return false;
}
