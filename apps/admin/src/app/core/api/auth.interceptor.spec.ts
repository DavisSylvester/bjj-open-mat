import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { authInterceptor } from './auth.interceptor';
import { environment } from '../../../environments/environment';

/** `environment` is declared `as const`; the tests need to vary the token. */
const mutableEnvironment = environment as { devToken: string };

describe('authInterceptor', () => {
  let http: HttpClient;
  let httpMock: HttpTestingController;
  let originalToken: string;

  beforeEach(() => {
    originalToken = environment.devToken;
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    mutableEnvironment.devToken = originalToken;
    httpMock.verify();
  });

  function authHeaderFor(url: string): string | null {
    http.get(url).subscribe({ next: () => undefined, error: () => undefined });
    const req = httpMock.expectOne(url);
    const header: string | null = req.request.headers.get('Authorization');
    req.flush({});
    return header;
  }

  it('attaches the bearer token to a genuine API URL', () => {
    mutableEnvironment.devToken = 'dev-secret';
    expect(authHeaderFor(`${environment.apiBaseUrl}/api/v1/admin/users`)).toBe(
      'Bearer dev-secret',
    );
  });

  it('does NOT attach the token to a look-alike host that shares the base URL prefix', () => {
    mutableEnvironment.devToken = 'dev-secret';
    expect(authHeaderFor('http://localhost:3100.attacker.example/x')).toBeNull();
  });

  it('does NOT attach the token to an unrelated third-party origin', () => {
    mutableEnvironment.devToken = 'dev-secret';
    expect(authHeaderFor('https://attacker.example/api/v1/admin/users')).toBeNull();
  });

  it('does NOT attach the token to a malformed URL', () => {
    mutableEnvironment.devToken = 'dev-secret';
    expect(authHeaderFor('http://[not-a-url/x')).toBeNull();
  });

  it('attaches nothing at all when the token is empty, as in the production build', () => {
    mutableEnvironment.devToken = '';
    expect(authHeaderFor(`${environment.apiBaseUrl}/api/v1/admin/users`)).toBeNull();
  });
});
