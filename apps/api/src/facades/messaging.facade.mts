// apps/api/src/facades/messaging.facade.mts
import type {
  AddParticipantsRequest, Conversation, ConversationParticipant, ConversationSummary, CreateChannelRequest, CreateGroupRequest,
  EditMessageRequest, Gym, GymMembership, Message, MessageListQuery, MessageReport, MessageReportStatus,
  ReportMessageRequest, ResolveReportRequest, SendMessageRequest, UserRole,
} from "@bjj/contract";
import { AppError } from "../http/errors.mts";
import { assertActiveMember, assertCanManageGym } from "./gym-authz.mts";
import type { ConversationRepository } from "../repositories/conversation.repository.mts";
import type { MessageRepository } from "../repositories/message.repository.mts";
import type { ConversationParticipantRepository } from "../repositories/conversation-participant.repository.mts";
import type { ChannelReadStateRepository } from "../repositories/channel-read-state.repository.mts";
import type { UserBlockRepository } from "../repositories/user-block.repository.mts";
import type { MessageReportRepository } from "../repositories/message-report.repository.mts";
import type { MembershipRepository } from "../repositories/membership.repository.mts";
import type { GymRepository } from "../repositories/gym.repository.mts";
import type { UserRepository } from "../repositories/user.repository.mts";
import type { PushNotifier } from "../push/push.types.mts";

type IdFactory = () => string;

type ConvRepo = Pick<ConversationRepository, "insert" | "findById" | "findDirectByPairKey" | "listChannelsByGym" | "updateLastMessage" | "update" | "delete">;
type MsgRepo = Pick<MessageRepository, "insert" | "findById" | "listByConversation" | "latestForConversation" | "countAfter" | "softDelete" | "update">;
type PartRepo = Pick<ConversationParticipantRepository, "insertMany" | "find" | "listByConversation" | "listActiveForUser" | "setLastReadAt" | "setMuted" | "setLeftAt">;
type ReadRepo = Pick<ChannelReadStateRepository, "find" | "upsertLastReadAt" | "upsertMuted">;
type BlockRepo = Pick<UserBlockRepository, "insert" | "existsEitherWay" | "listBlockedBy" | "deleteByBlocked">;
type ReportRepo = Pick<MessageReportRepository, "insert" | "findById" | "listByGym" | "updateStatus">;
type MemberRepo = Pick<MembershipRepository, "find" | "listByUser">;
type GymRepo = Pick<GymRepository, "findById">;
type UserRepo = Pick<UserRepository, "findById">;

export class MessagingFacade {

  public constructor(
    private readonly conversations: ConvRepo,
    private readonly messages: MsgRepo,
    private readonly participants: PartRepo,
    private readonly channelReads: ReadRepo,
    private readonly blocks: BlockRepo,
    private readonly reports: ReportRepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly users: UserRepo,
    private readonly push: PushNotifier,
    private readonly newId: IdFactory,
  ) {}

  private authzDeps(): { gyms: GymRepo; memberships: MemberRepo } {
    return { gyms: this.gyms, memberships: this.memberships };
  }

  private pairKeyOf(a: string, b: string): string {
    return [a, b].sort().join("|");
  }

  private async sharesActiveGym(a: string, b: string): Promise<boolean> {
    const [am, bm] = await Promise.all([this.memberships.listByUser(a), this.memberships.listByUser(b)]);
    const bActive: Set<string> = new Set(bm.filter((m: GymMembership) => m.status === "active").map((m) => m.gymId));
    return am.some((m: GymMembership) => m.status === "active" && bActive.has(m.gymId));
  }

  public async startDirect(userId: string, recipientId: string, _role: UserRole): Promise<Conversation> {
    if (userId === recipientId) throw new AppError("bad_request", "Cannot message yourself");
    if (await this.blocks.existsEitherWay(userId, recipientId)) throw new AppError("forbidden", "Messaging is blocked");
    if (!(await this.sharesActiveGym(userId, recipientId))) throw new AppError("forbidden", "You do not share a gym");
    const pairKey: string = this.pairKeyOf(userId, recipientId);
    const existing: Conversation | null = await this.conversations.findDirectByPairKey(pairKey);
    if (existing) return existing;
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "direct", pairKey, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    const rows: ConversationParticipant[] = [userId, recipientId].map((uid) => ({
      id: this.newId(), conversationId: conv.id, userId: uid, role: "member", muted: false,
    }));
    await this.participants.insertMany(rows);
    return conv;
  }

  public async createGroup(userId: string, gymId: string, req: CreateGroupRequest, role: UserRole): Promise<Conversation> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    const others: string[] = [...new Set(req.participantIds)].filter((id) => id !== userId);
    for (const pid of others) {
      const m: GymMembership | null = await this.memberships.find(gymId, pid);
      if (!m || m.status !== "active") throw new AppError("forbidden", `User ${pid} is not a member of this gym`);
    }
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "group", gymId, title: req.title, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    const rows: ConversationParticipant[] = [
      { id: this.newId(), conversationId: conv.id, userId, role: "admin", muted: false },
      ...others.map((uid) => ({ id: this.newId(), conversationId: conv.id, userId: uid, role: "member" as const, muted: false })),
    ];
    await this.participants.insertMany(rows);
    return conv;
  }

  public async createChannel(userId: string, gymId: string, req: CreateChannelRequest, role: UserRole): Promise<Conversation> {
    await assertCanManageGym(this.authzDeps(), userId, gymId, role);
    const now: string = new Date().toISOString();
    const conv: Conversation = { id: this.newId(), kind: "gym_channel", gymId, title: req.title, createdBy: userId, createdAt: now };
    await this.conversations.insert(conv);
    return conv;
  }

  public async listChannels(userId: string, gymId: string, role: UserRole): Promise<Conversation[]> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    let channels: Conversation[] = await this.conversations.listChannelsByGym(gymId);
    if (channels.length === 0) {
      const gym: Gym | null = await this.gyms.findById(gymId);
      const now: string = new Date().toISOString();
      const general: Conversation = { id: this.newId(), kind: "gym_channel", gymId, title: "General", createdBy: gym?.ownerId ?? userId, createdAt: now };
      await this.conversations.insert(general);
      channels = [general];
    }
    return channels;
  }

  private async assertAccess(userId: string, conv: Conversation, role: UserRole): Promise<void> {
    if (conv.kind === "gym_channel") {
      if (!conv.gymId) throw new AppError("not_found", "gym_channel missing gymId");
      await assertActiveMember(this.authzDeps(), userId, conv.gymId, role);
      return;
    }
    const p = await this.participants.find(conv.id, userId);
    if (!p || p.leftAt) throw new AppError("forbidden", "You are not a participant");
  }

  private async unreadFor(userId: string, conv: Conversation): Promise<number> {
    if (conv.kind === "gym_channel") {
      const state = await this.channelReads.find(conv.id, userId);
      return this.messages.countAfter(conv.id, state?.lastReadAt);
    }
    const p = await this.participants.find(conv.id, userId);
    return this.messages.countAfter(conv.id, p?.lastReadAt);
  }

  private async otherParticipantIds(userId: string, conv: Conversation): Promise<string[]> {
    if (conv.kind === "gym_channel") return [];
    const rows = await this.participants.listByConversation(conv.id);
    return rows.filter((p) => p.userId !== userId).map((p) => p.userId);
  }

  public async listConversations(
    userId: string, role: UserRole, page: number, limit: number,
  ): Promise<{ items: ConversationSummary[]; total: number }> {
    const partRows = await this.participants.listActiveForUser(userId);
    const direct: Conversation[] = [];
    for (const row of partRows) {
      const c = await this.conversations.findById(row.conversationId);
      if (c) direct.push(c);
    }
    // gym channels for gyms where the user is an active member
    const memberships = await this.memberships.listByUser(userId);
    const activeGymIds = memberships.filter((m) => m.status === "active").map((m) => m.gymId);
    const channels: Conversation[] = [];
    for (const gymId of activeGymIds) {
      const list = await this.conversations.listChannelsByGym(gymId);
      channels.push(...list);
    }
    const all = [...direct, ...channels];
    const summaries = await Promise.all(all.map(async (conv) => {
      const [unreadCount, lastMessage] = await Promise.all([this.unreadFor(userId, conv), this.messages.latestForConversation(conv.id)]);
      let muted = false;
      if (conv.kind === "gym_channel") muted = (await this.channelReads.find(conv.id, userId))?.muted ?? false;
      else muted = (await this.participants.find(conv.id, userId))?.muted ?? false;
      const others = await this.otherParticipantIds(userId, conv);
      const otherParticipants = await Promise.all(
        others.map(async (uid) => ({
          userId: uid,
          displayName: (await this.users.findById(uid))?.displayName ?? "Member",
        })),
      );
      return { conversation: conv, unreadCount, muted, lastMessage: lastMessage ?? undefined, otherParticipantIds: others, otherParticipants };
    }));
    summaries.sort((a, b) => (b.conversation.lastMessageAt ?? "").localeCompare(a.conversation.lastMessageAt ?? ""));
    const total = summaries.length;
    const startIdx = (page - 1) * limit;
    return { items: summaries.slice(startIdx, startIdx + limit), total };
  }

  public async getMessages(userId: string, conversationId: string, req: MessageListQuery, role: UserRole): Promise<Message[]> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    const limit: number = req.limit ?? 30;
    const list = await this.messages.listByConversation(conversationId, req.before, limit);
    const blocked = new Set(await this.blocks.listBlockedBy(userId));
    const visible = list.filter((m) => !blocked.has(m.authorId));
    // mark read
    const now: string = new Date().toISOString();
    if (conv.kind === "gym_channel") await this.channelReads.upsertLastReadAt(conversationId, userId, now, this.newId());
    else await this.participants.setLastReadAt(conversationId, userId, now);
    return visible;
  }

  public async sendMessage(userId: string, conversationId: string, req: SendMessageRequest, role: UserRole): Promise<Message> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    if (conv.kind === "direct") {
      const other = (await this.participants.listByConversation(conversationId)).map((p) => p.userId).find((u) => u !== userId);
      if (other && await this.blocks.existsEitherWay(userId, other)) throw new AppError("forbidden", "Messaging is blocked");
    }
    const now: string = new Date().toISOString();
    const message: Message = { id: this.newId(), conversationId, authorId: userId, body: req.body, createdAt: now };
    await this.messages.insert(message);
    await this.conversations.updateLastMessage(conversationId, now, req.body.slice(0, 140));
    const parts = await this.participants.listByConversation(conversationId);
    const recipientIds: string[] = [];
    for (const p of parts) {
      if (p.userId === userId || p.leftAt || p.muted) continue;
      if (await this.blocks.existsEitherWay(userId, p.userId)) continue;
      recipientIds.push(p.userId);
    }
    if (recipientIds.length > 0) {
      const sender = await this.users.findById(userId);
      await this.push.pushToUsers(recipientIds, {
        title: sender?.displayName ?? "New message",
        body: req.body,
        data: { type: "message", conversationId },
      });
    }
    return message;
  }

  public async editMessage(userId: string, messageId: string, req: EditMessageRequest, _role: UserRole): Promise<Message> {
    const m = await this.messages.findById(messageId);
    if (!m) throw new AppError("not_found", `Message ${messageId} not found`);
    if (m.authorId !== userId) throw new AppError("forbidden", "Only the author can edit");
    return (await this.messages.update(messageId, { body: req.body, editedAt: new Date().toISOString() })) as Message;
  }

  public async deleteMessage(userId: string, messageId: string, role: UserRole): Promise<void> {
    const m = await this.messages.findById(messageId);
    if (!m) throw new AppError("not_found", `Message ${messageId} not found`);
    if (m.authorId !== userId) {
      const conv = await this.conversations.findById(m.conversationId);
      if (!conv || conv.kind === "direct" || !conv.gymId) throw new AppError("forbidden", "Cannot delete this message");
      await assertCanManageGym(this.authzDeps(), userId, conv.gymId, role);
    }
    await this.messages.softDelete(messageId, new Date().toISOString());
  }

  public async addParticipants(userId: string, conversationId: string, req: AddParticipantsRequest, _role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind !== "group") throw new AppError("bad_request", "Only group conversations take participants");
    if (!conv.gymId) throw new AppError("not_found", "Group has no gym association");
    const caller = await this.participants.find(conversationId, userId);
    if (!caller || caller.role !== "admin" || caller.leftAt) throw new AppError("forbidden", "Only a group admin can add members");
    const rows: ConversationParticipant[] = [];
    for (const uid of [...new Set(req.userIds)]) {
      if (await this.participants.find(conversationId, uid)) continue;
      const mem = await this.memberships.find(conv.gymId, uid);
      if (!mem || mem.status !== "active") throw new AppError("forbidden", `User ${uid} is not a member of this gym`);
      rows.push({ id: this.newId(), conversationId, userId: uid, role: "member", muted: false });
    }
    await this.participants.insertMany(rows);
  }

  public async leaveConversation(userId: string, conversationId: string, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind === "gym_channel") {
      await this.channelReads.upsertMuted(conversationId, userId, true, this.newId());
      return;
    }
    await this.assertAccess(userId, conv, role);
    await this.participants.setLeftAt(conversationId, userId, new Date().toISOString());
  }

  public async setMuted(userId: string, conversationId: string, muted: boolean, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    if (conv.kind === "gym_channel") { await this.channelReads.upsertMuted(conversationId, userId, muted, this.newId()); return; }
    await this.assertAccess(userId, conv, role);
    await this.participants.setMuted(conversationId, userId, muted);
  }

  public async markRead(userId: string, conversationId: string, role: UserRole): Promise<void> {
    const conv = await this.conversations.findById(conversationId);
    if (!conv) throw new AppError("not_found", `Conversation ${conversationId} not found`);
    await this.assertAccess(userId, conv, role);
    const now: string = new Date().toISOString();
    if (conv.kind === "gym_channel") await this.channelReads.upsertLastReadAt(conversationId, userId, now, this.newId());
    else await this.participants.setLastReadAt(conversationId, userId, now);
  }

  public async blockUser(userId: string, targetId: string): Promise<void> {
    if (userId === targetId) throw new AppError("bad_request", "Cannot block yourself");
    if (await this.blocks.existsEitherWay(userId, targetId)) return;
    await this.blocks.insert({ id: this.newId(), blockerId: userId, blockedId: targetId, createdAt: new Date().toISOString() });
  }

  public async unblockUser(userId: string, blockedId: string): Promise<void> {
    await this.blocks.deleteByBlocked(userId, blockedId);
  }

  public async listBlocks(userId: string): Promise<string[]> {
    return this.blocks.listBlockedBy(userId);
  }

  private async firstSharedActiveGym(a: string, b: string): Promise<string | null> {
    const [am, bm] = await Promise.all([this.memberships.listByUser(a), this.memberships.listByUser(b)]);
    const bActive = new Set(bm.filter((m) => m.status === "active").map((m) => m.gymId));
    const hit = am.find((m) => m.status === "active" && bActive.has(m.gymId));
    return hit?.gymId ?? null;
  }

  public async reportMessage(userId: string, req: ReportMessageRequest): Promise<MessageReport> {
    let gymId: string | null = null;
    if (req.messageId) {
      const m = await this.messages.findById(req.messageId);
      const conv = m ? await this.conversations.findById(m.conversationId) : null;
      gymId = conv?.gymId ?? (await this.firstSharedActiveGym(userId, req.reportedUserId));
    } else {
      gymId = await this.firstSharedActiveGym(userId, req.reportedUserId);
    }
    if (!gymId) throw new AppError("bad_request", "No shared gym to route this report");
    const report: MessageReport = {
      id: this.newId(), messageId: req.messageId, reportedUserId: req.reportedUserId, reporterId: userId,
      gymId, reason: req.reason, note: req.note, status: "open", createdAt: new Date().toISOString(),
    };
    await this.reports.insert(report);
    return report;
  }

  public async listReports(userId: string, gymId: string, status: MessageReportStatus | undefined, role: UserRole): Promise<MessageReport[]> {
    await assertCanManageGym(this.authzDeps(), userId, gymId, role);
    return this.reports.listByGym(gymId, status);
  }

  public async resolveReport(userId: string, reportId: string, req: ResolveReportRequest, role: UserRole): Promise<void> {
    const report = await this.reports.findById(reportId);
    if (!report) throw new AppError("not_found", `Report ${reportId} not found`);
    await assertCanManageGym(this.authzDeps(), userId, report.gymId, role);
    await this.reports.updateStatus(reportId, req.status, new Date().toISOString());
  }
}
