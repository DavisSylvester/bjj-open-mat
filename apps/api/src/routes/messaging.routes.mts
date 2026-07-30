import { Elysia } from "elysia";
import {
  AddParticipantsRequest,
  BlockUserRequest,
  ConversationListQuery,
  CreateChannelRequest,
  CreateGroupRequest,
  EditMessageRequest,
  MessageListQuery,
  MessageReportStatus,
  ReportMessageRequest,
  ResolveReportRequest,
  SendMessageRequest,
  SetMutedRequest,
  StartDirectRequest,
} from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { authPlugin } from "../auth/auth.middleware.mts";
import type { Container } from "../container.mts";
import { AppError } from "../http/errors.mts";
import { data, list } from "../http/envelope.mts";

function requireId(identity: AuthIdentity | null): AuthIdentity {
  if (!identity) throw new AppError("unauthorized", "Authentication required");
  return identity;
}

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function messagingRoutes(container: Container) {
  const { messagingFacade } = container;

  // Gym-scoped messaging routes: channel create/list + message-reports list
  const gymMessagingRoutes = new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/:id/channels",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.createChannel(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: CreateChannelRequest },
    )
    .get(
      "/:id/channels",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.listChannels(caller.userId, params.id, caller.role));
      },
      { requireAuth: true },
    )
    .get(
      "/:id/message-reports",
      async ({ identity, params, query }) => {
        const caller = requireId(identity);
        const items = await messagingFacade.listReports(caller.userId, params.id, query.status, caller.role);
        return list(items, { page: 1, limit: items.length, total: items.length });
      },
      { requireAuth: true, query: MessageReportStatus },
    );

  // Messaging-scoped routes: direct, groups, conversations, messages, blocks, reports
  const messagingDetailRoutes = new Elysia({ prefix: "/api/v1/messaging" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/direct",
      async ({ identity, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.startDirect(caller.userId, body.recipientId, caller.role));
      },
      { requireAuth: true, body: StartDirectRequest },
    )
    .post(
      "/groups",
      async ({ identity, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.createGroup(caller.userId, body.gymId, body, caller.role));
      },
      { requireAuth: true, body: CreateGroupRequest },
    )
    .get(
      "/conversations",
      async ({ identity, query }) => {
        const caller = requireId(identity);
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const result = await messagingFacade.listConversations(caller.userId, caller.role, page, limit);
        return list(result.items, { page, limit, total: result.total });
      },
      { requireAuth: true, query: ConversationListQuery },
    )
    .get(
      "/conversations/:id/messages",
      async ({ identity, params, query }) => {
        const caller = requireId(identity);
        const limit = query.limit ?? 30;
        const items = await messagingFacade.getMessages(caller.userId, params.id, query, caller.role);
        return list(items, { page: 1, limit, total: items.length });
      },
      { requireAuth: true, query: MessageListQuery },
    )
    .post(
      "/conversations/:id/messages",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.sendMessage(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: SendMessageRequest },
    )
    .post(
      "/conversations/:id/read",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await messagingFacade.markRead(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .post(
      "/conversations/:id/mute",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await messagingFacade.setMuted(caller.userId, params.id, body.muted, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true, body: SetMutedRequest },
    )
    .post(
      "/conversations/:id/leave",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await messagingFacade.leaveConversation(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .post(
      "/conversations/:id/participants",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await messagingFacade.addParticipants(caller.userId, params.id, body, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true, body: AddParticipantsRequest },
    )
    .patch(
      "/messages/:id",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.editMessage(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: EditMessageRequest },
    )
    .delete(
      "/messages/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await messagingFacade.deleteMessage(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .post(
      "/messages/:id/report",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.reportMessage(caller.userId, { ...body, messageId: params.id }));
      },
      { requireAuth: true, body: ReportMessageRequest },
    )
    .post(
      "/reports",
      async ({ identity, body }) => {
        const caller = requireId(identity);
        return data(await messagingFacade.reportMessage(caller.userId, body));
      },
      { requireAuth: true, body: ReportMessageRequest },
    )
    .post(
      "/reports/:id/resolve",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await messagingFacade.resolveReport(caller.userId, params.id, body, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true, body: ResolveReportRequest },
    )
    .get(
      "/blocks",
      async ({ identity }) => {
        const caller = requireId(identity);
        const ids = await messagingFacade.listBlocks(caller.userId);
        const items = ids.map((blockedId: string) => ({ blockedId }));
        return list(items, { page: 1, limit: items.length, total: items.length });
      },
      { requireAuth: true },
    )
    .post(
      "/blocks",
      async ({ identity, body }) => {
        const caller = requireId(identity);
        await messagingFacade.blockUser(caller.userId, body.userId);
        return data({ ok: true });
      },
      { requireAuth: true, body: BlockUserRequest },
    )
    .delete(
      "/blocks/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await messagingFacade.unblockUser(caller.userId, params.id);
        return data({ ok: true });
      },
      { requireAuth: true },
    );

  return new Elysia()
    .use(gymMessagingRoutes)
    .use(messagingDetailRoutes);
}
