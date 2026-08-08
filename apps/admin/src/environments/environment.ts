export const environment = {
  apiBaseUrl: 'http://localhost:3100',
  // Bearer token sent with every admin API call. Empty in the production
  // configuration on purpose: a shipped build must never carry a credential.
  // A deployed portal needs a real Auth0 login instead — see
  // docs/decisions/2026-08-06-admin-api-auth.md.
  devToken: '',
} as const;
