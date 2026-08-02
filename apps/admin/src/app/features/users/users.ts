import { Component, inject, OnInit, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { User } from '@/core/models';
import { ZardBadgeComponent } from '@/shared/components/badge';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

@Component({
  selector: 'app-users',
  standalone: true,
  imports: [
    ZardBadgeComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
  ],
  templateUrl: './users.html',
  styleUrl: './users.scss',
  host: { 'data-testid': 'users-page' },
})
export class Users implements OnInit {

  private readonly api = inject(AdminApiService);

  public readonly users = signal<User[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly total = signal<number>(0);

  public async ngOnInit(): Promise<void> {
    this.loading.set(true);
    try {
      const envelope = await this.api.listUsers(1, 50);
      this.users.set(envelope.data);
      this.total.set(envelope.meta.total);
    } finally {
      this.loading.set(false);
    }
  }

  public formatDate(value: string | undefined): string {
    if (!value) {
      return '—';
    }
    return new Date(value).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  public formatLocation(city: string | undefined, state: string | undefined): string {
    if (city && state) {
      return `${city}, ${state}`;
    }
    if (state) {
      return state;
    }
    if (city) {
      return city;
    }
    return '—';
  }
}
