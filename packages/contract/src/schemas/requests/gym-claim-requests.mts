import { type Static, Type as t } from "@sinclair/typebox";
import { ClaimantRelationship } from "../../enums/claimant-relationship.mts";
import { GymClaimStatus } from "../../enums/gym-claim-status.mts";

export const SubmitGymClaimRequest = t.Object(
  {
    relationship: ClaimantRelationship,
    contact: t.String({ minLength: 1 }),
    message: t.String({ minLength: 1 }),
  },
  { $id: "SubmitGymClaimRequest" },
);
export type SubmitGymClaimRequest = Static<typeof SubmitGymClaimRequest>;

export const RejectGymClaimRequest = t.Object(
  {
    note: t.Optional(t.String()),
  },
  { $id: "RejectGymClaimRequest" },
);
export type RejectGymClaimRequest = Static<typeof RejectGymClaimRequest>;

export const AdminGymClaimsQuery = t.Object(
  {
    status: t.Optional(GymClaimStatus),
  },
  { $id: "AdminGymClaimsQuery" },
);
export type AdminGymClaimsQuery = Static<typeof AdminGymClaimsQuery>;
