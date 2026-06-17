import {
  Attendee,
  AttendeesResponse,
  BeltRank,
  HealthResponse,
  OpenMat,
  OpenMatDetail,
  OpenMatListResponse,
  ReadyResponse,
  RsvpRequest,
  RsvpResponse,
  SkillLevel,
} from "@bjj/contract";

// Hand-assembled OpenAPI 3.1 document. The component schemas are the actual
// TypeBox objects from @bjj/contract (TypeBox emits valid JSON Schema), so the
// spec stays in lockstep with the contract package.
export function buildOpenApiDocument(): Record<string, unknown> {
  const json = (ref: string): Record<string, unknown> => ({
    $ref: `#/components/schemas/${ref}`,
  });
  const ok = (ref: string): Record<string, unknown> => ({
    "200": {
      description: "OK",
      content: { "application/json": { schema: json(ref) } },
    },
  });

  return {
    openapi: "3.1.0",
    info: { title: "BJJ Open Mat API", version: "0.1.0" },
    servers: [{ url: "/" }],
    paths: {
      "/health": { get: { summary: "Liveness", responses: ok("HealthResponse") } },
      "/ready": { get: { summary: "Readiness", responses: ok("ReadyResponse") } },
      "/api/v1/open-mats": {
        get: {
          summary: "List open mats (filter by dayOfWeek, sorted by start time)",
          parameters: [
            { name: "dayOfWeek", in: "query", required: false, schema: { type: "integer", minimum: 0, maximum: 6 } },
            { name: "lat", in: "query", required: false, schema: { type: "number" } },
            { name: "lng", in: "query", required: false, schema: { type: "number" } },
            { name: "radiusKm", in: "query", required: false, schema: { type: "integer" } },
          ],
          responses: ok("OpenMatListResponse"),
        },
      },
      "/api/v1/open-mats/{id}": {
        get: {
          summary: "Open mat detail (includes location for directions)",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string" } }],
          responses: { ...ok("OpenMatDetail"), "404": { description: "Not found" } },
        },
      },
      "/api/v1/open-mats/{id}/attendees": {
        get: {
          summary: "List RSVP'd attendees",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string" } }],
          responses: ok("AttendeesResponse"),
        },
      },
      "/api/v1/open-mats/{id}/rsvp": {
        post: {
          summary: "RSVP to an occurrence",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string" } }],
          requestBody: { required: true, content: { "application/json": { schema: json("RsvpRequest") } } },
          responses: ok("RsvpResponse"),
        },
        delete: {
          summary: "Cancel RSVP",
          parameters: [{ name: "id", in: "path", required: true, schema: { type: "string" } }],
          responses: ok("RsvpResponse"),
        },
      },
    },
    components: {
      schemas: {
        BeltRank,
        SkillLevel,
        OpenMat,
        OpenMatDetail,
        Attendee,
        AttendeesResponse,
        RsvpRequest,
        RsvpResponse,
        OpenMatListResponse,
        HealthResponse,
        ReadyResponse,
      },
    },
  };
}
