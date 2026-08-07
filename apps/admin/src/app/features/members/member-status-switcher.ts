import { ChangeDetectionStrategy, Component, EventEmitter, Output, input } from '@angular/core';

import type { MembershipStatus } from '@/core/models';

/** The statuses an admin may assign. Mirrors ManageableMembershipStatus in the
 *  contract: `pending` is owned by the join flow and the API rejects it. */
export type SettableStatus = 'active' | 'hidden' | 'inactive';

const SEGMENTS: readonly { value: SettableStatus; label: string }[] = [
  { value: 'active', label: 'Active' },
  { value: 'hidden', label: 'Hidden' },
  { value: 'inactive', label: 'Inactive' },
];

/**
 * Segmented status control for one membership.
 *
 * Current state and available actions are the same control, so the row reads
 * once. Clicking Active on a pending member is the approve action; pending is
 * never a target, because the API returns 400 for it.
 */
@Component({
  selector: 'app-member-status-switcher',
  standalone: true,
  templateUrl: './member-status-switcher.html',
  styleUrl: './member-status-switcher.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'data-testid': 'status-switcher' },
})
export class MemberStatusSwitcher {

  public readonly status = input.required<MembershipStatus>();
  public readonly isOwner = input<boolean>(false);
  public readonly busy = input<boolean>(false);

  @Output() public readonly statusChange = new EventEmitter<SettableStatus>();

  public readonly segments = SEGMENTS;

  public isSelected(value: SettableStatus): boolean {
    return this.status() === value;
  }

  /** A gym's owner cannot be hidden or deactivated — the server enforces this,
   *  and disabling here reports the rule instead of discovering it via a 4xx. */
  public isDisabled(value: SettableStatus): boolean {
    if (this.busy()) return true;
    return this.isOwner() && value !== 'active';
  }

  public select(value: SettableStatus): void {
    if (this.isDisabled(value) || this.isSelected(value)) return;
    this.statusChange.emit(value);
  }
}
