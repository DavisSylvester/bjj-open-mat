import type { CreateOpenMatBody } from './types.mjs';
import type { GymRef } from './geo-match.mjs';

export interface SessionRef {
  readonly id: string;
  readonly gymId: string;
  readonly dayOfWeek?: number;
  readonly specificDate?: string;
  readonly startTime: string;
}

export interface CreatedSession {
  readonly id: string;
  readonly verified: boolean;
}

export class ApiClient {

  private readonly baseUrl: string;
  private readonly token: string;
  private readonly fetchImpl: typeof fetch;

  public constructor(baseUrl: string, token: string, fetchImpl: typeof fetch = fetch) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.token = token;
    this.fetchImpl = fetchImpl;
  }

  public async gymsNear(lat: number, lng: number, radiusKm: number): Promise<GymRef[]> {
    const url = `${this.baseUrl}/gyms/nearby?lat=${lat}&lng=${lng}&radiusKm=${radiusKm}`;
    const res = await this.fetchImpl(url);
    if (!res.ok) throw new Error(`gymsNear ${res.status}`);
    return ((await res.json()) as { data: GymRef[] }).data;
  }

  public async sessionsForGym(gymId: string): Promise<SessionRef[]> {
    const url = `${this.baseUrl}/open-mats?gymId=${encodeURIComponent(gymId)}&limit=100`;
    const res = await this.fetchImpl(url);
    if (!res.ok) throw new Error(`sessionsForGym ${res.status}`);
    return ((await res.json()) as { data: SessionRef[] }).data;
  }

  public async createSession(body: CreateOpenMatBody): Promise<CreatedSession> {
    const url = `${this.baseUrl}/open-mats`;
    const res = await this.fetchImpl(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${this.token}` },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`createSession ${res.status}: ${await res.text()}`);
    return ((await res.json()) as { data: CreatedSession }).data;
  }
}
