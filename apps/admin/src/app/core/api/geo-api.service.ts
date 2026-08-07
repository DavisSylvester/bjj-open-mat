import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

import { environment } from '../../../environments/environment';
import type { DataEnvelope } from '../models';

export interface ReverseGeocode {
  city: string;
  state: string;
  label: string;
}

/**
 * Browser location, resolved to a US state via the API's geocoder.
 *
 * Kept separate from AdminApiService so the members page depends on "what
 * state am I in" rather than on geolocation plumbing, and so the denied /
 * unavailable paths can be tested without a component.
 */
@Injectable({ providedIn: 'root' })
export class GeoApiService {

  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  public reverse(lat: number, lng: number): Promise<ReverseGeocode> {
    return firstValueFrom(
      this.http.get<DataEnvelope<ReverseGeocode>>(
        `${this.base}/api/v1/geo/reverse`,
        { params: { lat: lat.toString(), lng: lng.toString() } },
      ),
    ).then((res) => res.data);
  }

  /**
   * Best-effort. Resolves null on denial, unavailability, timeout, or an
   * unrecognised location — the caller falls back to alphabetical ordering and
   * surfaces no error, because location is a convenience, not a requirement.
   */
  public async detectState(): Promise<string | null> {
    const position = await this.currentPosition();
    if (!position) return null;
    try {
      const { state } = await this.reverse(position.coords.latitude, position.coords.longitude);
      return state.length > 0 ? state : null;
    } catch {
      return null;
    }
  }

  private currentPosition(): Promise<GeolocationPosition | null> {
    if (!navigator.geolocation) return Promise.resolve(null);
    return new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition(
        (position) => resolve(position),
        () => resolve(null),
        { timeout: 10_000, maximumAge: 300_000 },
      );
    });
  }
}
