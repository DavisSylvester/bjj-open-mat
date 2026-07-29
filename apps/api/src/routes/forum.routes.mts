import { Elysia } from "elysia";
import {
  CreateQuestionRequest,
  UpdateQuestionRequest,
  CreateAnswerRequest,
  UpdateAnswerRequest,
  AcceptAnswerRequest,
  ForumListQuery,
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
export function forumRoutes(container: Container) {
  const { forumFacade } = container;

  // Gym-scoped forum routes: POST question + GET question list under /api/v1/gyms/:id/forum/questions
  const gymForumRoutes = new Elysia({ prefix: "/api/v1/gyms" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .post(
      "/:id/forum/questions",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await forumFacade.createQuestion(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: CreateQuestionRequest },
    )
    .get(
      "/:id/forum/questions",
      async ({ identity, params, query }) => {
        const caller = requireId(identity);
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const result = await forumFacade.listQuestions(caller.userId, params.id, query.category, page, limit, caller.role);
        return list(result.items, { page, limit, total: result.total });
      },
      { requireAuth: true, query: ForumListQuery },
    );

  // Forum-scoped routes: question detail, update, delete, answer CRUD, accept
  const forumDetailRoutes = new Elysia({ prefix: "/api/v1/forum" })
    .use(authPlugin(container.verifier, container.roleLookup))
    .get(
      "/questions/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        return data(await forumFacade.getDetail(caller.userId, params.id, caller.role));
      },
      { requireAuth: true },
    )
    .patch(
      "/questions/:id",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await forumFacade.updateQuestion(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: UpdateQuestionRequest },
    )
    .delete(
      "/questions/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await forumFacade.deleteQuestion(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .post(
      "/questions/:id/answers",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await forumFacade.createAnswer(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: CreateAnswerRequest },
    )
    .patch(
      "/answers/:id",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        return data(await forumFacade.updateAnswer(caller.userId, params.id, body, caller.role));
      },
      { requireAuth: true, body: UpdateAnswerRequest },
    )
    .delete(
      "/answers/:id",
      async ({ identity, params }) => {
        const caller = requireId(identity);
        await forumFacade.deleteAnswer(caller.userId, params.id, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true },
    )
    .post(
      "/questions/:id/accept",
      async ({ identity, params, body }) => {
        const caller = requireId(identity);
        await forumFacade.accept(caller.userId, params.id, body, caller.role);
        return data({ ok: true });
      },
      { requireAuth: true, body: AcceptAnswerRequest },
    );

  return new Elysia()
    .use(gymForumRoutes)
    .use(forumDetailRoutes);
}
