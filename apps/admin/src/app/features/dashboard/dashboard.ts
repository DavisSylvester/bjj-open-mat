import { Component, inject, OnInit, signal } from '@angular/core';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { AdminOpenMatsByState, AdminOverviewStats } from '@/core/models';
import {
  ZardCardComponent,
  ZardCardContentComponent,
  ZardCardHeaderComponent,
  ZardCardTitleComponent,
} from '@/shared/components/card';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    ZardCardComponent,
    ZardCardHeaderComponent,
    ZardCardTitleComponent,
    ZardCardContentComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
  host: { 'data-testid': 'dashboard-page' },
})
export class Dashboard implements OnInit {

  private readonly api = inject(AdminApiService);

  public readonly overview = signal<AdminOverviewStats | null>(null);
  public readonly openMats = signal<AdminOpenMatsByState | null>(null);
  public readonly loading = signal<boolean>(true);

  public async ngOnInit(): Promise<void> {
    this.loading.set(true);
    try {
      const [overviewData, openMatsData] = await Promise.all([
        this.api.getOverview(),
        this.api.getOpenMatsByState(10),
      ]);
      this.overview.set(overviewData);
      this.openMats.set(openMatsData);
    } finally {
      this.loading.set(false);
    }
  }
}
