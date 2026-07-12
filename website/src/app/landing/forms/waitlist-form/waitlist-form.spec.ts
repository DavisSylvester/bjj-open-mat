import { TestBed } from '@angular/core/testing';
import { LeadApiService } from '../../../core/lead-api.service';
import { WaitlistForm } from './waitlist-form';

describe('WaitlistForm', () => {
  let joinWaitlist: ReturnType<typeof vi.fn>;

  function setup(): WaitlistForm {
    TestBed.configureTestingModule({
      providers: [{ provide: LeadApiService, useValue: { joinWaitlist, submitGymLead: vi.fn() } }],
    });
    return TestBed.createComponent(WaitlistForm).componentInstance;
  }

  beforeEach(() => {
    joinWaitlist = vi.fn().mockResolvedValue({ status: 'confirmed' });
  });

  it('submits the email and reaches the success state', async () => {
    const cmp = setup();
    cmp.email.set('rolls@gracie.com');

    await cmp.submit();

    expect(joinWaitlist).toHaveBeenCalledTimes(1);
    expect(joinWaitlist).toHaveBeenCalledWith(
      expect.objectContaining({ email: 'rolls@gracie.com', hp: '' }),
    );
    expect(cmp.state()).toBe('success');
  });

  it('moves to the error state when the API rejects', async () => {
    joinWaitlist = vi.fn().mockRejectedValue(new Error('400'));
    const cmp = setup();
    cmp.email.set('rolls@gracie.com');

    await cmp.submit();

    expect(cmp.state()).toBe('error');
  });
});
