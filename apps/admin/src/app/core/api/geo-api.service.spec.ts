import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

import { GeoApiService } from './geo-api.service';

const BASE = 'http://localhost:3100';

describe('GeoApiService', () => {
  let service: GeoApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting(), GeoApiService],
    });
    service = TestBed.inject(GeoApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('reverse() unwraps city and state', async () => {
    const promise = service.reverse(33.1, -96.5);
    const req = httpMock.expectOne(`${BASE}/api/v1/geo/reverse?lat=33.1&lng=-96.5`);
    req.flush({ data: { city: 'Van Alstyne', state: 'TX', label: 'Van Alstyne, TX' } });
    await expect(promise).resolves.toEqual({ city: 'Van Alstyne', state: 'TX', label: 'Van Alstyne, TX' });
  });

  it('detectState() resolves null when geolocation is denied', async () => {
    Object.defineProperty(globalThis.navigator, 'geolocation', {
      configurable: true,
      value: {
        getCurrentPosition: (_ok: PositionCallback, fail: PositionErrorCallback): void => {
          fail({ code: 1, message: 'denied' } as GeolocationPositionError);
        },
      },
    });
    await expect(service.detectState()).resolves.toBeNull();
  });

  it('detectState() resolves null when geolocation is unavailable', async () => {
    Object.defineProperty(globalThis.navigator, 'geolocation', { configurable: true, value: undefined });
    await expect(service.detectState()).resolves.toBeNull();
  });
});
