import { Component, computed, input, signal } from '@angular/core';

type PhoneVariant = 'app' | 'owner';
type Screen = 'home' | 'detail' | 'checkin' | 'profile';
type RatingKey = 'quality' | 'level' | 'clean' | 'friendly';
type Ratings = Record<RatingKey, number>;

interface StarRow {
  readonly key: RatingKey;
  readonly label: string;
}

@Component({
  selector: 'app-phone-demo',
  imports: [],
  templateUrl: './phone-demo.html',
  styleUrl: './phone-demo.scss',
})
export class PhoneDemo {

  public readonly variant = input<PhoneVariant>('app');

  // ── Frame sizing ──────────────────────────────────────────────
  // Source device canvas is 412x892; scaled down per variant.
  // app (hero): 0.62 -> 255x553 · owner: min(0.62, 0.58) = 0.58 -> 239x517
  public readonly scale = computed<number>(() => (this.variant() === 'owner' ? Math.min(0.62, 0.58) : 0.62));

  public readonly phoneW = computed<number>(() => Math.round(412 * this.scale()));

  public readonly phoneH = computed<number>(() => Math.round(892 * this.scale()));

  // ── Interactive demo state (app variant only) ─────────────────
  public readonly screen = signal<Screen>('home');

  public readonly going = signal<boolean>(false);

  public readonly checkedIn = signal<boolean>(false);

  public readonly ratings = signal<Ratings>({ quality: 0, level: 0, clean: 0, friendly: 0 });

  public readonly starRows: readonly StarRow[] = [
    { key: 'quality', label: 'Gym Quality' },
    { key: 'level', label: 'Level Match' },
    { key: 'clean', label: 'Cleanliness' },
    { key: 'friendly', label: 'Friendliness' },
  ];

  // ── Derived (mirror of the source renderVals) ─────────────────
  public readonly isHome = computed<boolean>(() => this.screen() === 'home');

  public readonly isDetail = computed<boolean>(() => this.screen() === 'detail');

  public readonly isCheckin = computed<boolean>(() => this.screen() === 'checkin');

  public readonly isProfile = computed<boolean>(() => this.screen() === 'profile');

  public readonly showNav = computed<boolean>(() => this.screen() === 'home' || this.screen() === 'profile');

  public readonly rsvpLabel = computed<string>(() => (this.going() ? "You're going ✓" : "I'm going"));

  public readonly rsvpBg = computed<string>(() => (this.going() ? '#16C79A' : '#E94560'));

  public readonly rsvpShadow = computed<string>(() => (this.going() ? 'rgba(22,199,154,0.33)' : 'rgba(233,69,96,0.33)'));

  public readonly goingCount = computed<string>(() => `${this.going() ? 4 : 3} going`);

  public readonly matCount = computed<number>(() => (this.checkedIn() ? 28 : 27));

  public readonly reviewCount = computed<number>(() => (this.checkedIn() ? 9 : 8));

  public readonly navHomeBg = computed<string>(() => (this.screen() === 'home' ? 'rgba(233,69,96,0.09)' : 'transparent'));

  public readonly navHomeColor = computed<string>(() => (this.screen() === 'home' ? '#E94560' : 'rgba(15,20,48,0.55)'));

  public readonly navProfileBg = computed<string>(() => (this.screen() === 'profile' ? 'rgba(233,69,96,0.09)' : 'transparent'));

  public readonly navProfileColor = computed<string>(() => (this.screen() === 'profile' ? '#E94560' : 'rgba(15,20,48,0.55)'));

  // ── Actions ───────────────────────────────────────────────────
  public goHome(): void {
    this.screen.set('home');
  }

  public goDetail(): void {
    this.screen.set('detail');
  }

  public goProfile(): void {
    this.screen.set('profile');
  }

  public goCheckin(): void {
    this.screen.set('checkin');
  }

  public toggleGoing(): void {
    this.going.update((v) => !v);
  }

  public postReview(): void {
    this.checkedIn.set(true);
    this.screen.set('profile');
  }

  public setStar(key: RatingKey, i: number): void {
    this.ratings.update((r) => ({ ...r, [key]: i + 1 }));
  }

  public starColor(key: RatingKey, i: number): string {
    return i < this.ratings()[key] ? '#FFC857' : 'rgba(20,20,40,0.18)';
  }
}
