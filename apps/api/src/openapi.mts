import {
  AcceptAnswerRequest,
  AddParticipantsRequest,
  Attendee,
  AuthSyncRequest,
  BeltRank,
  BeltPromotion,
  BlockUserRequest,
  CategoryRatings,
  ChannelReadState,
  CheckIn,
  CheckInLocationStatus,
  ClassAttendee,
  ClassAttendeesQuery,
  ClassJournalEntry,
  ClassOccurrence,
  ClassRsvp,
  ClassRsvpRequest,
  ClassType,
  Conversation,
  ConversationKind,
  ConversationListQuery,
  ConversationParticipant,
  ConversationSummary,
  CreateAnswerRequest,
  CreateChannelRequest,
  CreateCheckInRequest,
  CreateClassRequest,
  CreateGroupRequest,
  CreateGymRequest,
  CreateOpenMatRequest,
  CreateQuestionRequest,
  EditMessageRequest,
  ErrorResponse,
  Favorite,
  ForumAnswer,
  ForumCategory,
  ForumListQuery,
  ForumQuestion,
  ForumQuestionDetail,
  Gym,
  GiType,
  GymClass,
  GymLeadRequest,
  GymMembership,
  GymRole,
  HealthResponse,
  InstructorFeedbackItem,
  InstructorFeedbackQuery,
  InstructorRating,
  InstructorRatingSummary,
  JoinMethod,
  JournalRangeQuery,
  LeadResponse,
  ListMeta,
  MembershipStatus,
  Message,
  MessageListQuery,
  MessageReport,
  MessageReportReason,
  MessageReportStatus,
  Notification,
  NotificationType,
  OccurrenceJournalQuery,
  OccurrenceOverrideRequest,
  OpenMat,
  OpenMatDetail,
  ParticipantRole,
  PromoteBeltRequest,
  ReadyResponse,
  ReportMessageRequest,
  ResolveReportRequest,
  ReviewRequest,
  RosterMember,
  RsvpRequest,
  ScheduledClass,
  ScheduleQuery,
  SendMessageRequest,
  SetMutedRequest,
  SkillLevel,
  StartDirectRequest,
  UpdateAnswerRequest,
  UpdateClassRequest,
  UpdateGymRequest,
  UpdateMembershipRequest,
  UpdateMyMembershipRequest,
  UpdateOpenMatRequest,
  UpdateQuestionRequest,
  UpdateUserRequest,
  UpsertInstructorRatingRequest,
  UpsertJournalRequest,
  User,
  UserBlock,
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
  const classIdParam = [{ name: "id", in: "path", required: true, description: "Class ID", schema: { type: "string" } }];
  const classOccurrenceParams = [
    { name: "id", in: "path", required: true, description: "Class ID", schema: { type: "string" } },
    { name: "date", in: "path", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
  ];
  const questionIdParam = [{ name: "id", in: "path", required: true, description: "Question ID", schema: { type: "string" } }];
  const answerIdParam = [{ name: "id", in: "path", required: true, description: "Answer ID", schema: { type: "string" } }];

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
      "/api/v1/gyms/{id}/classes": {
        post: {
          summary: "Create class definition for a gym",
          parameters: gymIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateClassRequest") } } },
          responses: ok(dataOf("GymClass")),
        },
        get: {
          summary: "List class definitions for a gym",
          parameters: gymIdParam,
          responses: ok(listOf("GymClass")),
        },
      },
      "/api/v1/gyms/{id}/schedule": {
        get: {
          summary: "Get gym schedule (expanded occurrences) for a date range",
          parameters: [
            ...gymIdParam,
            { name: "from", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
            { name: "to", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
          ],
          responses: ok(listOf("ScheduledClass")),
        },
      },
      "/api/v1/classes/{id}": {
        patch: {
          summary: "Update a class definition",
          parameters: classIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateClassRequest") } } },
          responses: ok(dataOf("GymClass")),
        },
        delete: {
          summary: "Archive (soft-delete) a class definition",
          parameters: classIdParam,
          responses: { "200": { description: "OK" } },
        },
      },
      "/api/v1/classes/{id}/occurrences/{date}": {
        put: {
          summary: "Override a single occurrence of a class",
          parameters: classOccurrenceParams,
          requestBody: { required: true, content: { "application/json": { schema: ref("OccurrenceOverrideRequest") } } },
          responses: ok(dataOf("ClassOccurrence")),
        },
      },
      "/api/v1/classes/{id}/rsvp": {
        post: {
          summary: "RSVP to a class occurrence",
          parameters: classIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ClassRsvpRequest") } } },
          responses: { "200": { description: "OK" } },
        },
        delete: {
          summary: "Cancel RSVP for a class occurrence",
          parameters: classIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ClassRsvpRequest") } } },
          responses: { "200": { description: "OK" } },
        },
      },
      "/api/v1/classes/{id}/attendees": {
        get: {
          summary: "List attendees for a class occurrence",
          parameters: [
            ...classIdParam,
            { name: "date", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
          ],
          responses: ok(listOf("ClassAttendee")),
        },
      },
      "/api/v1/classes/{id}/journal": {
        post: {
          summary: "Upsert class journal entry for an occurrence",
          parameters: classIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpsertJournalRequest") } } },
          responses: ok(dataOf("ClassJournalEntry")),
        },
        get: {
          summary: "List shared journal entries for a class occurrence",
          parameters: [
            ...classIdParam,
            { name: "date", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
          ],
          responses: ok(listOf("ClassJournalEntry")),
        },
      },
      "/api/v1/users/me/journal": {
        get: {
          summary: "List my journal entries for a date range",
          parameters: [
            { name: "from", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
            { name: "to", in: "query", required: true, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
          ],
          responses: ok(listOf("ClassJournalEntry")),
        },
      },
      "/api/v1/classes/{id}/instructor-rating": {
        post: {
          summary: "Submit or update an instructor rating for a class occurrence",
          parameters: classIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpsertInstructorRatingRequest") } } },
          responses: ok(dataOf("InstructorRating")),
        },
      },
      "/api/v1/users/{id}/instructor-rating": {
        get: {
          summary: "Public instructor rating summary for a user",
          parameters: userIdParam,
          responses: ok(dataOf("InstructorRatingSummary")),
        },
      },
      "/api/v1/gyms/{id}/instructor-feedback": {
        get: {
          summary: "List instructor feedback for a gym (admin/owner)",
          parameters: [
            ...gymIdParam,
            { name: "instructorUserId", in: "query", required: false, description: "Filter by instructor user ID", schema: { type: "string" } },
            { name: "from", in: "query", required: false, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
            { name: "to", in: "query", required: false, description: "ISO YYYY-MM-DD", schema: { type: "string" } },
          ],
          responses: ok(listOf("InstructorFeedbackItem")),
        },
      },
      "/api/v1/gyms/{id}/forum/questions": {
        post: {
          summary: "Post a question to a gym forum",
          parameters: gymIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateQuestionRequest") } } },
          responses: ok(dataOf("ForumQuestion")),
        },
        get: {
          summary: "List forum questions for a gym",
          parameters: [
            ...gymIdParam,
            { name: "category", in: "query", required: false, description: "Filter by category", schema: { type: "string" } },
            { name: "page", in: "query", required: false, schema: { type: "integer" } },
            { name: "limit", in: "query", required: false, schema: { type: "integer" } },
          ],
          responses: ok(listOf("ForumQuestion")),
        },
      },
      "/api/v1/forum/questions/{id}": {
        get: {
          summary: "Get forum question detail (with answers)",
          parameters: questionIdParam,
          responses: ok(dataOf("ForumQuestionDetail")),
        },
        patch: {
          summary: "Update a forum question",
          parameters: questionIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateQuestionRequest") } } },
          responses: ok(dataOf("ForumQuestion")),
        },
        delete: {
          summary: "Delete a forum question",
          parameters: questionIdParam,
          responses: { "200": { description: "OK" } },
        },
      },
      "/api/v1/forum/questions/{id}/answers": {
        post: {
          summary: "Post an answer to a forum question",
          parameters: questionIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateAnswerRequest") } } },
          responses: ok(dataOf("ForumAnswer")),
        },
      },
      "/api/v1/forum/answers/{id}": {
        patch: {
          summary: "Update a forum answer",
          parameters: answerIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("UpdateAnswerRequest") } } },
          responses: ok(dataOf("ForumAnswer")),
        },
        delete: {
          summary: "Delete a forum answer",
          parameters: answerIdParam,
          responses: { "200": { description: "OK" } },
        },
      },
      "/api/v1/forum/questions/{id}/accept": {
        post: {
          summary: "Mark an answer as accepted",
          parameters: questionIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("AcceptAnswerRequest") } } },
          responses: { "200": { description: "OK" } },
        },
      },
      "/api/v1/gyms/{id}/channels": {
        post: {
          summary: "Create a gym channel (admin/owner)",
          parameters: gymIdParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateChannelRequest") } } },
          responses: ok(dataOf("Conversation")),
        },
        get: {
          summary: "List gym channels",
          parameters: gymIdParam,
          responses: ok(listOf("Conversation")),
        },
      },
      "/api/v1/gyms/{id}/message-reports": {
        get: {
          summary: "List message reports for a gym (admin/owner)",
          parameters: [
            ...gymIdParam,
            { name: "status", in: "query", required: false, description: "Filter by report status", schema: { type: "string" } },
          ],
          responses: ok(listOf("MessageReport")),
        },
      },
      "/api/v1/messaging/direct": {
        post: {
          summary: "Start or retrieve a direct conversation",
          requestBody: { required: true, content: { "application/json": { schema: ref("StartDirectRequest") } } },
          responses: ok(dataOf("Conversation")),
        },
      },
      "/api/v1/messaging/groups": {
        post: {
          summary: "Create a group conversation",
          requestBody: { required: true, content: { "application/json": { schema: ref("CreateGroupRequest") } } },
          responses: ok(dataOf("Conversation")),
        },
      },
      "/api/v1/messaging/conversations": {
        get: {
          summary: "List conversations for the current user",
          parameters: [
            { name: "page", in: "query", required: false, schema: { type: "integer" } },
            { name: "limit", in: "query", required: false, schema: { type: "integer" } },
          ],
          responses: ok(listOf("ConversationSummary")),
        },
      },
      "/api/v1/messaging/conversations/{id}/messages": {
        get: {
          summary: "List messages in a conversation",
          parameters: [
            ...idParam,
            { name: "before", in: "query", required: false, description: "Cursor — message ID", schema: { type: "string" } },
            { name: "limit", in: "query", required: false, schema: { type: "integer" } },
          ],
          responses: ok(listOf("Message")),
        },
        post: {
          summary: "Send a message in a conversation",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("SendMessageRequest") } } },
          responses: ok(dataOf("Message")),
        },
      },
      "/api/v1/messaging/conversations/{id}/read": {
        post: {
          summary: "Mark a conversation as read",
          parameters: idParam,
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/conversations/{id}/mute": {
        post: {
          summary: "Mute or unmute a conversation",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("SetMutedRequest") } } },
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/conversations/{id}/leave": {
        post: {
          summary: "Leave a conversation",
          parameters: idParam,
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/conversations/{id}/participants": {
        post: {
          summary: "Add participants to a conversation",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("AddParticipantsRequest") } } },
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/messages/{id}": {
        patch: {
          summary: "Edit a message",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("EditMessageRequest") } } },
          responses: ok(dataOf("Message")),
        },
        delete: {
          summary: "Delete a message",
          parameters: idParam,
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/messages/{id}/report": {
        post: {
          summary: "Report a message",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ReportMessageRequest") } } },
          responses: ok(dataOf("MessageReport")),
        },
      },
      "/api/v1/messaging/reports": {
        post: {
          summary: "Submit a message report",
          requestBody: { required: true, content: { "application/json": { schema: ref("ReportMessageRequest") } } },
          responses: ok(dataOf("MessageReport")),
        },
      },
      "/api/v1/messaging/reports/{id}/resolve": {
        post: {
          summary: "Resolve a message report (admin/owner)",
          parameters: idParam,
          requestBody: { required: true, content: { "application/json": { schema: ref("ResolveReportRequest") } } },
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/blocks": {
        get: {
          summary: "List blocked users",
          responses: ok(listOf("UserBlock")),
        },
        post: {
          summary: "Block a user",
          requestBody: { required: true, content: { "application/json": { schema: ref("BlockUserRequest") } } },
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
        },
      },
      "/api/v1/messaging/blocks/{id}": {
        delete: {
          summary: "Unblock a user",
          parameters: idParam,
          responses: ok({ type: "object", properties: { data: { type: "object", properties: { ok: { type: "boolean" } } } } }),
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
        ClassType,
        GymClass,
        ClassOccurrence,
        ClassRsvp,
        ClassAttendee,
        ScheduledClass,
        CreateClassRequest,
        UpdateClassRequest,
        OccurrenceOverrideRequest,
        ClassRsvpRequest,
        ScheduleQuery,
        ClassAttendeesQuery,
        ClassJournalEntry,
        InstructorRating,
        InstructorRatingSummary,
        InstructorFeedbackItem,
        UpsertJournalRequest,
        UpsertInstructorRatingRequest,
        JournalRangeQuery,
        OccurrenceJournalQuery,
        InstructorFeedbackQuery,
        ForumCategory,
        ForumQuestion,
        ForumAnswer,
        ForumQuestionDetail,
        CreateQuestionRequest,
        UpdateQuestionRequest,
        CreateAnswerRequest,
        UpdateAnswerRequest,
        AcceptAnswerRequest,
        ForumListQuery,
        ConversationKind,
        ParticipantRole,
        MessageReportReason,
        MessageReportStatus,
        Conversation,
        Message,
        ConversationParticipant,
        ChannelReadState,
        UserBlock,
        MessageReport,
        ConversationSummary,
        StartDirectRequest,
        CreateGroupRequest,
        CreateChannelRequest,
        SendMessageRequest,
        EditMessageRequest,
        AddParticipantsRequest,
        SetMutedRequest,
        BlockUserRequest,
        ReportMessageRequest,
        ResolveReportRequest,
        ConversationListQuery,
        MessageListQuery,
      },
    },
  };
}
