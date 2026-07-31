import { type Static, Type as t } from "@sinclair/typebox";
import { GymClaimKind } from "../enums/gym-claim-kind.mjs";
import { GymClaimStatus } from "../enums/gym-claim-status.mjs";
import { ClaimantRelationship } from "../enums/claimant-relationship.mjs";

export const GymClaim = t.Object(
  {
    id: t.String(),
    gymId: t.String(),
    claimantId: t.String(),
    kind: GymClaimKind,
    relationship: ClaimantRelationship,
    contact: t.String({ minLength: 1 }),
    message: t.String(),
    status: t.Optional(t.Union([GymClaimStatus], { default: "pending" })),
    previousOwnerId: t.Optional(t.String()),
    createdAt: t.String(),
    decidedAt: t.Optional(t.String()),
    decidedBy: t.Optional(t.String()),
    decisionNote: t.Optional(t.String()),
  },
  { $id: "GymClaim" },
);
export type GymClaim = Static<typeof GymClaim>;
