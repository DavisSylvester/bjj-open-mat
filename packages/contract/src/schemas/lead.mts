import { type Static, Type as t } from "@sinclair/typebox";

export const Utm = t.Object(
  {
    source: t.Optional(t.String()),
    medium: t.Optional(t.String()),
    campaign: t.Optional(t.String()),
  },
  { $id: "Utm" },
);
export type Utm = Static<typeof Utm>;

export const WaitlistLeadStatus = t.Union([t.Literal("pending"), t.Literal("confirmed")], {
  $id: "WaitlistLeadStatus",
});
export type WaitlistLeadStatus = Static<typeof WaitlistLeadStatus>;

export const WaitlistLead = t.Object(
  {
    id: t.String(),
    email: t.String({ format: "email" }),
    status: WaitlistLeadStatus,
    source: t.Optional(t.String()),
    utm: t.Optional(Utm),
    createdAt: t.String(),
    confirmationSentAt: t.Optional(t.String()),
  },
  { $id: "WaitlistLead" },
);
export type WaitlistLead = Static<typeof WaitlistLead>;

export const GymLeadStatus = t.Union([t.Literal("new"), t.Literal("contacted")], { $id: "GymLeadStatus" });
export type GymLeadStatus = Static<typeof GymLeadStatus>;

export const GymLead = t.Object(
  {
    id: t.String(),
    gymName: t.String(),
    ownerName: t.Optional(t.String()),
    ownerEmail: t.String({ format: "email" }),
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    message: t.Optional(t.String()),
    status: GymLeadStatus,
    utm: t.Optional(Utm),
    createdAt: t.String(),
  },
  { $id: "GymLead" },
);
export type GymLead = Static<typeof GymLead>;
