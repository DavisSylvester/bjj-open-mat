// apps/api/src/facades/messaging.facade.mts
import type {
  Conversation, ConversationParticipant, ConversationSummary, CreateChannelRequest, CreateGroupRequest,
  Gym, GymMembership, Message, MessageListQuery, SendMessageRequest, UserRole,
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

type IdFactory = () => string;

let _lastNow = 0;
function monotonicIso(): string {
  const t = Date.now();
  _lastNow = t > _lastNow ? t : _lastNow + 1;
  return new Date(_lastNow).toISOString();
}
type ConvRepo = Pick<ConversationRepository, "insert" | "findById" | "findDirectByPairKey" | "listChannelsByGym" | "updateLastMessage" | "update" | "delete">;
type MsgRepo = Pick<MessageRepository, "insert" | "findById" | "listByConversation" | "latestForConversation" | "countAfter" | "softDelete" | "update">;
type PartRepo = Pick<ConversationParticipantRepository, "insertMany" | "find" | "listByConversation" | "listActiveForUser" | "setLastReadAt" | "setMuted" | "setLeftAt">;
type ReadRepo = Pick<ChannelReadStateRepository, "find" | "upsertLastReadAt" | "upsertMuted">;
type BlockRepo = Pick<UserBlockRepository, "insert" | "existsEitherWay" | "listBlockedBy" | "delete">;
type ReportRepo = Pick<MessageReportRepository, "insert" | "findById" | "listByGym" | "updateStatus">;
type MemberRepo = Pick<MembershipRepository, "find" | "listByUser">;
type GymRepo = Pick<GymRepository, "findById">;

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
      await assertActiveMember(this.authzDeps(), userId, conv.gymId as string, role);
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
      return { conversation: conv, unreadCount, muted, lastMessage: lastMessage ?? undefined, otherParticipantIds: others };
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
    const now: string = monotonicIso();
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
    const now: string = monotonicIso();
    const message: Message = { id: this.newId(), conversationId, authorId: userId, body: req.body, createdAt: now };
    await this.messages.insert(message);
    await this.conversations.updateLastMessage(conversationId, now, req.body.slice(0, 140));
    return message;
  }
}
