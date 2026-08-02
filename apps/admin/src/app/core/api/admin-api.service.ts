import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

import { environment } from '../../../environments/environment';
import type {
  AdminOverviewStats,
  AdminOpenMatsByState,
  CreateGymBody,
  DataEnvelope,
  Gym,
  ListEnvelope,
  OpenMat,
  User,
} from '../models';

@Injectable({ providedIn: 'root' })
export class AdminApiService {

  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  public getOverview(): Promise<AdminOverviewStats> {
    return firstValueFrom(
      this.http.get<DataEnvelope<AdminOverviewStats>>(
        `${this.base}/api/v1/admin/stats/overview`,
      ),
    ).then((res) => res.data);
  }

  public getOpenMatsByState(limit: number = 10): Promise<AdminOpenMatsByState> {
    return firstValueFrom(
      this.http.get<DataEnvelope<AdminOpenMatsByState>>(
        `${this.base}/api/v1/admin/stats/open-mats-by-state`,
        { params: { limit: limit.toString() } },
      ),
    ).then((res) => res.data);
  }

  public listUsers(page: number = 1, limit: number = 50): Promise<ListEnvelope<User>> {
    return firstValueFrom(
      this.http.get<ListEnvelope<User>>(
        `${this.base}/api/v1/admin/users`,
        { params: { page: page.toString(), limit: limit.toString() } },
      ),
    ).then((res) => ({ data: res.data, meta: res.meta }));
  }

  public listGyms(page: number = 1, limit: number = 50): Promise<ListEnvelope<Gym>> {
    return firstValueFrom(
      this.http.get<ListEnvelope<Gym>>(
        `${this.base}/api/v1/admin/gyms`,
        { params: { page: page.toString(), limit: limit.toString() } },
      ),
    ).then((res) => ({ data: res.data, meta: res.meta }));
  }

  public listOpenMats(page: number = 1, limit: number = 50): Promise<ListEnvelope<OpenMat>> {
    return firstValueFrom(
      this.http.get<ListEnvelope<OpenMat>>(
        `${this.base}/api/v1/admin/open-mats`,
        { params: { page: page.toString(), limit: limit.toString() } },
      ),
    ).then((res) => ({ data: res.data, meta: res.meta }));
  }

  public verifyGym(id: string): Promise<Gym> {
    return firstValueFrom(
      this.http.post<DataEnvelope<Gym>>(
        `${this.base}/api/v1/admin/gyms/${id}/verify`,
        {},
      ),
    ).then((res) => res.data);
  }

  public createGym(body: CreateGymBody): Promise<Gym> {
    return firstValueFrom(
      this.http.post<DataEnvelope<Gym>>(
        `${this.base}/api/v1/admin/gyms`,
        body,
      ),
    ).then((res) => res.data);
  }

  public updateGym(id: string, body: Partial<Gym>): Promise<Gym> {
    return firstValueFrom(
      this.http.put<DataEnvelope<Gym>>(
        `${this.base}/api/v1/admin/gyms/${id}`,
        body,
      ),
    ).then((res) => res.data);
  }

  public addOwner(id: string, userId: string): Promise<Gym> {
    return firstValueFrom(
      this.http.post<DataEnvelope<Gym>>(
        `${this.base}/api/v1/admin/gyms/${id}/owner`,
        { userId },
      ),
    ).then((res) => res.data);
  }

  public invite(id: string, emails: string[]): Promise<{ invited: number }> {
    return firstValueFrom(
      this.http.post<DataEnvelope<{ invited: number }>>(
        `${this.base}/api/v1/admin/gyms/${id}/invite`,
        { emails },
      ),
    ).then((res) => res.data);
  }

  public updateOpenMat(id: string, body: Partial<OpenMat>): Promise<OpenMat> {
    return firstValueFrom(
      this.http.put<DataEnvelope<OpenMat>>(
        `${this.base}/api/v1/admin/open-mats/${id}`,
        body,
      ),
    ).then((res) => res.data);
  }
}
