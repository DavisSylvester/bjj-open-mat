// apps/api/test/contract-membership-status.test.mts
import { describe, expect, it } from 'bun:test';
import { Value } from '@sinclair/typebox/value';
import {
  GymMembership,
  MembershipStatus,
  ManageableMembershipStatus,
  RosterMember,
  UpdateMembershipRequest,
  hasMemberPrivileges,
} from '@bjj/contract';

describe('membership status contract', () => {
  it('accepts all four statuses', () => {
    for (const s of ['pending', 'active', 'hidden', 'inactive']) {
      expect(Value.Check(MembershipStatus, s)).toBe(true);
    }
    expect(Value.Check(MembershipStatus, 'bogus')).toBe(false);
  });

  it('ManageableMembershipStatus rejects pending', () => {
    expect(Value.Check(ManageableMembershipStatus, 'hidden')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'inactive')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'active')).toBe(true);
    expect(Value.Check(ManageableMembershipStatus, 'pending')).toBe(false);
  });

  it('hasMemberPrivileges is true only for active and hidden', () => {
    expect(hasMemberPrivileges('active')).toBe(true);
    expect(hasMemberPrivileges('hidden')).toBe(true);
    expect(hasMemberPrivileges('inactive')).toBe(false);
    expect(hasMemberPrivileges('pending')).toBe(false);
    // Legacy docs may omit the field; the schema default is 'active'.
    expect(hasMemberPrivileges(undefined)).toBe(true);
  });

  it('UpdateMembershipRequest carries status', () => {
    expect(Value.Check(UpdateMembershipRequest, { status: 'hidden' })).toBe(true);
    expect(Value.Check(UpdateMembershipRequest, { status: 'pending' })).toBe(false);
  });

  it('GymMembership carries the status audit fields', () => {
    const m = {
      id: 'm1', gymId: 'g1', userId: 'u1', status: 'hidden', verifiedMember: false,
      gymRole: 'member', isHome: false, visibleInRoster: true, joinMethod: 'self',
      joinedAt: 't', statusUpdatedAt: 't', statusUpdatedBy: 'owner1',
    };
    expect(Value.Check(GymMembership, m)).toBe(true);
  });

  it('RosterMember requires status', () => {
    const base = {
      userId: 'u1', name: 'A', gymRole: 'member', verifiedMember: false, hasProfile: true,
    };
    expect(Value.Check(RosterMember, base)).toBe(false);
    expect(Value.Check(RosterMember, { ...base, status: 'active' })).toBe(true);
  });
});
