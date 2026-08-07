import type { HttpInterceptorFn } from '@angular/common/http';

import { environment } from '../../../environments/environment';

/**
 * Attaches the configured bearer token to admin API calls.
 *
 * `/api/v1/admin/*` requires an admin identity, so without a token the portal
 * gets 401 on every page. In local development `environment.devToken` holds the
 * API's AUTH_BYPASS_SECRET; the production configuration ships an empty token
 * and the header is omitted entirely, because a build served to a browser must
 * not carry a credential.
 *
 * Requests to other origins are left untouched — the token is scoped to the
 * configured API's *origin* so it cannot leak to a third-party host.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token: string = environment.devToken;
  if (token.length === 0) return next(req);
  if (!isApiOrigin(req.url)) return next(req);

  return next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }));
};

/**
 * Origin comparison, not prefix comparison. A prefix test lets a look-alike
 * host (`http://localhost:3100.attacker.example/`) collect the bearer token,
 * because it starts with the configured base URL as a string.
 *
 * A URL that cannot be parsed is treated as foreign: refusing to attach the
 * token is always the safe failure.
 */
function isApiOrigin(url: string): boolean {
  try {
    const base = new URL(environment.apiBaseUrl, location.origin);
    return new URL(url, location.origin).origin === base.origin;
  } catch {
    return false;
  }
}
