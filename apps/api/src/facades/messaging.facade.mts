// apps/api/src/facades/messaging.facade.mts
import type {
  Conversation, ConversationParticipant, CreateChannelRequest, CreateGroupRequest, Gym, GymMembership, UserRole,
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
}
