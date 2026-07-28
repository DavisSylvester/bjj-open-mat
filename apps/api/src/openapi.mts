import {
  Attendee,
  AuthSyncRequest,
  BeltRank,
  BeltPromotion,
  CategoryRatings,
  CheckIn,
  CheckInLocationStatus,
  CreateCheckInRequest,
  CreateGymRequest,
  CreateOpenMatRequest,
  ErrorResponse,
  Favorite,
  Gym,
  GiType,
  GymLeadRequest,
  GymMembership,
  GymRole,
  HealthResponse,
  JoinMethod,
  LeadResponse,
  ListMeta,
  MembershipStatus,
  Notification,
  NotificationType,
  OpenMat,
  OpenMatDetail,
  PromoteBeltRequest,
  ReadyResponse,
  ReviewRequest,
  RosterMember,
  RsvpRequest,
  SkillLevel,
  UpdateGymRequest,
  UpdateMembershipRequest,
  UpdateMyMembershipRequest,
  UpdateOpenMatRequest,
  UpdateUserRequest,
  User,
  UserRole,
  UserSettings,
  WaitlistLeadRequest,
} from "@bjj/contract";

export function buildOpenApiDocument(): Record<string, unknown> {
  const ref = (name: string): Record<string, unknown> => ({ $ref: `#/components/schemas/${name}` });
  const dataOf = (name: string): Record<string, unknown> => ({
    type: "object",
    properties: { data: ref(name) },
  });
  const listOf = (name: string): Record<string, unknown> => ({
    type: "object",
    properties: { data: { type: "array", items: ref(name) }, meta: ref("ListMeta") },
  });
  const ok = (schema: Record<string, unknown>): Record<string, unknown> => ({
    "200": { description: "OK", content: { "application/json": { schema } } },
  });
  const idParam = [{ name: "id", in: "path", required: true, schema: { type: "string" } }];
  const gymIdParam = [{ name: "id", in: "path", required: true, description: "Gym ID", schema: { type: "string" } }];
  const userIdParam = [{ name: "id", in: "path", required: true, description: "User ID", schema: { type: "string" } }];
  const memberUserIdParam = [
    { name: "id", in: "path", required: true, description: "Gym ID", schema: { type: "string" } },
    { name: "userId", in: "path", required: true, description: "Member User ID", schema: { type: "string" } },
  ];

  return {
    openapi: "3.1.0",
    info: { title: "BJJ Open Mat API", version: "0.2.0" },
    servers: [{ url: "/" }],
    paths: {
      "/health": { get: { summary: "Liveness", responses: ok(ref("HealthResponse")) } },
      "/ready": { get: { summary: "Readiness", responses: ok(ref("ReadyResponse")) } },
      "/api/v1/auth/me": { get: { summary: "Get-or-create current user", responses: ok(dataOf("User")) } },
      "/api/v1/auth/sync": {
        post: {
          summary: "Sync provider identity (name/email/avatar) for social users",
          requestBody: { required: true, content: { "application/json": { schema: ref("AuthSyncRequest") } } },
          responses: ok(dataOf("User")),
        },
      },
      "/api/v1/users/me": {
        get: { summary: "Current user", responses: ok(dataOf("User")) },
        put: {
          summary: "Update current user",
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateUserRequest") } } },
          responses: ok(dataOf("User")),
        },
      },
      "/api/v1/users/me/settings": {
        get: { summary: "Get settings", responses: ok(dataOf("UserSettings")) },
        put: { summary: "Update settings", responses: ok(dataOf("UserSettings")) },
      },
      "/api/v1/users/{id}": { get: { summary: "Public profile", parameters: idParam, responses: ok(dataOf("User")) } },
      "/api/v1/gyms": {
        get: { summary: "List gyms", responses: ok(listOf("Gym")) },
        post: {
          summary: "Create gym",
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateGymRequest") } } },
          responses: ok(dataOf("Gym")),
        },
      },
      "/api/v1/gyms/nearby": { get: { summary: "Nearby gyms", responses: ok(listOf("Gym")) } },
      "/api/v1/gyms/{id}": {
        get: { summary: "Gym detail", parameters: idParam, responses: ok(dataOf("Gym")) },
        put: {
          summary: "Update gym",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateGymRequest") } } },
          responses: ok(dataOf("Gym")),
        },
      },
      "/api/v1/gyms/{id}/directions": {
        get: { summary: "Directions", parameters: idParam, responses: ok(dataOf("Gym")) },
      },
      "/api/v1/gyms/{id}/favorite": {
        post: { summary: "Add favorite", parameters: idParam, responses: ok(dataOf("Gym")) },
        delete: { summary: "Remove favorite", parameters: idParam, responses: ok(dataOf("Gym")) },
      },
      "/api/v1/open-mats": {
        get: { summary: "List/finder open mats", responses: ok(listOf("OpenMat")) },
        post: {
          summary: "Create open mat",
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateOpenMatRequest") } } },
          responses: ok(dataOf("OpenMatDetail")),
        },
      },
      "/api/v1/open-mats/nearby": { get: { summary: "Nearby open mats", responses: ok(listOf("OpenMat")) } },
      "/api/v1/open-mats/{id}": {
        get: {
          summary: "Open mat detail",
          parameters: idParam,
          responses: { ...ok(dataOf("OpenMatDetail")), "404": { description: "Not found" } },
        },
        put: {
          summary: "Update open mat",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateOpenMatRequest") } } },
          responses: ok(dataOf("OpenMatDetail")),
        },
      },
      "/api/v1/open-mats/{id}/rsvp": {
        post: {
          summary: "RSVP",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("RsvpRequest") } } },
          responses: ok(dataOf("OpenMat")),
        },
        delete: { summary: "Cancel RSVP", parameters: idParam, responses: ok(dataOf("OpenMat")) },
      },
      "/api/v1/open-mats/{id}/attendees": {
        get: { summary: "Attendees", parameters: idParam, responses: ok(listOf("Attendee")) },
      },
      "/api/v1/open-mats/{id}/checkin": {
        post: {
          summary: "Check in",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateCheckInRequest") } } },
          responses: ok(dataOf("CheckIn")),
        },
      },
      "/api/v1/open-mats/{id}/checkins": {
        get: { summary: "Attendance", parameters: idParam, responses: ok(listOf("CheckIn")) },
      },
      "/api/v1/checkins/{id}/review": {
        post: {
          summary: "Submit review",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ReviewRequest") } } },
          responses: ok(dataOf("CheckIn")),
        },
      },
      "/api/v1/users/me/checkins": { get: { summary: "My check-ins", responses: ok(listOf("CheckIn")) } },
      "/api/v1/users/me/favorites": { get: { summary: "My favorite gyms", responses: ok(listOf("Gym")) } },
      "/api/v1/notifications": { get: { summary: "My notifications", responses: ok(listOf("Notification")) } },
      "/api/v1/notifications/{id}/read": {
        post: { summary: "Mark read", parameters: idParam, responses: ok(dataOf("Notification")) },
      },
      "/api/v1/notifications/read-all": { post: { summary: "Mark all read", responses: ok(dataOf("Notification")) } },
      "/api/v1/gyms/{id}/members": {
        post: {
          summary: "Join gym (self-enroll)",
          parameters: gymIdParam,
          responses: ok(dataOf("GymMembership")),
        },
        get: {
          summary: "List gym roster",
          parameters: gymIdParam,
          responses: ok(listOf("RosterMember")),
        },
      },
      "/api/v1/gyms/{id}/members/me": {
        delete: {
          summary: "Leave gym",
          parameters: gymIdParam,
          responses: { "204": { description: "No Content" } },
        },
        patch: {
          summary: "Update my membership preferences (roster visibility, home gym)",
          parameters: gymIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateMyMembershipRequest") } } },
          responses: ok(dataOf("GymMembership")),
        },
      },
      "/api/v1/gyms/{id}/members/{userId}": {
        patch: {
          summary: "Update member (admin/owner — verify, change role)",
          parameters: memberUserIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateMembershipRequest") } } },
          responses: ok(dataOf("GymMembership")),
        },
      },
      "/api/v1/gyms/{id}/members/{userId}/promotions": {
        post: {
          summary: "Record belt promotion for member",
          parameters: memberUserIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("PromoteBeltRequest") } } },
          responses: ok(dataOf("BeltPromotion")),
        },
      },
      "/api/v1/users/{id}/promotions": {
        get: {
          summary: "Belt promotion history for a user",
          parameters: userIdParam,
          responses: ok(listOf("BeltPromotion")),
        },
      },
      "/api/v1/users/me/memberships": {
        get: {
          summary: "My gym memberships",
          responses: ok(listOf("GymMembership")),
        },
      },
      "/api/v1/waitlist": {
        post: {
          summary: "Join the founding waitlist (public)",
          requestBody: { required: true, content: { "application/json": { schema: ref("WaitlistLeadRequest") } } },
          responses: ok(dataOf("LeadResponse")),
        },
      },
      "/api/v1/gym-leads": {
        post: {
          summary: "Submit a gym lead / claim a gym (public)",
          requestBody: { required: true, content: { "application/json": { schema: ref("GymLeadRequest") } } },
          responses: ok(dataOf("LeadResponse")),
        },
      },
    },
    components: {
      schemas: {
        BeltRank,
        SkillLevel,
        GiType,
        UserRole,
        NotificationType,
        User,
        UserSettings,
        Gym,
        OpenMat,
        OpenMatDetail,
        Attendee,
        CheckIn,
        CategoryRatings,
        Favorite,
        Notification,
        ListMeta,
        HealthResponse,
        ReadyResponse,
        ErrorResponse,
        CreateGymRequest,
        UpdateGymRequest,
        CreateOpenMatRequest,
        UpdateOpenMatRequest,
        UpdateUserRequest,
        AuthSyncRequest,
        RsvpRequest,
        CreateCheckInRequest,
        CheckInLocationStatus,
        ReviewRequest,
        WaitlistLeadRequest,
        GymLeadRequest,
        LeadResponse,
        GymRole,
        MembershipStatus,
        JoinMethod,
        GymMembership,
        RosterMember,
        BeltPromotion,
        UpdateMembershipRequest,
        UpdateMyMembershipRequest,
        PromoteBeltRequest,
      },
    },
  };
}
