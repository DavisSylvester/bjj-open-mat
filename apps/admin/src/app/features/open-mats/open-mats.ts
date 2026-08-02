import { Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { OpenMat } from '@/core/models';
import { ZardBadgeComponent } from '@/shared/components/badge';
import { ZardButtonComponent } from '@/shared/components/button';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardFieldImports } from '@/shared/components/field';
import { ZardInputComponent } from '@/shared/components/input';
import { ZardSonnerService } from '@/shared/components/sonner';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

export type OpenMatDialogMode = 'edit' | null;

@Component({
  selector: 'app-open-mats',
  standalone: true,
  imports: [
    FormsModule,
    ZardBadgeComponent,
    ZardButtonComponent,
    ZardEmptyComponent,
    ZardSpinnerComponent,
    ...ZardTableImports,
    ...ZardFieldImports,
    ZardInputComponent,
  ],
  templateUrl: './open-mats.html',
  styleUrl: './open-mats.scss',
  host: { 'data-testid': 'open-mats-page' },
})
export class OpenMats implements OnInit {

  private readonly api = inject(AdminApiService);
  private readonly sonner = inject(ZardSonnerService);

  public readonly openMats = signal<OpenMat[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly total = signal<number>(0);
  public readonly dialogMode = signal<OpenMatDialogMode>(null);
  public readonly selectedOpenMat = signal<OpenMat | null>(null);
  public readonly submitting = signal<boolean>(false);

  public formTitle: string = '';
  public formStartTime: string = '';
  public formEndTime: string = '';
  public formStatus: string = '';

  public async ngOnInit(): Promise<void> {
    await this.loadOpenMats();
  }

  public async loadOpenMats(): Promise<void> {
    this.loading.set(true);
    try {
      const envelope = await this.api.listOpenMats(1, 50);
      this.openMats.set(envelope.data);
      this.total.set(envelope.meta.total);
    } finally {
      this.loading.set(false);
    }
  }

  public openEditDialog(openMat: OpenMat): void {
    this.formTitle = openMat.title;
    this.formStartTime = openMat.startTime;
    this.formEndTime = openMat.endTime;
    this.formStatus = openMat.status;
    this.selectedOpenMat.set(openMat);
    this.dialogMode.set('edit');
  }

  public closeDialog(): void {
    this.dialogMode.set(null);
    this.selectedOpenMat.set(null);
  }

  public async onSubmitEdit(): Promise<void> {
    const openMat = this.selectedOpenMat();
    if (!openMat) {
      return;
    }
    this.submitting.set(true);
    try {
      const body: Partial<OpenMat> = {
        title: this.formTitle.trim(),
        startTime: this.formStartTime.trim(),
        endTime: this.formEndTime.trim(),
        status: this.formStatus.trim(),
      };
      const updated = await this.api.updateOpenMat(openMat.id, body);
      this.openMats.update((list) =>
        list.map((m) => (m.id === updated.id ? updated : m)),
      );
      this.sonner.success('Open mat updated successfully.');
      this.closeDialog();
    } catch {
      this.sonner.error('Failed to update open mat. Please try again.');
    } finally {
      this.submitting.set(false);
    }
  }
}
