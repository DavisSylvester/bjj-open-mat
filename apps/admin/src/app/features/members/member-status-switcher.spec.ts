import type { ComponentFixture} from '@angular/core/testing';
import { TestBed } from '@angular/core/testing';

import { MemberStatusSwitcher, type SettableStatus } from './member-status-switcher';

describe('MemberStatusSwitcher', () => {
  let fixture: ComponentFixture<MemberStatusSwitcher>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({ imports: [MemberStatusSwitcher] }).compileComponents();
    fixture = TestBed.createComponent(MemberStatusSwitcher);
  });

  function segments(): HTMLButtonElement[] {
    return Array.from(fixture.nativeElement.querySelectorAll('button[data-status]'));
  }

  it('renders exactly the three settable statuses — pending is never a target', () => {
    fixture.componentRef.setInput('status', 'pending');
    fixture.detectChanges();
    expect(segments().map((b) => b.dataset['status'])).toEqual(['active', 'hidden', 'inactive']);
  });

  it('marks the current status as selected', () => {
    fixture.componentRef.setInput('status', 'hidden');
    fixture.detectChanges();
    const selected = segments().filter((b) => b.getAttribute('aria-pressed') === 'true');
    expect(selected.map((b) => b.dataset['status'])).toEqual(['hidden']);
  });

  it('selects nothing when the status is pending, so approving is an explicit act', () => {
    fixture.componentRef.setInput('status', 'pending');
    fixture.detectChanges();
    expect(segments().filter((b) => b.getAttribute('aria-pressed') === 'true')).toHaveLength(0);
  });

  it('emits the clicked status', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.detectChanges();
    const emitted: SettableStatus[] = [];
    fixture.componentInstance.statusChange.subscribe((s: SettableStatus) => emitted.push(s));
    segments().find((b) => b.dataset['status'] === 'hidden')!.click();
    expect(emitted).toEqual(['hidden']);
  });

  it('does not re-emit when the current status is clicked', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.detectChanges();
    const emitted: SettableStatus[] = [];
    fixture.componentInstance.statusChange.subscribe((s: SettableStatus) => emitted.push(s));
    segments().find((b) => b.dataset['status'] === 'active')!.click();
    expect(emitted).toEqual([]);
  });

  it('disables hidden and inactive for a gym owner but leaves active enabled', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.componentRef.setInput('isOwner', true);
    fixture.detectChanges();
    const byStatus = new Map(segments().map((b) => [b.dataset['status'], b]));
    expect(byStatus.get('hidden')!.disabled).toBe(true);
    expect(byStatus.get('inactive')!.disabled).toBe(true);
    expect(byStatus.get('active')!.disabled).toBe(false);
  });

  it('disables every segment while busy', () => {
    fixture.componentRef.setInput('status', 'active');
    fixture.componentRef.setInput('busy', true);
    fixture.detectChanges();
    expect(segments().every((b) => b.disabled)).toBe(true);
  });
});
