import { Component, computed, input } from '@angular/core';

type PhoneVariant = 'app' | 'owner';

@Component({
  selector: 'app-phone-demo',
  imports: [],
  templateUrl: './phone-demo.html',
  styleUrl: './phone-demo.scss',
})
export class PhoneDemo {

  public readonly variant = input<PhoneVariant>('app');

  // Source device canvas is 412x892; scaled down per variant.
  // app (hero): 0.62 -> 255x553 · owner: 0.58 -> 239x517
  private readonly scale = computed<number>(() => (this.variant() === 'owner' ? 0.58 : 0.62));

  public readonly phoneW = computed<number>(() => Math.round(412 * this.scale()));

  public readonly phoneH = computed<number>(() => Math.round(892 * this.scale()));
}
