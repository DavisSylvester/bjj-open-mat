import type { ComponentFixture} from '@angular/core/testing';
import { TestBed } from '@angular/core/testing';

import { Members } from './members';
import { AdminApiService } from '@/core/api/admin-api.service';
import { GeoApiService } from '@/core/api/geo-api.service';
import type { AdminMembersTree, AdminRosterRow } from '@/core/models';

const TREE: AdminMembersTree = {
  states: [
    { state: 'CA', gyms: [{ id: 'g-ca', name: 'Cali BJJ', memberCount: 1, pendingCount: 0 }] },
    { state: 'TX', gyms: [{ id: 'g-tx', name: 'Renzo Dallas', memberCount: 2, pendingCount: 1, ownerId: 'u-owner' }] },
  ],
  noState: [{ id: 'g-none', name: 'Nowhere BJJ', memberCount: 1, pendingCount: 0 }],
  noGym: { userCount: 3 },
};

function row(over: Partial<AdminRosterRow> = {}): AdminRosterRow {
  return {
    membershipId: 'm-1', gymId: 'g-tx', userId: 'u-1',
    displayName: 'Davis', email: 'd@e.dev',
    status: 'active', visibleInRoster: true, verifiedMember: false,
    joinedAt: '2026-08-01T00:00:00.000Z',
    ...over,
  };
}

function setup(opts: { state?: string | null; api?: Partial<AdminApiService> } = {}): ComponentFixture<Members> {
  const api: Partial<AdminApiService> = {
    getMembersTree: async () => TREE,
    listGymMembers: async () => ({ data: [row()], meta: { page: 1, limit: 50, total: 2 } }),
    listNoGymUsers: async () => ({ data: [], meta: { page: 1, limit: 50, total: 3 } }),
    updateMembership: async () => ({}) as never,
    ...opts.api,
  };
  TestBed.configureTestingModule({
    imports: [Members],
    providers: [
      { provide: AdminApiService, useValue: api },
      {
        provide: GeoApiService,
        useValue: { detectState: async (): Promise<string | null> => opts.state ?? null },
      },
    ],
  });
  return TestBed.createComponent(Members);
}

async function settle(fixture: ComponentFixture<Members>): Promise<void> {
  fixture.detectChanges();
  await fixture.whenStable();
  fixture.detectChanges();
}

describe('Members page', () => {
  it('orders the detected state first, then the rest alphabetically', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['TX', 'CA']);
  });

  it('expands the detected state and only that one', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.isStateExpanded('TX')).toBe(true);
    expect(fixture.componentInstance.isStateExpanded('CA')).toBe(false);
  });

  it('falls back to alphabetical with nothing expanded when location is denied', async () => {
    const fixture = setup({ state: null });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['CA', 'TX']);
    expect(fixture.componentInstance.isStateExpanded('CA')).toBe(false);
    expect(fixture.componentInstance.error()).toBeNull();
  });

  it('ignores a detected state that matches no group', async () => {
    const fixture = setup({ state: 'ZZ' });
    await settle(fixture);
    expect(fixture.componentInstance.orderedStates().map((s) => s.state)).toEqual(['CA', 'TX']);
  });

  it('loads a gym roster on expand and appends on load-more', async () => {
    let call = 0;
    const fixture = setup({
      state: 'TX',
      api: {
        listGymMembers: async () => {
          call += 1;
          return call === 1
            ? { data: [row({ membershipId: 'm-1' })], meta: { page: 1, limit: 1, total: 2 } }
            : { data: [row({ membershipId: 'm-2', userId: 'u-2' })], meta: { page: 2, limit: 1, total: 2 } };
        },
      },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleGym('g-tx');
    await settle(fixture);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1']);
    expect(fixture.componentInstance.hasMore('g-tx', 2)).toBe(true);

    await fixture.componentInstance.loadMore('g-tx');
    await settle(fixture);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1', 'm-2']);
    expect(fixture.componentInstance.hasMore('g-tx', 2)).toBe(false);
  });

  it('rolls back and records a row error when the status update fails', async () => {
    const fixture = setup({
      state: 'TX',
      api: { updateMembership: async () => { throw new Error('nope'); } },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleGym('g-tx');
    await settle(fixture);

    await fixture.componentInstance.setStatus('g-tx', fixture.componentInstance.rowsFor('g-tx')[0]!, 'hidden');
    await settle(fixture);

    expect(fixture.componentInstance.rowsFor('g-tx')[0]!.status).toBe('active');
    expect(fixture.componentInstance.rowError('m-1')).not.toBeNull();
  });

  it('treats the gym owner row as owner-locked', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.isOwnerRow('g-tx', row({ userId: 'u-owner' }))).toBe(true);
    expect(fixture.componentInstance.isOwnerRow('g-tx', row({ userId: 'u-1' }))).toBe(false);
  });

  it('exposes the no-gym count from the tree', async () => {
    const fixture = setup({ state: 'TX' });
    await settle(fixture);
    expect(fixture.componentInstance.noGymCount()).toBe(3);
  });
});
