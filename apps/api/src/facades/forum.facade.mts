// apps/api/src/facades/forum.facade.mts
import type {
  AcceptAnswerRequest,
  CreateAnswerRequest,
  CreateQuestionRequest,
  ForumAnswer,
  ForumCategory,
  ForumQuestion,
  ForumQuestionDetail,
  Notification,
  NotificationType,
  UpdateAnswerRequest,
  UpdateQuestionRequest,
  UserRole,
} from '@bjj/contract';
import { AppError } from '../http/errors.mts';
import { assertActiveMember, assertCanManageGym } from './gym-authz.mts';
import type { ForumQuestionRepository } from '../repositories/forum-question.repository.mts';
import type { ForumAnswerRepository } from '../repositories/forum-answer.repository.mts';
import type { MembershipRepository } from '../repositories/membership.repository.mts';
import type { GymRepository } from '../repositories/gym.repository.mts';
import type { NotificationRepository } from '../repositories/notification.repository.mts';
import type { PushNotifier } from '../push/push.types.mts';

type IdFactory = () => string;
type QRepo = Pick<ForumQuestionRepository, 'insert' | 'findById' | 'listByGym' | 'update' | 'incAnswerCount' | 'delete'>;
type ARepo = Pick<ForumAnswerRepository, 'insert' | 'findById' | 'listByQuestion' | 'update' | 'setAcceptedForQuestion' | 'clearAcceptedForQuestion' | 'delete'>;
type MemberRepo = Pick<MembershipRepository, 'find'>;
type GymRepo = Pick<GymRepository, 'findById'>;
type NotifRepo = Pick<NotificationRepository, 'insert'>;

export class ForumFacade {

  public constructor(
    private readonly questions: QRepo,
    private readonly answers: ARepo,
    private readonly memberships: MemberRepo,
    private readonly gyms: GymRepo,
    private readonly notifications: NotifRepo,
    private readonly push: PushNotifier,
    private readonly newId: IdFactory,
  ) {}

  private authzDeps(): { gyms: GymRepo; memberships: MemberRepo } {
    return { gyms: this.gyms, memberships: this.memberships };
  }

  private async getQuestionOr404(id: string): Promise<ForumQuestion> {
    const q = await this.questions.findById(id);
    if (!q) throw new AppError('not_found', `Question ${id} not found`);
    return q;
  }

  private async getAnswerOr404(id: string): Promise<ForumAnswer> {
    const a = await this.answers.findById(id);
    if (!a) throw new AppError('not_found', `Answer ${id} not found`);
    return a;
  }

  private async notify(
    userId: string,
    type: NotificationType,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const n: Notification = {
      id: this.newId(),
      userId,
      type,
      title,
      body,
      read: false,
      data,
      createdAt: new Date().toISOString(),
    };
    await this.notifications.insert(n);
    await this.push.pushToUsers([n.userId], { title: n.title, body: n.body, data: { type: n.type } });
  }

  public async createQuestion(
    userId: string,
    gymId: string,
    req: CreateQuestionRequest,
    role: UserRole,
  ): Promise<ForumQuestion> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    const now: string = new Date().toISOString();
    const q: ForumQuestion = {
      id: this.newId(),
      gymId,
      authorId: userId,
      category: req.category,
      title: req.title,
      body: req.body,
      pinned: false,
      locked: false,
      answerCount: 0,
      createdAt: now,
    };
    return this.questions.insert(q);
  }

  public async listQuestions(
    userId: string,
    gymId: string,
    category: ForumCategory | undefined,
    page: number,
    limit: number,
    role: UserRole,
  ): Promise<{ items: ForumQuestion[]; total: number }> {
    await assertActiveMember(this.authzDeps(), userId, gymId, role);
    return this.questions.listByGym(gymId, category, (page - 1) * limit, limit);
  }

  public async getDetail(userId: string, questionId: string, role: UserRole): Promise<ForumQuestionDetail> {
    const q = await this.getQuestionOr404(questionId);
    await assertActiveMember(this.authzDeps(), userId, q.gymId, role);
    const questionAnswers = await this.answers.listByQuestion(questionId);
    return { question: q, answers: questionAnswers };
  }

  public async updateQuestion(
    userId: string,
    questionId: string,
    req: UpdateQuestionRequest,
    role: UserRole,
  ): Promise<ForumQuestion> {
    const q = await this.getQuestionOr404(questionId);
    const touchesContent: boolean = req.title !== undefined || req.body !== undefined || req.category !== undefined;
    const touchesModeration: boolean = req.pinned !== undefined || req.locked !== undefined;
    if (touchesContent && q.authorId !== userId) {
      throw new AppError('forbidden', 'Only the author can edit content');
    }
    if (touchesModeration) {
      await assertCanManageGym(this.authzDeps(), userId, q.gymId, role);
    }
    const patch: Partial<ForumQuestion> = {};
    if (req.title !== undefined) patch.title = req.title;
    if (req.body !== undefined) patch.body = req.body;
    if (req.category !== undefined) patch.category = req.category;
    if (req.pinned !== undefined) patch.pinned = req.pinned;
    if (req.locked !== undefined) patch.locked = req.locked;
    patch.updatedAt = new Date().toISOString();
    return (await this.questions.update(questionId, patch)) as ForumQuestion;
  }

  public async deleteQuestion(userId: string, questionId: string, role: UserRole): Promise<void> {
    const q = await this.getQuestionOr404(questionId);
    if (q.authorId !== userId) {
      await assertCanManageGym(this.authzDeps(), userId, q.gymId, role);
    }
    const questionAnswers = await this.answers.listByQuestion(questionId);
    await Promise.all(questionAnswers.map((a) => this.answers.delete(a.id)));
    await this.questions.delete(questionId);
  }

  public async createAnswer(
    userId: string,
    questionId: string,
    req: CreateAnswerRequest,
    role: UserRole,
  ): Promise<ForumAnswer> {
    const q = await this.getQuestionOr404(questionId);
    await assertActiveMember(this.authzDeps(), userId, q.gymId, role);
    if (q.locked) throw new AppError('conflict', 'This question is locked');
    const now: string = new Date().toISOString();
    const answer: ForumAnswer = {
      id: this.newId(),
      questionId,
      gymId: q.gymId,
      authorId: userId,
      body: req.body,
      accepted: false,
      createdAt: now,
    };
    const saved = await this.answers.insert(answer);
    await this.questions.incAnswerCount(questionId, 1);
    if (q.authorId !== userId) {
      await this.notify(
        q.authorId,
        'forum_answer',
        'New answer',
        `Someone answered "${q.title}"`,
        { questionId, gymId: q.gymId },
      );
    }
    return saved;
  }

  public async updateAnswer(
    userId: string,
    answerId: string,
    req: UpdateAnswerRequest,
    _role: UserRole,
  ): Promise<ForumAnswer> {
    const a = await this.getAnswerOr404(answerId);
    if (a.authorId !== userId) throw new AppError('forbidden', 'Only the author can edit this answer');
    return (await this.answers.update(answerId, { body: req.body, updatedAt: new Date().toISOString() })) as ForumAnswer;
  }

  public async deleteAnswer(userId: string, answerId: string, role: UserRole): Promise<void> {
    const a = await this.getAnswerOr404(answerId);
    if (a.authorId !== userId) {
      await assertCanManageGym(this.authzDeps(), userId, a.gymId, role);
    }
    await this.answers.delete(answerId);
    await this.questions.incAnswerCount(a.questionId, -1);
    const q = await this.questions.findById(a.questionId);
    if (q && q.acceptedAnswerId === answerId) {
      await this.questions.update(a.questionId, { acceptedAnswerId: undefined });
    }
  }

  public async accept(
    userId: string,
    questionId: string,
    req: AcceptAnswerRequest,
    role: UserRole,
  ): Promise<void> {
    const q = await this.getQuestionOr404(questionId);
    if (q.authorId !== userId) {
      await assertCanManageGym(this.authzDeps(), userId, q.gymId, role);
    }
    const answer = await this.getAnswerOr404(req.answerId);
    if (answer.questionId !== questionId) {
      throw new AppError('bad_request', 'Answer does not belong to this question');
    }
    await this.answers.setAcceptedForQuestion(questionId, req.answerId);
    await this.questions.update(questionId, { acceptedAnswerId: req.answerId });
    if (answer.authorId !== userId) {
      await this.notify(
        answer.authorId,
        'forum_accepted',
        'Answer accepted',
        `Your answer to "${q.title}" was accepted`,
        { questionId, gymId: q.gymId },
      );
    }
  }
}
