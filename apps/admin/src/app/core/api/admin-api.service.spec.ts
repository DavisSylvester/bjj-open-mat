import { TestBed } from '@angular/core/testing';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

import { AdminApiService } from './admin-api.service';
import type { AdminOverviewStats } from '../models/admin-stats';
import type { User } from '../models/user';

const BASE = 'http://localhost:3100';

describe('AdminApiService', () => {
  let service: AdminApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        AdminApiService,
      ],
    });

    service = TestBed.inject(AdminApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  describe('getOverview()', () => {
    it('should GET the overview endpoint and unwrap data', async () => {
      const mockStats: AdminOverviewStats = {
        signups: {
          today: 1,
          last3Days: 3,
          last7Days: 7,
          last14Days: 14,
          monthToDate: 30,
          yearToDate: 365,
        },
        totalUsers: 100,
        totalGyms: 10,
        totalOpenMats: 50,
      };

      const promise = service.getOverview();

      const req = httpMock.expectOne(`${BASE}/api/v1/admin/stats/overview`);
      expect(req.request.method).toBe('GET');
      req.flush({ data: mockStats });

      const result = await promise;
      expect(result).toEqual(mockStats);
    });
  });

  describe('listUsers()', () => {
    it('should GET users with page and limit query params and return ListEnvelope', async () => {
      const mockUsers: User[] = [
        { id: 'u-1', email: 'a@a.com', displayName: 'Alice' },
      ];
      const mockMeta = { page: 1, limit: 50, total: 1 };

      const promise = service.listUsers(1, 50);

      const req = httpMock.expectOne(
        (r) =>
          r.url === `${BASE}/api/v1/admin/users` &&
          r.params.get('page') === '1' &&
          r.params.get('limit') === '50',
      );
      expect(req.request.method).toBe('GET');
      req.flush({ data: mockUsers, meta: mockMeta });

      const result = await promise;
      expect(result.data).toEqual(mockUsers);
      expect(result.meta).toEqual(mockMeta);
    });

    it('should use default page=1 and limit=50 when called with no args', async () => {
      const promise = service.listUsers();

      const req = httpMock.expectOne(
        (r) =>
          r.url === `${BASE}/api/v1/admin/users` &&
          r.params.get('page') === '1' &&
          r.params.get('limit') === '50',
      );
      req.flush({ data: [], meta: { page: 1, limit: 50, total: 0 } });

      await promise;
    });
  });

  describe('verifyGym()', () => {
    it('should POST to the verify URL and unwrap data', async () => {
      const mockGym = {
        id: 'g-1',
        name: 'Test Gym',
        address: '123 Main St',
        isVerified: true,
      };

      const promise = service.verifyGym('g-1');

      const req = httpMock.expectOne(`${BASE}/api/v1/admin/gyms/g-1/verify`);
      expect(req.request.method).toBe('POST');
      req.flush({ data: mockGym });

      const result = await promise;
      expect(result).toEqual(mockGym);
    });
  });

  describe('getMembersTree()', () => {
    it('should GET the tree endpoint and unwrap data', async () => {
      const tree = { states: [{ state: 'TX', gyms: [] }], noState: [], noGym: { userCount: 3 } };
      const promise = service.getMembersTree();
      const req = httpMock.expectOne(`${BASE}/api/v1/admin/members/tree`);
      expect(req.request.method).toBe('GET');
      req.flush({ data: tree });
      await expect(promise).resolves.toEqual(tree);
    });
  });

  describe('listGymMembers()', () => {
    it('should GET a gym roster with paging params', async () => {
      const promise = service.listGymMembers('g-1', 2, 25);
      const req = httpMock.expectOne(
        `${BASE}/api/v1/admin/gyms/g-1/members?page=2&limit=25`,
      );
      expect(req.request.method).toBe('GET');
      req.flush({ data: [], meta: { page: 2, limit: 25, total: 0 } });
      await expect(promise).resolves.toEqual({ data: [], meta: { page: 2, limit: 25, total: 0 } });
    });
  });

  describe('listNoGymUsers()', () => {
    it('should GET the no-gym endpoint', async () => {
      const promise = service.listNoGymUsers(1, 50);
      const req = httpMock.expectOne(`${BASE}/api/v1/admin/members/no-gym?page=1&limit=50`);
      req.flush({ data: [], meta: { page: 1, limit: 50, total: 0 } });
      await expect(promise).resolves.toEqual({ data: [], meta: { page: 1, limit: 50, total: 0 } });
    });
  });
});
