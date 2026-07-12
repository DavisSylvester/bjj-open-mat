import { TestBed } from '@angular/core/testing';
import { PhoneDemo } from './phone-demo';

describe('PhoneDemo', () => {
  function setup(): PhoneDemo {
    TestBed.configureTestingModule({});
    return TestBed.createComponent(PhoneDemo).componentInstance;
  }

  it('app variant defaults to the home screen with nav visible', () => {
    const cmp = setup();

    expect(cmp.variant()).toBe('app');
    expect(cmp.screen()).toBe('home');
    expect(cmp.isHome()).toBe(true);
    expect(cmp.showNav()).toBe(true);
  });

  it('goDetail() navigates to the detail screen and hides nav', () => {
    const cmp = setup();

    cmp.goDetail();

    expect(cmp.screen()).toBe('detail');
    expect(cmp.isDetail()).toBe(true);
    expect(cmp.showNav()).toBe(false);
  });

  it('toggleGoing() flips going and swaps the RSVP label/background', () => {
    const cmp = setup();

    expect(cmp.going()).toBe(false);
    expect(cmp.rsvpLabel()).toBe("I'm going");
    expect(cmp.rsvpBg()).toBe('#E94560');

    cmp.toggleGoing();

    expect(cmp.going()).toBe(true);
    expect(cmp.rsvpLabel()).toBe("You're going ✓");
    expect(cmp.rsvpBg()).toBe('#16C79A');
    expect(cmp.goingCount()).toBe('4 going');
  });

  it('setStar() sets the rating to i + 1 (tapping the 3rd star sets 3)', () => {
    const cmp = setup();

    cmp.setStar('quality', 2);

    expect(cmp.ratings().quality).toBe(3);
    expect(cmp.starColor('quality', 0)).toBe('#FFC857');
    expect(cmp.starColor('quality', 2)).toBe('#FFC857');
    expect(cmp.starColor('quality', 3)).toBe('rgba(20,20,40,0.18)');
  });

  it('postReview() sets checkedIn and navigates to the profile screen', () => {
    const cmp = setup();

    cmp.postReview();

    expect(cmp.checkedIn()).toBe(true);
    expect(cmp.screen()).toBe('profile');
    expect(cmp.isProfile()).toBe(true);
    expect(cmp.matCount()).toBe(28);
    expect(cmp.reviewCount()).toBe(9);
  });

  it('owner variant uses the 0.58 scale', () => {
    TestBed.configureTestingModule({});
    const fixture = TestBed.createComponent(PhoneDemo);
    fixture.componentRef.setInput('variant', 'owner');
    const cmp = fixture.componentInstance;

    expect(cmp.scale()).toBe(0.58);
    expect(cmp.phoneW()).toBe(Math.round(412 * 0.58));
  });
});
