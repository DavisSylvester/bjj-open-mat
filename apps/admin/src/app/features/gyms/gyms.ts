import { Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { AdminApiService } from '@/core/api/admin-api.service';
import type { CreateGymBody, Gym } from '@/core/models';
import { ZardBadgeComponent } from '@/shared/components/badge';
import { ZardButtonComponent } from '@/shared/components/button';
import { ZardEmptyComponent } from '@/shared/components/empty';
import { ZardFieldImports } from '@/shared/components/field';
import { ZardInputComponent } from '@/shared/components/input';
import { ZardSonnerService } from '@/shared/components/sonner';
import { ZardSpinnerComponent } from '@/shared/components/spinner/spinner.component';
import { ZardTableImports } from '@/shared/components/table';

export type DialogMode = 'create' | 'edit' | 'add-owner' | 'invite' | null;

@Component({
  selector: 'app-gyms',
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
  templateUrl: './gyms.html',
  styleUrl: './gyms.scss',
  host: { 'data-testid': 'gyms-page' },
})
export class Gyms implements OnInit {

  private readonly api = inject(AdminApiService);
  private readonly sonner = inject(ZardSonnerService);

  public readonly gyms = signal<Gym[]>([]);
  public readonly loading = signal<boolean>(true);
  public readonly total = signal<number>(0);
  public readonly dialogMode = signal<DialogMode>(null);
  public readonly selectedGym = signal<Gym | null>(null);
  public readonly submitting = signal<boolean>(false);

  // Create / Edit form fields
  public formName = '';
  public formAddress = '';
  public formCity = '';
  public formState = '';

  // Add owner form field
  public formUserId = '';

  // Invite form field
  public formEmails = '';

  public async ngOnInit(): Promise<void> {
    await this.loadGyms();
  }

  public async loadGyms(): Promise<void> {
    this.loading.set(true);
    try {
      const envelope = await this.api.listGyms(1, 50);
      this.gyms.set(envelope.data);
      this.total.set(envelope.meta.total);
    } finally {
      this.loading.set(false);
    }
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

  public isCreateFormValid(): boolean {
    return this.formName.trim().length > 0 && this.formAddress.trim().length > 0;
  }

  public openCreateDialog(): void {
    this.formName = '';
    this.formAddress = '';
    this.formCity = '';
    this.formState = '';
    this.selectedGym.set(null);
    this.dialogMode.set('create');
  }

  public openEditDialog(gym: Gym): void {
    this.formName = gym.name;
    this.formAddress = gym.address;
    this.formCity = gym.city ?? '';
    this.formState = gym.state ?? '';
    this.selectedGym.set(gym);
    this.dialogMode.set('edit');
  }

  public openAddOwnerDialog(gym: Gym): void {
    this.formUserId = '';
    this.selectedGym.set(gym);
    this.dialogMode.set('add-owner');
  }

  public openInviteDialog(gym: Gym): void {
    this.formEmails = '';
    this.selectedGym.set(gym);
    this.dialogMode.set('invite');
  }

  public closeDialog(): void {
    this.dialogMode.set(null);
    this.selectedGym.set(null);
  }

  public async onVerify(gym: Gym): Promise<void> {
    try {
      const updated = await this.api.verifyGym(gym.id);
      this.gyms.update((list) =>
        list.map((g) => (g.id === updated.id ? updated : g)),
      );
      this.sonner.success(`${gym.name} verified successfully.`);
    } catch {
      this.sonner.error('Failed to verify gym. Please try again.');
    }
  }

  public async onSubmitCreate(): Promise<void> {
    if (!this.isCreateFormValid()) {
      return;
    }
    this.submitting.set(true);
    try {
      const body: CreateGymBody = {
        name: this.formName.trim(),
        address: this.formAddress.trim(),
        city: this.formCity.trim() || undefined,
        state: this.formState.trim() || undefined,
      };
      await this.api.createGym(body);
      this.sonner.success('Gym created successfully.');
      this.closeDialog();
      await this.loadGyms();
    } catch {
      this.sonner.error('Failed to create gym. Please try again.');
    } finally {
      this.submitting.set(false);
    }
  }

  public async onSubmitEdit(): Promise<void> {
    const gym = this.selectedGym();
    if (!gym) {
      return;
    }
    this.submitting.set(true);
    try {
      const body: Partial<Gym> = {
        name: this.formName.trim(),
        address: this.formAddress.trim(),
        city: this.formCity.trim() || undefined,
        state: this.formState.trim() || undefined,
      };
      const updated = await this.api.updateGym(gym.id, body);
      this.gyms.update((list) =>
        list.map((g) => (g.id === updated.id ? updated : g)),
      );
      this.sonner.success('Gym updated successfully.');
      this.closeDialog();
    } catch {
      this.sonner.error('Failed to update gym. Please try again.');
    } finally {
      this.submitting.set(false);
    }
  }

  public async onSubmitAddOwner(): Promise<void> {
    const gym = this.selectedGym();
    if (!gym || !this.formUserId.trim()) {
      return;
    }
    this.submitting.set(true);
    try {
      const updated = await this.api.addOwner(gym.id, this.formUserId.trim());
      this.gyms.update((list) =>
        list.map((g) => (g.id === updated.id ? updated : g)),
      );
      this.sonner.success('Owner added successfully.');
      this.closeDialog();
    } catch {
      this.sonner.error('Failed to add owner. Please try again.');
    } finally {
      this.submitting.set(false);
    }
  }

  public async onSubmitInvite(): Promise<void> {
    const gym = this.selectedGym();
    if (!gym || !this.formEmails.trim()) {
      return;
    }
    this.submitting.set(true);
    try {
      const emails = this.formEmails
        .split(',')
        .map((e) => e.trim())
        .filter((e) => e.length > 0);
      const result = await this.api.invite(gym.id, emails);
      this.sonner.success(`Invited ${result.invited} member(s) successfully.`);
      this.closeDialog();
    } catch {
      this.sonner.error('Failed to send invites. Please try again.');
    } finally {
      this.submitting.set(false);
    }
  }
}
