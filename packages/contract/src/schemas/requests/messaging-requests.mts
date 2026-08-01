import { type Static, Type as t } from "@sinclair/typebox";
import { MessageReportReason } from "../../enums/message-report-reason.mts";
import { MessageReportStatus } from "../../enums/message-report-status.mts";

export const StartDirectRequest = t.Object({ recipientId: t.String() }, { $id: "StartDirectRequest" });
export type StartDirectRequest = Static<typeof StartDirectRequest>;

export const CreateGroupRequest = t.Object(
  { gymId: t.String(), title: t.String({ minLength: 1 }), participantIds: t.Array(t.String(), { minItems: 1 }) },
  { $id: "CreateGroupRequest" },
);
export type CreateGroupRequest = Static<typeof CreateGroupRequest>;

export const CreateChannelRequest = t.Object({ title: t.String({ minLength: 1 }) }, { $id: "CreateChannelRequest" });
export type CreateChannelRequest = Static<typeof CreateChannelRequest>;

export const SendMessageRequest = t.Object({ body: t.String({ minLength: 1 }) }, { $id: "SendMessageRequest" });
export type SendMessageRequest = Static<typeof SendMessageRequest>;

export const EditMessageRequest = t.Object({ body: t.String({ minLength: 1 }) }, { $id: "EditMessageRequest" });
export type EditMessageRequest = Static<typeof EditMessageRequest>;

export const AddParticipantsRequest = t.Object({ userIds: t.Array(t.String(), { minItems: 1 }) }, { $id: "AddParticipantsRequest" });
export type AddParticipantsRequest = Static<typeof AddParticipantsRequest>;

export const SetMutedRequest = t.Object({ muted: t.Boolean() }, { $id: "SetMutedRequest" });
export type SetMutedRequest = Static<typeof SetMutedRequest>;

export const BlockUserRequest = t.Object({ userId: t.String() }, { $id: "BlockUserRequest" });
export type BlockUserRequest = Static<typeof BlockUserRequest>;

export const ReportMessageRequest = t.Object(
  { messageId: t.Optional(t.String()), reportedUserId: t.String(), reason: MessageReportReason, note: t.Optional(t.String()) },
  { $id: "ReportMessageRequest" },
);
export type ReportMessageRequest = Static<typeof ReportMessageRequest>;

export const ResolveReportRequest = t.Object({ status: MessageReportStatus }, { $id: "ResolveReportRequest" });
export type ResolveReportRequest = Static<typeof ResolveReportRequest>;

export const ConversationListQuery = t.Object(
  // NOTE: query params arrive as STRINGS; Elysia coerces t.Number (not t.Integer)
  // for query. Using t.Integer here made every request 422 "Expected integer".
  { page: t.Optional(t.Number({ minimum: 1, default: 1 })), limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 20 })) },
  { $id: "ConversationListQuery" },
);
export type ConversationListQuery = Static<typeof ConversationListQuery>;

export const MessageListQuery = t.Object(
  { before: t.Optional(t.String()), limit: t.Optional(t.Number({ minimum: 1, maximum: 100, default: 30 })) },
  { $id: "MessageListQuery" },
);
export type MessageListQuery = Static<typeof MessageListQuery>;
