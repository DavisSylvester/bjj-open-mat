import type { UserRole } from "@bjj/contract";

export interface AuthIdentity {
  readonly userId: string;
  readonly role: UserRole;
  readonly email: string;
  readonly viaBypass: boolean;
}
