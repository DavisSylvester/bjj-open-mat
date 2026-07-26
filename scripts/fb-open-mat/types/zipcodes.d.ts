// Partial ambient declaration for the `zipcodes` package — only the symbols the
// scraper uses. Mirrors apps/api/src/types/zipcodes.d.ts (that shim is scoped to
// the API's tsconfig and not visible here).
declare module 'zipcodes' {
  export interface ZipRecord {
    zip: string;
    latitude: number;
    longitude: number;
    city: string;
    state: string;
    country: string;
  }

  export function lookup(zip: string | number): ZipRecord | undefined;
  export function lookupByCoords(lat: number, lon: number): ZipRecord | null;
}
