import { Component, inject, input, signal } from '@angular/core';
import { LeadApiService } from '../../../core/lead-api.service';
import type { Utm } from '../../../core/models/i-lead';

type FormState = 'idle' | 'submitting' | 'success' | 'error';

@Component({
  selector: 'app-waitlist-form',
  imports: [],
  templateUrl: './waitlist-form.html',
  styleUrl: './waitlist-form.scss',
})
export class WaitlistForm {

  public readonly label = input<string>('Join the founding list');

  public readonly microcopy = input<string | undefined>(undefined);

  public readonly maxWidth = input<string>('480px');

  public readonly email = signal<string>('');

  public readonly hp = signal<string>('');

  public readonly state = signal<FormState>('idle');

  private readonly api = inject(LeadApiService);

  public async submit(): Promise<void> {
    if (this.state() === 'submitting') {
      return;
    }

    this.state.set('submitting');

    const utm: Utm | undefined = this.readUtm();

    try {
      await this.api.joinWaitlist({ email: this.email(), hp: this.hp(), utm });
      this.state.set('success');
    } catch {
      this.state.set('error');
    }
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
