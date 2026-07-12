import { Component, inject, signal } from '@angular/core';
import { LeadApiService } from '../../../core/lead-api.service';
import type { Utm } from '../../../core/models/i-lead';

type FormState = 'idle' | 'submitting' | 'success' | 'error';

@Component({
  selector: 'app-gym-lead-form',
  imports: [],
  templateUrl: './gym-lead-form.html',
  styleUrl: './gym-lead-form.scss',
})
export class GymLeadForm {

  public readonly gymName = signal<string>('');

  public readonly ownerName = signal<string>('');

  public readonly ownerEmail = signal<string>('');

  public readonly city = signal<string>('');

  public readonly state = signal<string>('');

  public readonly message = signal<string>('');

  public readonly hp = signal<string>('');

  public readonly formState = signal<FormState>('idle');

  public readonly invalid = signal<boolean>(false);

  private readonly api = inject(LeadApiService);

  public async submit(): Promise<void> {
    if (this.formState() === 'submitting') {
      return;
    }

    const gymName = this.gymName().trim();
    const ownerEmail = this.ownerEmail().trim();

    if (gymName === '' || ownerEmail === '') {
      this.invalid.set(true);
      return;
    }

    this.invalid.set(false);
    this.formState.set('submitting');

    const utm: Utm | undefined = this.readUtm();

    try {
      await this.api.submitGymLead({
        gymName,
        ownerEmail,
        ownerName: this.blankToUndefined(this.ownerName()),
        city: this.blankToUndefined(this.city()),
        state: this.blankToUndefined(this.state()),
        message: this.blankToUndefined(this.message()),
        hp: this.hp(),
        utm,
      });
      this.formState.set('success');
    } catch {
      this.formState.set('error');
    }
  }

  private blankToUndefined(value: string): string | undefined {
    const trimmed = value.trim();
    return trimmed === '' ? undefined : trimmed;
  }

  private readUtm(): Utm | undefined {
    const params = new URLSearchParams(window.location.search);
    const source = params.get('utm_source') ?? undefined;
    const medium = params.get('utm_medium') ?? undefined;
    const campaign = params.get('utm_campaign') ?? undefined;

    if (source === undefined && medium === undefined && campaign === undefined) {
      return undefined;
    }

    return { source, medium, campaign };
  }
}
