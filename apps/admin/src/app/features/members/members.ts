import type { OnInit } from '@angular/core';
import { Component, inject, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { GymMembership, MembershipStatus } from '@/core/models';
import { ZardBadgeComponent } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

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
  public readonly busyId = signal<string | null>(null);
  public readonly error = signal<string | null>(null);

  public async ngOnInit(): Promise<void> {
    await this.load();
  }

  public async setStatus(member: GymMembership, status: MembershipStatus): Promise<void> {
    if (this.busyId() !== null) return;
    this.busyId.set(member.id);
    this.error.set(null);
    try {
      const updated = await this.api.updateMembership(member.gymId, member.userId, { status });
      this.members.update((rows) => rows.map((r) => (r.id === updated.id ? updated : r)));
    } catch {
      this.error.set('Could not update that member. Please try again.');
    } finally {
      this.busyId.set(null);
    }
  }

  public badgeType(status: MembershipStatus | undefined): 'default' | 'destructive' | 'outline' {
    if (status === 'active' || status === undefined) return 'default';
    if (status === 'inactive') return 'destructive';
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
