import { lookup } from 'zipcodes';

export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface Geocoder {
  lookupZip(zip: string): GeoPoint | null;
}

export class ZipcodesGeocoder implements Geocoder {

  public lookupZip(zip: string): GeoPoint | null {
    const trimmed = zip.trim();
    if (!/^\d{5}$/.test(trimmed)) return null;
    const rec = lookup(trimmed);
    if (!rec || typeof rec.latitude !== 'number' || typeof rec.longitude !== 'number') return null;
    return { lat: rec.latitude, lng: rec.longitude };
  }
}
