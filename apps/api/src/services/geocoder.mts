import type { GeoLocation } from '@bjj/contract';
import { lookup, lookupByCoords } from 'zipcodes';

export interface Geocoder {
  lookupZip(zip: string): GeoLocation | null;
  reverse(lat: number, lng: number): { city: string; state: string } | null;
}

export class ZipcodesGeocoder implements Geocoder {

  public lookupZip(zip: string): GeoLocation | null {
    const trimmed = zip.trim();
    if (!/^\d{5}$/.test(trimmed)) return null;
    const rec = lookup(trimmed);
    if (!rec || typeof rec.latitude !== 'number' || typeof rec.longitude !== 'number') return null;
    return { lat: rec.latitude, lng: rec.longitude };
  }

  public reverse(lat: number, lng: number): { city: string; state: string } | null {
    const rec = lookupByCoords(lat, lng);
    if (!rec || !rec.city || !rec.state) return null;
    return { city: rec.city, state: rec.state };
  }
}
