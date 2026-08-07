export const environment = {
  apiBaseUrl: 'http://localhost:3100',
  // Local development only. Set this to the AUTH_BYPASS_SECRET from
  // apps/api/.env to reach the admin API, which now requires an admin
  // identity. The bypass alone is not enough: the env schema forbids
  // DEMO_USER_ROLE=admin, so the role is read from the database. Point
  // DEMO_USER_ID at a user whose `role` field is "admin".
  //
  // Leave this empty in git. Fill it in locally and do not commit the value.
  devToken: '',
} as const;
