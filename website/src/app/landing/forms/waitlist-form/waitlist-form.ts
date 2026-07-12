import { Component, input } from '@angular/core';

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
}
