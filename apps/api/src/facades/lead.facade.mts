import type { GymLeadRequest, LeadResponse, WaitlistLead, WaitlistLeadRequest, GymLead } from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { WaitlistLeadRepository } from "../repositories/waitlist-lead.repository.mts";
import type { GymLeadRepository } from "../repositories/gym-lead.repository.mts";
import type { EmailService } from "../services/email.service.mts";

type IdFactory = () => string;

export class LeadFacade {

  public constructor(
    private readonly waitlist: Pick<WaitlistLeadRepository, "upsertByEmail">,
    private readonly gymLeads: Pick<GymLeadRepository, "insert">,
    private readonly email: EmailService,
    private readonly newId: IdFactory,
  ) {}

  public async joinWaitlist(req: WaitlistLeadRequest): Promise<LeadResponse> {
    const email = req.email.trim().toLowerCase();
    const lead: WaitlistLead = {
      id: this.newId(),
      email,
      status: "confirmed",
      source: req.source,
      utm: req.utm,
      createdAt: new Date().toISOString(),
      confirmationSentAt: new Date().toISOString(),
    };
    const isNew = await this.waitlist.upsertByEmail(lead);
    // Only email on first signup; re-submits succeed silently without a duplicate email.
    if (isNew) {
      try {
        await this.email.sendWaitlistConfirmation(email);
      } catch (err: unknown) {
        logger.warn(`Waitlist confirmation email failed for ${email}`, { err });
      }
    }
    return { status: "confirmed" };
  }

  public async submitGymLead(req: GymLeadRequest): Promise<LeadResponse> {
    const ownerEmail = req.ownerEmail.trim().toLowerCase();
    const lead: GymLead = {
      id: this.newId(),
      gymName: req.gymName.trim(),
      ownerName: req.ownerName,
      ownerEmail,
      city: req.city,
      state: req.state,
      message: req.message,
      status: "new",
      utm: req.utm,
      createdAt: new Date().toISOString(),
    };
    await this.gymLeads.insert(lead);
    try {
      await this.email.sendGymLeadConfirmation(ownerEmail, lead.gymName);
      await this.email.sendGymLeadAdminAlert({
        gymName: lead.gymName,
        ownerName: lead.ownerName,
        ownerEmail,
        city: lead.city,
        state: lead.state,
        message: lead.message,
      });
    } catch (err: unknown) {
      logger.warn(`Gym lead email failed for ${lead.gymName}`, { err });
    }
    return { status: "new" };
  }
}
