// Value import, not `import type`: the guard below uses `instanceof`.
import { HttpErrorResponse } from '@angular/common/http';
import { NgTemplateOutlet } from '@angular/common';
import type { OnInit } from '@angular/core';
import { Component, computed, inject, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import { GeoApiService } from '@/core/api/geo-api.service';
import type {
  AdminMembersTree,
  AdminRosterRow,
  GymSummary,
  NoGymUserRow,
  StateGroup,
} from '@/core/models';
import { ZardBadgeComponent, type ZardBadgeTypeVariants } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { MemberStatusSwitcher, type SettableStatus } from './member-status-switcher';

const PAGE_SIZE = 50;
const DEFAULT_UPDATE_ERROR = 'Could not update that member. Please try again.';

function isHttpErrorResponse(err: unknown): err is HttpErrorResponse {
  return err instanceof HttpErrorResponse;
}

/**
 * Narrows an unknown thrown value down to the API's error envelope
 * (`{ error: { code, message, details? } }`) and extracts its message,
 * falling back to a generic message when the shape doesn't match.
 */
function extractErrorMessage(err: unknown): string {
  if (!isHttpErrorResponse(err)) return DEFAULT_UPDATE_ERROR;
  const body: unknown = err.error;
  if (typeof body !== 'object' || body === null || !('error' in body)) return DEFAULT_UPDATE_ERROR;
  const inner: unknown = (body as { error: unknown }).error;
  if (typeof inner !== 'object' || inner === null || !('message' in inner)) return DEFAULT_UPDATE_ERROR;
  const message: unknown = (inner as { message: unknown }).message;
  return typeof message === 'string' && message.length > 0 ? message : DEFAULT_UPDATE_ERROR;
}

@Component({
  selector: 'app-members',
  standalone: true,
  imports: [
    NgTemplateOutlet,
    ZardBadgeComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    MemberStatusSwitcher,
  ],
  templateUrl: './members.html',
  styleUrl: './members.scss',
  host: { 'data-testid': 'members-page' },
})
export class Members implements OnInit {

  private readonly api = inject(AdminApiService);
  private readonly geo = inject(GeoApiService);

  public readonly tree = signal<AdminMembersTree | null>(null);
  public readonly loading = signal<boolean>(true);
  public readonly error = signal<string | null>(null);
  public readonly detectedState = signal<string | null>(null);

  private readonly expandedStates = signal<ReadonlySet<string>>(new Set<string>());
  private readonly expandedGyms = signal<ReadonlySet<string>>(new Set<string>());
  private readonly rows = signal<ReadonlyMap<string, AdminRosterRow[]>>(new Map());
  private readonly pages = signal<ReadonlyMap<string, number>>(new Map());
  private readonly busyRows = signal<ReadonlySet<string>>(new Set<string>());
  private readonly rowErrors = signal<ReadonlyMap<string, string>>(new Map());
  private readonly groupErrors = signal<ReadonlyMap<string, string>>(new Map());

  public readonly noGymUsers = signal<NoGymUserRow[]>([]);

  public readonly noGymCount = computed<number>(() => this.tree()?.noGym.userCount ?? 0);
  public readonly noStateGyms = computed<GymSummary[]>(() => this.tree()?.noState ?? []);

  /**
   * Detected state first, everything else alphabetically. Detection only
   * changes order and which group starts open — no group is ever hidden, so a
   * wrong or missing detection costs nothing but a scroll.
   */
  public readonly orderedStates = computed<StateGroup[]>(() => {
    const groups: StateGroup[] = [...(this.tree()?.states ?? [])];
    groups.sort((a, b) => a.state.localeCompare(b.state));
    const detected: string | null = this.detectedState();
    if (detected === null) return groups;
    const index: number = groups.findIndex((g) => g.state === detected);
    if (index < 0) return groups;
    const [match] = groups.splice(index, 1);
    return match ? [match, ...groups] : groups;
  });

  public async ngOnInit(): Promise<void> {
    await this.load();
  }

  public isStateExpanded(state: string): boolean {
    return this.expandedStates().has(state);
  }

  public isGymExpanded(gymId: string): boolean {
    return this.expandedGyms().has(gymId);
  }

  public rowsFor(gymId: string): AdminRosterRow[] {
    return this.rows().get(gymId) ?? [];
  }

  public hasMore(gymId: string, memberCount: number): boolean {
    return this.rowsFor(gymId).length < memberCount;
  }

  public isRowBusy(membershipId: string): boolean {
    return this.busyRows().has(membershipId);
  }

  public rowError(membershipId: string): string | null {
    return this.rowErrors().get(membershipId) ?? null;
  }

  public groupError(gymId: string): string | null {
    return this.groupErrors().get(gymId) ?? null;
  }

  public isOwnerRow(gymId: string, row: AdminRosterRow): boolean {
    const gym: GymSummary | undefined = this.findGym(gymId);
    return gym?.ownerId !== undefined && gym.ownerId === row.userId;
  }

  public badgeType(status: AdminRosterRow['status']): ZardBadgeTypeVariants {
    if (status === 'active') return 'default';
    if (status === 'inactive') return 'destructive';
    if (status === 'pending') return 'secondary';
    return 'outline';
  }

  public toggleState(state: string): void {
    this.expandedStates.update((set) => toggle(set, state));
  }

  public async toggleGym(gymId: string): Promise<void> {
    const wasExpanded: boolean = this.isGymExpanded(gymId);
    this.expandedGyms.update((set) => toggle(set, gymId));
    if (wasExpanded || this.rows().has(gymId)) return;
    await this.fetchPage(gymId, 1);
  }

  public async loadMore(gymId: string): Promise<void> {
    const next: number = (this.pages().get(gymId) ?? 1) + 1;
    await this.fetchPage(gymId, next);
  }

  public async toggleNoGym(): Promise<void> {
    const wasExpanded: boolean = this.isGymExpanded('__no_gym__');
    this.expandedGyms.update((set) => toggle(set, '__no_gym__'));
    if (wasExpanded || this.noGymUsers().length > 0) return;
    const envelope = await this.api.listNoGymUsers(1, PAGE_SIZE);
    this.noGymUsers.set(envelope.data);
  }

  /**
   * Optimistic: the row moves immediately and reverts if the API rejects it.
   * The error lands on the row rather than the page, because one member's
   * failed toggle is not a broken page.
   */
  public async setStatus(gymId: string, row: AdminRosterRow, status: SettableStatus): Promise<void> {
    if (this.isRowBusy(row.membershipId)) return;
    const previous: AdminRosterRow['status'] = row.status;

    this.busyRows.update((s) => addToSet(s, row.membershipId));
    this.rowErrors.update((map) => withoutEntry(map, row.membershipId));
    this.patchRow(gymId, row.membershipId, { status });

    try {
      await this.api.updateMembership(gymId, row.userId, { status });
    } catch (err) {
      this.patchRow(gymId, row.membershipId, { status: previous });
      this.rowErrors.update((map) => withEntry(map, row.membershipId, extractErrorMessage(err)));
    } finally {
      this.busyRows.update((s) => removeFromSet(s, row.membershipId));
    }
  }

  public async retryTree(): Promise<void> {
    await this.load();
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const tree: AdminMembersTree = await this.api.getMembersTree();
      this.tree.set(tree);
      // Detection runs after the tree so the page never waits on the browser's
      // permission prompt to render.
      void this.applyDetectedState();
    } catch (err) {
      this.error.set(extractErrorMessage(err));
    } finally {
      this.loading.set(false);
    }
  }

  private async applyDetectedState(): Promise<void> {
    const state: string | null = await this.geo.detectState();
    if (state === null) return;
    const known: boolean = (this.tree()?.states ?? []).some((g) => g.state === state);
    if (!known) return;
    this.detectedState.set(state);
    this.expandedStates.update((s) => addToSet(s, state));
  }

  private async fetchPage(gymId: string, page: number): Promise<void> {
    this.groupErrors.update((map) => withoutEntry(map, gymId));
    try {
      const envelope = await this.api.listGymMembers(gymId, page, PAGE_SIZE);
      this.rows.update((map) => {
        const next = new Map(map);
        next.set(gymId, [...(map.get(gymId) ?? []), ...envelope.data]);
        return next;
      });
      this.pages.update((map) => new Map(map).set(gymId, page));
    } catch (err) {
      this.groupErrors.update((map) => withEntry(map, gymId, extractErrorMessage(err)));
    }
  }

  private patchRow(gymId: string, membershipId: string, patch: Partial<AdminRosterRow>): void {
    this.rows.update((map) => {
      const current: AdminRosterRow[] = map.get(gymId) ?? [];
      const next = new Map(map);
      next.set(gymId, current.map((r) => (r.membershipId === membershipId ? { ...r, ...patch } : r)));
      return next;
    });
  }

  private findGym(gymId: string): GymSummary | undefined {
    const t: AdminMembersTree | null = this.tree();
    if (!t) return undefined;
    for (const group of t.states) {
      const found: GymSummary | undefined = group.gyms.find((g) => g.id === gymId);
      if (found) return found;
    }
    return t.noState.find((g) => g.id === gymId);
  }
}

// Sets and maps are replaced rather than mutated, so signal `update` always
// sees a new reference. Separate helpers per container type — one generic
// `remove` cannot be typed across both a Set and a Map.
function toggle(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  const next = new Set(current);
  if (!next.delete(key)) next.add(key);
  return next;
}

function addToSet(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  return new Set(current).add(key);
}

function removeFromSet(current: ReadonlySet<string>, key: string): ReadonlySet<string> {
  const next = new Set(current);
  next.delete(key);
  return next;
}

function withEntry(
  current: ReadonlyMap<string, string>,
  key: string,
  value: string,
): ReadonlyMap<string, string> {
  return new Map(current).set(key, value);
}

function withoutEntry(
  current: ReadonlyMap<string, string>,
  key: string,
): ReadonlyMap<string, string> {
  const next = new Map(current);
  next.delete(key);
  return next;
}
