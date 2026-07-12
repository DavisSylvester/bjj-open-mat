import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { LeadApiService } from './lead-api.service';
import { environment } from '../../environments/environment';

describe('LeadApiService', () => {
  let svc: LeadApiService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting(), LeadApiService] });
    svc = TestBed.inject(LeadApiService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('POSTs the waitlist email and unwraps the envelope', async () => {
    const p = svc.joinWaitlist({ email: 'a@b.com' });
    const req = http.expectOne(`${environment.apiBaseUrl}/api/v1/waitlist`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ email: 'a@b.com' });
    req.flush({ data: { status: 'confirmed' } });
    expect((await p).status).toBe('confirmed');
  });

  it('POSTs a gym lead and unwraps the envelope', async () => {
    const p = svc.submitGymLead({ gymName: 'GB', ownerEmail: 'c@g.com' });
    const req = http.expectOne(`${environment.apiBaseUrl}/api/v1/gym-leads`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ gymName: 'GB', ownerEmail: 'c@g.com' });
    req.flush({ data: { status: 'new' } });
    expect((await p).status).toBe('new');
  });
});
