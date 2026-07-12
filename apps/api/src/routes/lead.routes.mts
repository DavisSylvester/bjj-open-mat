import { Elysia } from "elysia";
import { GymLeadRequest, WaitlistLeadRequest } from "@bjj/contract";
import type { Container } from "../container.mts";
import { data } from "../http/envelope.mts";

// Public, unauthenticated lead capture for the marketing site. A non-empty
// honeypot (`hp`) field marks a bot: we return success without persisting.
// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function leadRoutes(container: Container) {
  const { leadFacade } = container;

  return new Elysia({ prefix: "/api/v1" })
    .post(
      "/waitlist",
      async ({ body }) => {
        if (body.hp && body.hp.length > 0) return data({ status: "confirmed" as const });
        return data(await leadFacade.joinWaitlist(body));
      },
      { body: WaitlistLeadRequest },
    )
    .post(
      "/gym-leads",
      async ({ body }) => {
        if (body.hp && body.hp.length > 0) return data({ status: "new" as const });
        return data(await leadFacade.submitGymLead(body));
      },
      { body: GymLeadRequest },
    );
}
