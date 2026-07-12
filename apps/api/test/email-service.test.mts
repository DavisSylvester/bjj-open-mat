import { describe, expect, it } from "bun:test";
import { SesEmailService, UnconfiguredEmailService } from "../src/services/email.service.mts";

// A fake SESv2 client capturing the last command input.
function fakeClient(): { sent: unknown[]; send(cmd: unknown): Promise<unknown> } {
  const sent: unknown[] = [];
  return {
    sent,
    async send(cmd: { input: unknown }): Promise<unknown> {
      sent.push(cmd.input);
      return { MessageId: "m1" };
    },
  };
}

describe("SesEmailService", () => {
  it("sends a waitlist confirmation from the configured sender", async () => {
    const client = fakeClient();
    const svc = new SesEmailService(
      { from: "no-reply@dsylvester.ai", adminEmail: "admin@x.com" },
      client as never,
    );
    await svc.sendWaitlistConfirmation("user@x.com");
    const input = client.sent[0] as { FromEmailAddress: string; Destination: { ToAddresses: string[] } };
    expect(input.FromEmailAddress).toBe("no-reply@dsylvester.ai");
    expect(input.Destination.ToAddresses).toEqual(["user@x.com"]);
  });

  it("sends a gym-lead admin alert to the admin address", async () => {
    const client = fakeClient();
    const svc = new SesEmailService(
      { from: "no-reply@dsylvester.ai", adminEmail: "admin@x.com" },
      client as never,
    );
    await svc.sendGymLeadAdminAlert({ gymName: "GB", ownerEmail: "coach@gym.com" });
    const input = client.sent[0] as { Destination: { ToAddresses: string[] } };
    expect(input.Destination.ToAddresses).toEqual(["admin@x.com"]);
  });
});

describe("UnconfiguredEmailService", () => {
  it("no-ops without throwing", async () => {
    const svc = new UnconfiguredEmailService();
    await svc.sendWaitlistConfirmation("user@x.com");
    expect(true).toBe(true);
  });
});
