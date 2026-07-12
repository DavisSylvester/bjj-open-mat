import { Component, inject, input, signal } from '@angular/core';
import { LeadApiService } from '../../../core/lead-api.service';
import type { Utm } from '../../../core/models/i-lead';
import { readUtm, type FormState } from '../../../core/lead-utm';

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

    const utm: Utm = readUtm();

    try {
      await this.api.joinWaitlist({ email: this.email(), hp: this.hp(), utm });
      this.state.set('success');
    } catch {
      this.state.set('error');
    }
  }
}
