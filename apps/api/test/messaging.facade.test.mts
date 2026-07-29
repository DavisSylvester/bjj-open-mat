// apps/api/test/messaging.facade.test.mts
import { describe, expect, it } from "bun:test";
import { MessagingFacade } from "../src/facades/messaging.facade.mts";
import type { Conversation, ConversationParticipant, Gym, GymMembership, Message, UserBlock, MessageReport, ChannelReadState } from "@bjj/contract";
import type { MessageListQuery, AddParticipantsRequest, EditMessageRequest } from "@bjj/contract";

interface Seed {
  gymOwnerId?: string;
  memberships?: GymMembership[];
  conversations?: Conversation[];
  participants?: ConversationParticipant[];
  messages?: Message[];
  blocks?: UserBlock[];
}

export function facade(seed?: Seed) {
  const conversations = new Map<string, Conversation>();
  (seed?.conversations ?? []).forEach((c) => conversations.set(c.id, c));
  const participants = new Map<string, ConversationParticipant>();
  (seed?.participants ?? []).forEach((p) => participants.set(`${p.conversationId}:${p.userId}`, p));
  const messages = new Map<string, Message>();
  const msgInsertIndex = new Map<string, number>();
  let msgInsertCounter = 0;
  (seed?.messages ?? []).forEach((m) => { messages.set(m.id, m); msgInsertIndex.set(m.id, msgInsertCounter++); });
  const blocks = new Map<string, UserBlock>();
  (seed?.blocks ?? []).forEach((b) => blocks.set(b.id, b));
  const channelReads = new Map<string, ChannelReadState>();
  const reports: MessageReport[] = [];
  const memberList: GymMembership[] = seed?.memberships ?? [];
  const gyms = new Map<string, Gym>([
    ["g1", { id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }],
    ["g2", { id: "g2", name: "B", address: "y", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }],
  ]);

  const convRepo = {
    insert: async (c: Conversation) => { conversations.set(c.id, c); return c; },
    findById: async (id: string) => conversations.get(id) ?? null,
    findDirectByPairKey: async (pk: string) => [...conversations.values()].find((c) => c.pairKey === pk) ?? null,
    listChannelsByGym: async (g: string) => [...conversations.values()].filter((c) => c.kind === "gym_channel" && c.gymId === g),
    updateLastMessage: async (id: string, at: string, preview: string) => { const c = conversations.get(id); if (c) { c.lastMessageAt = at; c.lastMessagePreview = preview; } },
    update: async (id: string, patch: Partial<Conversation>) => { const c = conversations.get(id); if (!c) return null; const n = { ...c, ...patch }; Object.keys(patch).forEach((k) => { if ((patch as Record<string, unknown>)[k] === undefined) delete (n as Record<string, unknown>)[k]; }); conversations.set(id, n); return n; },
    delete: async (id: string) => { conversations.delete(id); },
  };
  const msgCmpDesc = (a: Message, b: Message): number => {
    const tCmp = (b.createdAt ?? "").localeCompare(a.createdAt ?? "");
    if (tCmp !== 0) return tCmp;
    // tie-break by insertion order (later insert = higher index = "newer")
    return (msgInsertIndex.get(b.id) ?? 0) - (msgInsertIndex.get(a.id) ?? 0);
  };
  const msgRepo = {
    insert: async (m: Message) => { messages.set(m.id, m); msgInsertIndex.set(m.id, msgInsertCounter++); return m; },
    findById: async (id: string) => messages.get(id) ?? null,
    listByConversation: async (cid: string, before: string | undefined, limit: number) => [...messages.values()].filter((m) => m.conversationId === cid && (before === undefined || (m.createdAt ?? "") < before)).sort(msgCmpDesc).slice(0, limit),
    latestForConversation: async (cid: string) => [...messages.values()].filter((m) => m.conversationId === cid).sort(msgCmpDesc)[0] ?? null,
    countAfter: async (cid: string, after: string | undefined) => [...messages.values()].filter((m) => m.conversationId === cid && !m.deletedAt && (after === undefined || (m.createdAt ?? "") > after)).length,
    softDelete: async (id: string, at: string) => { const m = messages.get(id); if (m) { m.deletedAt = at; m.body = ""; } },
    update: async (id: string, patch: Partial<Message>) => { const m = messages.get(id); if (!m) return null; const n = { ...m, ...patch }; messages.set(id, n); return n; },
  };
  const partRepo = {
    insertMany: async (ps: ConversationParticipant[]) => { ps.forEach((p) => participants.set(`${p.conversationId}:${p.userId}`, p)); },
    find: async (cid: string, uid: string) => participants.get(`${cid}:${uid}`) ?? null,
    listByConversation: async (cid: string) => [...participants.values()].filter((p) => p.conversationId === cid),
    listActiveForUser: async (uid: string) => [...participants.values()].filter((p) => p.userId === uid && !p.leftAt),
    setLastReadAt: async (cid: string, uid: string, at: string) => { const p = participants.get(`${cid}:${uid}`); if (p) p.lastReadAt = at; },
    setMuted: async (cid: string, uid: string, m: boolean) => { const p = participants.get(`${cid}:${uid}`); if (p) p.muted = m; },
    setLeftAt: async (cid: string, uid: string, at: string) => { const p = participants.get(`${cid}:${uid}`); if (p) p.leftAt = at; },
  };
  const readRepo = {
    find: async (chId: string, uid: string) => channelReads.get(`${chId}:${uid}`) ?? null,
    upsertLastReadAt: async (chId: string, uid: string, at: string, id: string) => { const k = `${chId}:${uid}`; const cur = channelReads.get(k); channelReads.set(k, { id: cur?.id ?? id, channelId: chId, userId: uid, lastReadAt: at, muted: cur?.muted ?? false }); },
    upsertMuted: async (chId: string, uid: string, m: boolean, id: string) => { const k = `${chId}:${uid}`; const cur = channelReads.get(k); channelReads.set(k, { id: cur?.id ?? id, channelId: chId, userId: uid, lastReadAt: cur?.lastReadAt, muted: m }); },
  };
  const blockRepo = {
    insert: async (b: UserBlock) => { blocks.set(b.id, b); return b; },
    existsEitherWay: async (a: string, b: string) => [...blocks.values()].some((x) => (x.blockerId === a && x.blockedId === b) || (x.blockerId === b && x.blockedId === a)),
    listBlockedBy: async (uid: string) => [...blocks.values()].filter((x) => x.blockerId === uid).map((x) => x.blockedId),
    delete: async (id: string, blockerId: string) => { const b = blocks.get(id); if (b && b.blockerId === blockerId) blocks.delete(id); },
  };
  const reportRepo = {
    insert: async (r: MessageReport) => { reports.push(r); return r; },
    findById: async (id: string) => reports.find((r) => r.id === id) ?? null,
    listByGym: async (g: string, s: string | undefined) => reports.filter((r) => r.gymId === g && (s === undefined || r.status === s)),
    updateStatus: async (id: string, status: string, at: string) => { const r = reports.find((x) => x.id === id); if (r) { r.status = status as MessageReport["status"]; r.reviewedAt = at; } },
  };
  const memberRepo = {
    find: async (g: string, u: string) => memberList.find((m) => m.gymId === g && m.userId === u) ?? null,
    listByUser: async (u: string) => memberList.filter((m) => m.userId === u),
  };
  const gymRepo = { findById: async (id: string) => gyms.get(id) ?? null };
  let n = 0;

  return {
    f: new MessagingFacade(convRepo, msgRepo, partRepo, readRepo, blockRepo, reportRepo, memberRepo, gymRepo, () => `id-${n++}`),
    conversations, participants, messages, blocks, channelReads, reports,
  };
}

export const member = (userId: string, gymId = "g1", over: Partial<GymMembership> = {}): GymMembership => ({
  id: `m-${userId}-${gymId}`, gymId, userId, status: "active", verifiedMember: true, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t", ...over,
});

describe("MessagingFacade — creation + gating", () => {
  it("startDirect requires a shared active gym", async () => {
    const { f } = facade({ memberships: [member("u1", "g1"), member("u2", "g2")] });
    await expect(f.startDirect("u1", "u2", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("startDirect find-or-creates one direct conversation by pairKey", async () => {
    const { f, conversations } = facade({ memberships: [member("u1"), member("u2")] });
    const a = await f.startDirect("u1", "u2", "practitioner");
    const b = await f.startDirect("u2", "u1", "practitioner");
    expect(a.id).toBe(b.id);
    expect([...conversations.values()].filter((c) => c.kind === "direct").length).toBe(1);
    expect(a.pairKey).toBe("u1|u2");
  });

  it("startDirect refuses self and blocked users", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2")], blocks: [{ id: "b1", blockerId: "u2", blockedId: "u1" }] });
    await expect(f.startDirect("u1", "u1", "practitioner")).rejects.toMatchObject({ code: "bad_request" });
    await expect(f.startDirect("u1", "u2", "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("createGroup rejects a participant who is not a member of the gym", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2")] });
    await expect(f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2", "u3"] }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("createGroup includes creator as admin + members", async () => {
    const { f, participants } = facade({ memberships: [member("u1"), member("u2")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2"] }, "practitioner");
    expect(g.kind).toBe("group");
    expect(participants.get(`${g.id}:u1`)?.role).toBe("admin");
    expect(participants.get(`${g.id}:u2`)?.role).toBe("member");
  });

  it("createChannel requires a manager; listChannels seeds a default General", async () => {
    const nonMgr = facade({ memberships: [member("u1")] });
    await expect(nonMgr.f.createChannel("u1", "g1", { title: "Announcements" }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" })] });
    const channels = await owner.f.listChannels("u1", "g1", "practitioner");
    expect(channels.some((c) => c.title === "General")).toBe(true);
  });
});

describe("MessagingFacade — read + send", () => {
  it("send + list: unread counts, last message, access", async () => {
    const { f, conversations, participants } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await f.sendMessage("u1", conv.id, { body: "hey" }, "practitioner");
    await f.sendMessage("u1", conv.id, { body: "you there?" }, "practitioner");
    // u2 has never read -> unread 2
    const u2list = await f.listConversations("u2", "practitioner", 1, 20);
    const summary = u2list.items.find((s) => s.conversation.id === conv.id);
    expect(summary?.unreadCount).toBe(2);
    expect(summary?.lastMessage?.body).toBe("you there?");
    expect(summary?.otherParticipantIds).toEqual(["u1"]);
    // u2 reads -> unread 0
    await f.getMessages("u2", conv.id, { }, "practitioner");
    const after = await f.listConversations("u2", "practitioner", 1, 20);
    expect(after.items.find((s) => s.conversation.id === conv.id)?.unreadCount).toBe(0);
    expect(conversations.get(conv.id)?.lastMessagePreview).toBe("you there?");
    expect(participants.get(`${conv.id}:u2`)?.lastReadAt).toBeDefined();
  });

  it("non-participant cannot read a direct conversation", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await expect(f.getMessages("u3", conv.id, {}, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("channel: any active member reads + posts; unread via channel read-state", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [channel] = await owner.f.listChannels("u1", "g1", "practitioner");
    await owner.f.sendMessage("u1", channel.id, { body: "welcome" }, "practitioner");
    // u2 is a plain member -> can read + post
    const msgs = await owner.f.getMessages("u2", channel.id, {}, "practitioner");
    expect(msgs.length).toBe(1);
    await owner.f.sendMessage("u2", channel.id, { body: "thanks coach" }, "practitioner");
    expect((await owner.f.getMessages("u2", channel.id, {}, "practitioner")).length).toBe(2);
  });

  it("blocked author's messages are hidden from the blocker in a group", async () => {
    const { f, blocks } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "Squad", participantIds: ["u2", "u3"] }, "practitioner");
    await f.sendMessage("u2", g.id, { body: "from u2" }, "practitioner");
    await f.sendMessage("u3", g.id, { body: "from u3" }, "practitioner");
    blocks.set("b1", { id: "b1", blockerId: "u1", blockedId: "u2" });
    const seen = await f.getMessages("u1", g.id, {}, "practitioner");
    expect(seen.map((m) => m.body)).toEqual(["from u3"]);
  });
});

describe("MessagingFacade — edit/delete/participants/leave/mute", () => {
  it("author edits; non-author cannot", async () => {
    const { f, messages } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    const m = await f.sendMessage("u1", conv.id, { body: "orig" }, "practitioner");
    await f.editMessage("u1", m.id, { body: "edited" }, "practitioner");
    expect(messages.get(m.id)?.body).toBe("edited");
    await expect(f.editMessage("u2", m.id, { body: "hax" }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("manager deletes any message in a channel; plain member cannot delete others'", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [ch] = await owner.f.listChannels("u1", "g1", "practitioner");
    const m = await owner.f.sendMessage("u2", ch.id, { body: "member msg" }, "practitioner");
    await expect(owner.f.deleteMessage("u2b", m.id, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
    await owner.f.deleteMessage("u1", m.id, "practitioner"); // owner (manager)
    expect(owner.messages.get(m.id)?.deletedAt).toBeDefined();
  });

  it("addParticipants requires an admin caller + member targets", async () => {
    const { f, participants } = facade({ memberships: [member("u1"), member("u2"), member("u3")] });
    const g = await f.createGroup("u1", "g1", { gymId: "g1", title: "S", participantIds: ["u2"] }, "practitioner");
    await expect(f.addParticipants("u2", g.id, { userIds: ["u3"] }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
    await f.addParticipants("u1", g.id, { userIds: ["u3"] }, "practitioner");
    expect(participants.get(`${g.id}:u3`)?.role).toBe("member");
  });

  it("leave: group sets leftAt (drops from list); channel mutes", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const g = await owner.f.createGroup("u2", "g1", { gymId: "g1", title: "S", participantIds: ["u1"] }, "practitioner");
    await owner.f.leaveConversation("u1", g.id, "practitioner");
    const list = await owner.f.listConversations("u1", "practitioner", 1, 20);
    expect(list.items.some((s) => s.conversation.id === g.id)).toBe(false);
  });

  it("leaveConversation on a gym_channel mutes/hides it in listConversations", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [channel] = await owner.f.listChannels("u1", "g1", "practitioner");
    // before leave: channel visible and not muted for u2
    const before = await owner.f.listConversations("u2", "practitioner", 1, 20);
    const beforeSummary = before.items.find((s) => s.conversation.id === channel.id);
    expect(beforeSummary?.muted).toBe(false);
    // leave the channel (gym_channel path → upsertMuted(true))
    await owner.f.leaveConversation("u2", channel.id, "practitioner");
    const after = await owner.f.listConversations("u2", "practitioner", 1, 20);
    const afterSummary = after.items.find((s) => s.conversation.id === channel.id);
    expect(afterSummary?.muted).toBe(true);
  });

  it("setMuted on a gym_channel marks it muted in listConversations", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [channel] = await owner.f.listChannels("u1", "g1", "practitioner");
    await owner.f.setMuted("u2", channel.id, true, "practitioner");
    const list = await owner.f.listConversations("u2", "practitioner", 1, 20);
    const summary = list.items.find((s) => s.conversation.id === channel.id);
    expect(summary?.muted).toBe(true);
    // unmute restores it
    await owner.f.setMuted("u2", channel.id, false, "practitioner");
    const list2 = await owner.f.listConversations("u2", "practitioner", 1, 20);
    expect(list2.items.find((s) => s.conversation.id === channel.id)?.muted).toBe(false);
  });

  it("setMuted on a direct/group marks the participant row muted", async () => {
    const { f, participants } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await f.setMuted("u1", conv.id, true, "practitioner");
    expect(participants.get(`${conv.id}:u1`)?.muted).toBe(true);
    await f.setMuted("u1", conv.id, false, "practitioner");
    expect(participants.get(`${conv.id}:u1`)?.muted).toBe(false);
  });

  it("markRead sets unreadCount to 0 for a direct conversation", async () => {
    const { f } = facade({ memberships: [member("u1"), member("u2")] });
    const conv = await f.startDirect("u1", "u2", "practitioner");
    await f.sendMessage("u1", conv.id, { body: "msg1" }, "practitioner");
    await f.sendMessage("u1", conv.id, { body: "msg2" }, "practitioner");
    const before = await f.listConversations("u2", "practitioner", 1, 20);
    expect(before.items.find((s) => s.conversation.id === conv.id)?.unreadCount).toBe(2);
    await f.markRead("u2", conv.id, "practitioner");
    const after = await f.listConversations("u2", "practitioner", 1, 20);
    expect(after.items.find((s) => s.conversation.id === conv.id)?.unreadCount).toBe(0);
  });

  it("markRead sets unreadCount to 0 for a gym_channel", async () => {
    const owner = facade({ gymOwnerId: "u1", memberships: [member("u1", "g1", { gymRole: "owner" }), member("u2")] });
    const [channel] = await owner.f.listChannels("u1", "g1", "practitioner");
    await owner.f.sendMessage("u1", channel.id, { body: "announce" }, "practitioner");
    const before = await owner.f.listConversations("u2", "practitioner", 1, 20);
    expect(before.items.find((s) => s.conversation.id === channel.id)?.unreadCount).toBe(1);
    await owner.f.markRead("u2", channel.id, "practitioner");
    const after = await owner.f.listConversations("u2", "practitioner", 1, 20);
    expect(after.items.find((s) => s.conversation.id === channel.id)?.unreadCount).toBe(0);
  });
});
