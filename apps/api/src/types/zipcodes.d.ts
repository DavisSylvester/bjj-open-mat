// partial — only the symbols this project uses
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
  export function random(): ZipRecord;
}
