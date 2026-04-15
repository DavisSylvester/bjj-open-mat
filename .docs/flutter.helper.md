# Flutter Helper — Knowledge Base

Errors encountered during E2E testing and generation. Each entry is appended as issues are found.

```json
{
  "error": "Profile: shows action items — ARIA tree only shows tab bar, not profile screen content (Edit, Favorites, Log Out)",
  "plan": "The Profile screen ListTile widgets are not exposing semantics to the ARIA tree. Add Semantics widgets or ensure the screen has fully rendered before the ARIA snapshot. May need a longer waitForTimeout or explicit semantics labels on ListTile items.",
  "fixed": false,
  "model": "manual-generation",
  "date": "2026-04-14T04:53:00.000Z"
}
```

```json
{
  "error": "API: add favorite gym — POST /api/v1/gyms/:id/favorite returns 404",
  "plan": "The favorites route is not mounted at /api/v1/gyms/:id/favorite. Check the API's favorites endpoint file — the route may be registered under a different path (e.g., /api/v1/favorites or /v1/gyms/:id/favorite). Update the Flutter Endpoints.dart to match the actual API route.",
  "fixed": false,
  "model": "manual-generation",
  "date": "2026-04-14T04:53:00.000Z"
}
```

```json
{
  "error": "API uses /healthz instead of /health — validation check caught wrong health endpoint path",
  "plan": "The generated API has .get('/healthz') but the standard requires /health. Update the codegen system prompt rule and add validation that rejects /healthz. Already added to validate-output.mts.",
  "fixed": false,
  "model": "qwen3-coder-next",
  "date": "2026-04-14T04:53:00.000Z"
}
```

```json
{
  "error": "Open mat and gym IDs parsed as empty string — API returns '_id' but model only checks 'id'",
  "plan": "All fromJson factories must check both 'id' and '_id' fields: json['id'] ?? json['_id'] ?? ''. MongoDB uses _id, the PRD specifies id. Always handle both.",
  "fixed": true,
  "model": "manual-generation",
  "date": "2026-04-14T05:15:00.000Z"
}
```

```json
{
  "error": "All list screens crash with TypeError — API returns paginated {items, total, page} but Dart code casts data['data'] as List",
  "plan": "Never cast response.data['data'] as List directly. Always handle both shapes: data is List ? data : (data is Map ? data['items'] : []). Fixed in: search, training, favorites, my_gyms, session_mgmt, attendance screens.",
  "fixed": true,
  "model": "manual-generation",
  "date": "2026-04-14T15:15:00.000Z"
}
```

```json
{
  "error": "Check-in POST fails with 400 — API expects {openMatId, status} in body even though ID is in URL path",
  "plan": "Send openMatId and status in the request body: api.post(url, data: {'openMatId': id, 'status': 'checked_in'})",
  "fixed": true,
  "model": "manual-generation",
  "date": "2026-04-14T15:15:00.000Z"
}
```
