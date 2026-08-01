// apps/api/test/forum.facade.test.mts
import { describe, expect, it } from "bun:test";
import { ForumFacade } from "../src/facades/forum.facade.mts";
import type { ForumQuestion, ForumAnswer, Gym, GymMembership, Notification } from "@bjj/contract";
import type { PushPayload } from "../src/push/push.types.mts";

function facade(seed?: { gymOwnerId?: string; memberships?: GymMembership[]; questions?: ForumQuestion[]; answers?: ForumAnswer[]; pushCapture?: { userIds: string[]; payload: PushPayload }[] }): { f: ForumFacade; questions: Map<string, ForumQuestion>; answers: Map<string, ForumAnswer>; notifications: Notification[] } {
  const questions = new Map<string, ForumQuestion>();
  (seed?.questions ?? []).forEach((q) => questions.set(q.id, q));
  const answers = new Map<string, ForumAnswer>();
  (seed?.answers ?? []).forEach((a) => answers.set(a.id, a));
  const members = new Map<string, GymMembership>();
  (seed?.memberships ?? []).forEach((m) => members.set(`${m.gymId}:${m.userId}`, m));
  const gyms = new Map<string, Gym>([["g1", { id: "g1", name: "A", address: "x", amenities: [], isVerified: true, ownerId: seed?.gymOwnerId }]]);
  const notifications: Notification[] = [];

  const qRepo = {
    insert: async (q: ForumQuestion): Promise<ForumQuestion> => { questions.set(q.id, q); return q; },
    findById: async (id: string): Promise<ForumQuestion | null> => questions.get(id) ?? null,
    listByGym: async (g: string): Promise<{ items: ForumQuestion[]; total: number }> => {
      const items = [...questions.values()].filter((q) => q.gymId === g); return { items, total: items.length };
    },
    update: async (id: string, patch: Partial<ForumQuestion>): Promise<ForumQuestion | null> => {
      const cur = questions.get(id); if (!cur) return null; const n = { ...cur, ...patch }; questions.set(id, n); return n;
    },
    incAnswerCount: async (id: string, d: number): Promise<void> => { const q = questions.get(id); if (q) q.answerCount += d; },
    delete: async (id: string): Promise<void> => { questions.delete(id); },
  };
  const aRepo = {
    insert: async (a: ForumAnswer): Promise<ForumAnswer> => { answers.set(a.id, a); return a; },
    findById: async (id: string): Promise<ForumAnswer | null> => answers.get(id) ?? null,
    listByQuestion: async (qid: string): Promise<ForumAnswer[]> => [...answers.values()].filter((a) => a.questionId === qid),
    update: async (id: string, patch: Partial<ForumAnswer>): Promise<ForumAnswer | null> => {
      const cur = answers.get(id); if (!cur) return null; const n = { ...cur, ...patch }; answers.set(id, n); return n;
    },
    setAcceptedForQuestion: async (qid: string, aid: string): Promise<void> => {
      [...answers.values()].filter((a) => a.questionId === qid).forEach((a) => { a.accepted = a.id === aid; });
    },
    clearAcceptedForQuestion: async (qid: string): Promise<void> => {
      [...answers.values()].filter((a) => a.questionId === qid).forEach((a) => { a.accepted = false; });
    },
    delete: async (id: string): Promise<void> => { answers.delete(id); },
  };
  const memberRepo = { find: async (g: string, u: string): Promise<GymMembership | null> => members.get(`${g}:${u}`) ?? null };
  const gymRepo = { findById: async (id: string): Promise<Gym | null> => gyms.get(id) ?? null };
  const notifRepo = { insert: async (n: Notification): Promise<Notification> => { notifications.push(n); return n; } };
  const pushCapture = seed?.pushCapture ?? [];
  const push = { pushToUsers: async (userIds: string[], payload: PushPayload): Promise<void> => { pushCapture.push({ userIds, payload }); } };
  let n = 0;
  return { f: new ForumFacade(qRepo, aRepo, memberRepo, gymRepo, notifRepo, push, () => `id-${n++}`), questions, answers, notifications };
}

const member = (userId: string, over: Partial<GymMembership> = {}): GymMembership => ({
  id: `m-${userId}`, gymId: "g1", userId, status: "active", verifiedMember: true, gymRole: "member",
  isHome: false, visibleInRoster: true, joinMethod: "self", joinedAt: "t", ...over,
});
const question = (over: Partial<ForumQuestion> = {}): ForumQuestion => ({
  id: over.id ?? "q1", gymId: "g1", authorId: over.authorId ?? "asker", category: "technique",
  title: "T", body: "B", pinned: false, locked: over.locked ?? false, answerCount: over.answerCount ?? 0,
  acceptedAnswerId: over.acceptedAnswerId, createdAt: "t", ...over,
});

describe("ForumFacade", () => {
  it("non-member cannot create a question", async () => {
    const { f } = facade();
    await expect(f.createQuestion("stranger", "g1", { category: "general", title: "T", body: "B" }, "practitioner"))
      .rejects.toMatchObject({ code: "forbidden" });
  });

  it("member answers; asker is notified; count increments", async () => {
    const { f, notifications, questions } = facade({
      memberships: [member("asker"), member("responder")],
      questions: [question({ id: "q1", authorId: "asker" })],
    });
    await f.createAnswer("responder", "q1", { body: "try this" }, "practitioner");
    expect(questions.get("q1")?.answerCount).toBe(1);
    expect(notifications.find((n) => n.type === "forum_answer")?.userId).toBe("asker");
  });

  it("answering a locked question is rejected", async () => {
    const { f } = facade({ memberships: [member("responder")], questions: [question({ id: "q1", locked: true })] });
    await expect(f.createAnswer("responder", "q1", { body: "x" }, "practitioner")).rejects.toMatchObject({ code: "conflict" });
  });

  it("only asker or moderator can accept; accept flips the answer + notifies answerer", async () => {
    const { f, questions, answers, notifications } = facade({
      gymOwnerId: "owner1",
      memberships: [member("asker"), member("responder")],
      questions: [question({ id: "q1", authorId: "asker" })],
      answers: [{ id: "a1", questionId: "q1", gymId: "g1", authorId: "responder", body: "b", accepted: false, createdAt: "t" }],
    });
    await expect(f.accept("responder", "q1", { answerId: "a1" }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
    await f.accept("asker", "q1", { answerId: "a1" }, "practitioner");
    expect(answers.get("a1")?.accepted).toBe(true);
    expect(questions.get("q1")?.acceptedAnswerId).toBe("a1");
    expect(notifications.find((n) => n.type === "forum_accepted")?.userId).toBe("responder");
  });

  it("pin requires moderator; author cannot pin their own question", async () => {
    const { f } = facade({ memberships: [member("asker")], questions: [question({ id: "q1", authorId: "asker" })] });
    await expect(f.updateQuestion("asker", "q1", { pinned: true }, "practitioner")).rejects.toMatchObject({ code: "forbidden" });
  });

  it("deleting the accepted answer clears acceptedAnswerId and decrements count", async () => {
    const { f, questions } = facade({
      gymOwnerId: "owner1",
      memberships: [member("responder")],
      questions: [question({ id: "q1", answerCount: 1, acceptedAnswerId: "a1" })],
      answers: [{ id: "a1", questionId: "q1", gymId: "g1", authorId: "responder", body: "b", accepted: true, createdAt: "t" }],
    });
    await f.deleteAnswer("responder", "a1", "practitioner");
    expect(questions.get("q1")?.acceptedAnswerId).toBeUndefined();
    expect(questions.get("q1")?.answerCount).toBe(0);
  });

  it("push fires with type=forum_answer when responder answers", async () => {
    const pushCalls: { userIds: string[]; payload: PushPayload }[] = [];
    const { f } = facade({
      memberships: [member("asker"), member("responder")],
      questions: [question({ id: "q1", authorId: "asker" })],
      pushCapture: pushCalls,
    });
    await f.createAnswer("responder", "q1", { body: "try this" }, "practitioner");
    expect(pushCalls).toHaveLength(1);
    expect(pushCalls[0].payload.data.type).toBe("forum_answer");
  });
});
