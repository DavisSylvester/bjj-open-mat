import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { Gym, OpenMat } from '@/core/models';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

@Component({
  selector: 'app-schedules',
  standalone: true,
  imports: [
    FormsModule,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
  ],
  templateUrl: './schedules.html',
  styleUrl: './schedules.scss',
  host: { 'data-testid': 'schedules-page' },
})
export class Schedules implements OnInit {

  private readonly api = inject(AdminApiService);

  public readonly gyms = signal<Gym[]>([]);
  public readonly allOpenMats = signal<OpenMat[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly selectedGymId = signal<string>('');

  public readonly filteredOpenMats = computed<OpenMat[]>(() => {
    const gymId = this.selectedGymId();
    if (!gymId) {
      return [];
    }
    return this.allOpenMats().filter((m) => m.gymId === gymId);
  });

  public async ngOnInit(): Promise<void> {
    this.loading.set(true);
    try {
      const [gymsEnvelope, openMatsEnvelope] = await Promise.all([
        this.api.listGyms(1, 100),
        this.api.listOpenMats(1, 200),
      ]);
      this.gyms.set(gymsEnvelope.data);
      this.allOpenMats.set(openMatsEnvelope.data);
    } finally {
      this.loading.set(false);
    }
  }

  public onGymChange(gymId: string): void {
    this.selectedGymId.set(gymId);
  }
}
