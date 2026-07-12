import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";
import { logger } from "../config/logger.mts";

export interface GymLeadSummary {
  gymName: string;
  ownerName?: string;
  ownerEmail: string;
  city?: string;
  state?: string;
  message?: string;
}

export interface EmailService {
  sendWaitlistConfirmation(to: string): Promise<void>;
  sendGymLeadConfirmation(to: string, gymName: string): Promise<void>;
  sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void>;
}

export interface EmailConfig {
  from: string;
  adminEmail: string;
}

// Minimal structural type so tests can inject a fake without the real client.
interface SesLike {
  send(cmd: SendEmailCommand): Promise<unknown>;
}

// Sends transactional emails via Amazon SES v2. Bodies are intentionally plain
// and short; richer templates can be swapped in later without touching callers.
export class SesEmailService implements EmailService {

  private readonly client: SesLike;

  public constructor(
    private readonly config: EmailConfig,
    client?: SesLike,
    region: string = "us-east-1",
  ) {
    this.client = client ?? new SESv2Client({ region });
  }

  private async send(to: string, subject: string, text: string): Promise<void> {
    const cmd = new SendEmailCommand({
      FromEmailAddress: this.config.from,
      Destination: { ToAddresses: [to] },
      Content: { Simple: { Subject: { Data: subject }, Body: { Text: { Data: text } } } },
    });
    await this.client.send(cmd);
  }

  public async sendWaitlistConfirmation(to: string): Promise<void> {
    await this.send(
      to,
      "You're on the BJJ Open Mat founding list 🥋",
      "Thanks for joining! You'll be first in line at launch, with a Founding Member badge.\n\n— BJJ Open Mat",
    );
  }

  public async sendGymLeadConfirmation(to: string, gymName: string): Promise<void> {
    await this.send(
      to,
      `We got your gym: ${gymName}`,
      `Thanks for claiming ${gymName} on BJJ Open Mat. We'll reach out with next steps.\n\n— BJJ Open Mat`,
    );
  }

  public async sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void> {
    const lines = [
      `New gym lead: ${lead.gymName}`,
      `Owner: ${lead.ownerName ?? "(not given)"} <${lead.ownerEmail}>`,
      `Location: ${[lead.city, lead.state].filter(Boolean).join(", ") || "(not given)"}`,
      `Message: ${lead.message ?? "(none)"}`,
    ];
    await this.send(this.config.adminEmail, `[BJJ Open Mat] Gym lead: ${lead.gymName}`, lines.join("\n"));
  }
}

// Used in local dev / tests when SES is not configured. Logs and no-ops.
export class UnconfiguredEmailService implements EmailService {

  public async sendWaitlistConfirmation(to: string): Promise<void> {
    logger.info(`[email:noop] waitlist confirmation -> ${to}`);
  }

  public async sendGymLeadConfirmation(to: string, gymName: string): Promise<void> {
    logger.info(`[email:noop] gym confirmation -> ${to} (${gymName})`);
  }

  public async sendGymLeadAdminAlert(lead: GymLeadSummary): Promise<void> {
    logger.info(`[email:noop] gym admin alert for ${lead.gymName}`);
  }
}
