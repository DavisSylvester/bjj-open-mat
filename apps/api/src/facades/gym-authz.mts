// apps/api/src/facades/gym-authz.mts
import type { Gym, GymMembership, UserRole } from '@bjj/contract';
import { AppError } from '../http/errors.mts';

export interface GymAuthzDeps {
  readonly gyms: { findById(id: string): Promise<Gym | null> };
  readonly memberships: { find(gymId: string, userId: string): Promise<GymMembership | null> };
}

export async function assertCanManageGym(
  deps: GymAuthzDeps,
  callerId: string,
  gymId: string,
  callerRole: UserRole,
): Promise<void> {
  if (callerRole === 'admin') return;
  const gym: Gym | null = await deps.gyms.findById(gymId);
  if (!gym) throw new AppError('not_found', `Gym ${gymId} not found`);
  if (gym.ownerId === callerId) return;
  const membership: GymMembership | null = await deps.memberships.find(gymId, callerId);
  const role: string = membership?.gymRole ?? 'member';
  if (membership && membership.status === 'active' && (role === 'coach' || role === 'owner')) return;
  throw new AppError('forbidden', 'Requires gym owner or coach');
}
