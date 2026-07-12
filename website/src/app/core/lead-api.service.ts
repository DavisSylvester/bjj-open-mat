import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom, map } from 'rxjs';
import { environment } from '../../environments/environment';
import type { GymLeadRequest, LeadResponse, WaitlistRequest } from './models/i-lead';

interface Envelope<T> { data: T; }

@Injectable({ providedIn: 'root' })
export class LeadApiService {

  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  public joinWaitlist(req: WaitlistRequest): Promise<LeadResponse> {
    return firstValueFrom(
      this.http.post<Envelope<LeadResponse>>(`${this.base}/api/v1/waitlist`, req).pipe(map((e) => e.data)),
    );
  }

  public submitGymLead(req: GymLeadRequest): Promise<LeadResponse> {
    return firstValueFrom(
      this.http.post<Envelope<LeadResponse>>(`${this.base}/api/v1/gym-leads`, req).pipe(map((e) => e.data)),
    );
  }
}
