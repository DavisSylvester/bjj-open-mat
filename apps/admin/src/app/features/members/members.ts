import { Component, inject, OnInit, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { GymMembership } from '@/core/models';
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

  public async ngOnInit(): Promise<void> {
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
