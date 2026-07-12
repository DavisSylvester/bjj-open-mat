import { type Static, Type as t } from "@sinclair/typebox";
import { Utm } from "../lead.mts";

// `hp` is a honeypot: a hidden field real users never fill. Non-empty => bot.
export const WaitlistLeadRequest = t.Object(
  {
    email: t.String({ format: "email" }),
    source: t.Optional(t.String()),
    utm: t.Optional(Utm),
    hp: t.Optional(t.String()),
  },
  { $id: "WaitlistLeadRequest" },
);
export type WaitlistLeadRequest = Static<typeof WaitlistLeadRequest>;

export const GymLeadRequest = t.Object(
  {
    gymName: t.String({ minLength: 1 }),
    ownerName: t.Optional(t.String()),
    ownerEmail: t.String({ format: "email" }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    message: t.Optional(t.String()),
    utm: t.Optional(Utm),
    hp: t.Optional(t.String()),
  },
  { $id: "GymLeadRequest" },
);
export type GymLeadRequest = Static<typeof GymLeadRequest>;

export const LeadResponse = t.Object(
  {
    status: t.Union([t.Literal("confirmed"), t.Literal("new")]),
  },
  { $id: "LeadResponse" },
);
export type LeadResponse = Static<typeof LeadResponse>;
