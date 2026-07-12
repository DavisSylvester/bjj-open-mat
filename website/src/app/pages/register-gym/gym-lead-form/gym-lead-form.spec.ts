import { TestBed } from '@angular/core/testing';
import { LeadApiService } from '../../../core/lead-api.service';
import { GymLeadForm } from './gym-lead-form';

describe('GymLeadForm', () => {
  let submitGymLead: ReturnType<typeof vi.fn>;

  function setup(): GymLeadForm {
    TestBed.configureTestingModule({
      providers: [{ provide: LeadApiService, useValue: { submitGymLead, joinWaitlist: vi.fn() } }],
    });
    return TestBed.createComponent(GymLeadForm).componentInstance;
  }

  beforeEach(() => {
    submitGymLead = vi.fn().mockResolvedValue({ status: 'new' });
  });

  it('submits gym name + email and reaches the success state', async () => {
    const cmp = setup();
    cmp.gymName.set('Gracie Barra');
    cmp.ownerEmail.set('owner@gb.com');

    await cmp.submit();

    expect(submitGymLead).toHaveBeenCalledTimes(1);
    expect(submitGymLead).toHaveBeenCalledWith(
      expect.objectContaining({ gymName: 'Gracie Barra', ownerEmail: 'owner@gb.com' }),
    );
    expect(cmp.formState()).toBe('success');
  });

  it('does not call the API when gym name is empty (client validation)', async () => {
    const cmp = setup();
    cmp.ownerEmail.set('owner@gb.com');

    await cmp.submit();

    expect(submitGymLead).not.toHaveBeenCalled();
    expect(cmp.invalid()).toBe(true);
    expect(cmp.formState()).toBe('idle');
  });
});
