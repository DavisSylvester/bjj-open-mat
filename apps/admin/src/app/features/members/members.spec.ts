import type { ComponentFixture} from '@angular/core/testing';
import { TestBed } from '@angular/core/testing';

import { Members } from './members';
import { AdminApiService } from '@/core/api/admin-api.service';
import { GeoApiService } from '@/core/api/geo-api.service';
import type { AdminMembersTree, AdminRosterRow, ListEnvelope, NoGymUserRow } from '@/core/models';

interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void;
}

function deferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => { resolve = res; });
  return { promise, resolve };
}

function noGymUser(userId: string): NoGymUserRow {
  return { userId, displayName: userId, email: `${userId}@e.dev`, createdAt: '2026-08-01T00:00:00.000Z' };
}

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

  it('ignores a second load-more while the first is still in flight', async () => {
    let calls = 0;
    const gate = deferred<ListEnvelope<AdminRosterRow>>();
    const fixture = setup({
      state: 'TX',
      api: {
        listGymMembers: async () => {
          calls += 1;
          if (calls === 1) return { data: [row({ membershipId: 'm-1' })], meta: { page: 1, limit: 1, total: 3 } };
          return gate.promise;
        },
      },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleGym('g-tx');
    await settle(fixture);

    const first = fixture.componentInstance.loadMore('g-tx');
    const second = fixture.componentInstance.loadMore('g-tx');
    gate.resolve({ data: [row({ membershipId: 'm-2', userId: 'u-2' })], meta: { page: 2, limit: 1, total: 3 } });
    await Promise.all([first, second]);
    await settle(fixture);

    expect(calls).toBe(2);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1', 'm-2']);
  });

  it('does not re-fetch page 1 when a gym is collapsed and re-expanded mid-flight', async () => {
    let calls = 0;
    const gate = deferred<ListEnvelope<AdminRosterRow>>();
    const fixture = setup({
      state: 'TX',
      api: {
        listGymMembers: async () => {
          calls += 1;
          return gate.promise;
        },
      },
    });
    await settle(fixture);

    const first = fixture.componentInstance.toggleGym('g-tx');
    await fixture.componentInstance.toggleGym('g-tx');
    const third = fixture.componentInstance.toggleGym('g-tx');
    gate.resolve({ data: [row({ membershipId: 'm-1' })], meta: { page: 1, limit: 50, total: 1 } });
    await Promise.all([first, third]);
    await settle(fixture);

    expect(calls).toBe(1);
    expect(fixture.componentInstance.rowsFor('g-tx').map((r) => r.membershipId)).toEqual(['m-1']);
  });

  it('records a group error instead of rejecting when the no-gym fetch fails', async () => {
    const fixture = setup({
      state: 'TX',
      api: { listNoGymUsers: async () => { throw new Error('nope'); } },
    });
    await settle(fixture);

    await fixture.componentInstance.toggleNoGym();
    await settle(fixture);

    expect(fixture.componentInstance.groupError('__no_gym__')).not.toBeNull();
    expect(fixture.componentInstance.noGymUsers()).toEqual([]);
  });

  it('clears the no-gym error and loads on retry', async () => {
    let calls = 0;
    const fixture = setup({
      state: 'TX',
      api: {
        listNoGymUsers: async () => {
          calls += 1;
          if (calls === 1) throw new Error('nope');
          return { data: [noGymUser('u-1')], meta: { page: 1, limit: 50, total: 3 } };
        },
      },
    });
    await settle(fixture);
    await fixture.componentInstance.toggleNoGym();
    await settle(fixture);
    expect(fixture.componentInstance.groupError('__no_gym__')).not.toBeNull();

    await fixture.componentInstance.loadMoreNoGym();
    await settle(fixture);

    expect(fixture.componentInstance.groupError('__no_gym__')).toBeNull();
    expect(fixture.componentInstance.noGymUsers().map((u) => u.userId)).toEqual(['u-1']);
  });

  it('pages the no-gym group until its total is reached', async () => {
    let calls = 0;
    const fixture = setup({
      state: 'TX',
      api: {
        listNoGymUsers: async () => {
          calls += 1;
          return calls === 1
            ? { data: [noGymUser('u-1'), noGymUser('u-2')], meta: { page: 1, limit: 2, total: 3 } }
            : { data: [noGymUser('u-3')], meta: { page: 2, limit: 2, total: 3 } };
        },
      },
    });
    await settle(fixture);

    await fixture.componentInstance.toggleNoGym();
    await settle(fixture);
    expect(fixture.componentInstance.hasMoreNoGym()).toBe(true);

    await fixture.componentInstance.loadMoreNoGym();
    await settle(fixture);

    expect(fixture.componentInstance.noGymUsers().map((u) => u.userId)).toEqual(['u-1', 'u-2', 'u-3']);
    expect(fixture.componentInstance.hasMoreNoGym()).toBe(false);
  });

  it('reports a genuinely empty tree as empty', async () => {
    const fixture = setup({
      api: { getMembersTree: async (): Promise<AdminMembersTree> => ({ states: [], noState: [], noGym: { userCount: 0 } }) },
    });
    await settle(fixture);
    expect(fixture.componentInstance.isEmpty()).toBe(true);
    expect(fixture.nativeElement.querySelector('[data-testid="members-empty"]')).not.toBeNull();
  });

  it('does not report a tree carrying only gymless users as empty', async () => {
    const fixture = setup({
      api: { getMembersTree: async (): Promise<AdminMembersTree> => ({ states: [], noState: [], noGym: { userCount: 4 } }) },
    });
    await settle(fixture);
    expect(fixture.componentInstance.isEmpty()).toBe(false);
  });
});
