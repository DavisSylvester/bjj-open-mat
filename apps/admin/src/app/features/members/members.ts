import type { HttpErrorResponse } from '@angular/common/http';
import type { OnInit } from '@angular/core';
import { Component, inject, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { GymMembership, MembershipStatus } from '@/core/models';
import { ZardBadgeComponent, type ZardBadgeTypeVariants } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

const DEFAULT_UPDATE_ERROR = 'Could not update that member. Please try again.';

function isHttpErrorResponse(err: unknown): err is HttpErrorResponse {
  return typeof err === 'object' && err !== null && 'error' in err;
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
    ZardBadgeComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
  ],
  templateUrl: './members.html',
  styleUrl: './members.scss',
  host: { 'data-testid': 'members-page' },
})
export class Members implements OnInit {

  private readonly api = inject(AdminApiService);

  public readonly members = signal<GymMembership[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly total = signal<number>(0);
  public readonly busyIds = signal<ReadonlySet<string>>(new Set<string>());
  public readonly error = signal<string | null>(null);

  public async ngOnInit(): Promise<void> {
    await this.load();
  }

  public isBusy(memberId: string): boolean {
    return this.busyIds().has(memberId);
  }

  public async setStatus(member: GymMembership, status: MembershipStatus): Promise<void> {
    if (this.busyIds().has(member.id)) return;
    this.busyIds.update((ids) => new Set(ids).add(member.id));
    this.error.set(null);
    try {
      const updated = await this.api.updateMembership(member.gymId, member.userId, { status });
      this.members.update((rows) => rows.map((r) => (r.id === updated.id ? updated : r)));
    } catch (err) {
      this.error.set(extractErrorMessage(err));
    } finally {
      this.busyIds.update((ids) => {
        const next = new Set(ids);
        next.delete(member.id);
        return next;
      });
    }
  }

  public badgeType(status: MembershipStatus | undefined): ZardBadgeTypeVariants {
    if (status === 'active' || status === undefined) return 'default';
    if (status === 'inactive') return 'destructive';
    if (status === 'pending') return 'secondary';
    return 'outline';
  }

  private async load(): Promise<void> {
    this.loading.set(true);
    try {
      const envelope = await this.api.listMembers(1, 50);
      this.members.set(envelope.data);
      this.total.set(envelope.meta.total);
    } finally {
      this.loading.set(false);
    }
  }
}
