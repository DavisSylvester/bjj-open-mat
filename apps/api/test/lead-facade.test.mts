import { describe, expect, it, mock } from "bun:test";
import { LeadFacade } from "../src/facades/lead.facade.mts";
import type { EmailService } from "../src/services/email.service.mts";

function fakeEmail(): EmailService & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    async sendWaitlistConfirmation(): Promise<void> { calls.push("waitlist"); },
    async sendGymLeadConfirmation(): Promise<void> { calls.push("gymConfirm"); },
    async sendGymLeadAdminAlert(): Promise<void> { calls.push("gymAdmin"); },
  };
}

describe("LeadFacade.joinWaitlist", () => {
  it("persists then emails, returning confirmed", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "USER@X.com" });

    expect(res.status).toBe("confirmed");
    const arg = (waitlist.upsertByEmail.mock.calls[0] as unknown[])[0] as { email: string };
    expect(arg.email).toBe("user@x.com");
    expect(email.calls).toEqual(["waitlist"]);
  });

  it("stays successful even if the email send throws", async () => {
    const email = fakeEmail();
    email.sendWaitlistConfirmation = async (): Promise<void> => { throw new Error("SES down"); };
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "user@x.com" });
    expect(res.status).toBe("confirmed");
  });

  it("does not send a second confirmation for a duplicate signup", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => false) };
    const gym = { ensureIndexes: mock(), insert: mock() };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.joinWaitlist({ email: "dup@x.com" });
    expect(res.status).toBe("confirmed");
    expect(email.calls).toEqual([]);
  });
});

describe("LeadFacade.submitGymLead", () => {
  it("inserts, confirms the owner, and alerts the admin", async () => {
    const email = fakeEmail();
    const waitlist = { ensureIndexes: mock(), upsertByEmail: mock(async () => true) };
    const gym = { ensureIndexes: mock(), insert: mock(async () => undefined) };
    const facade = new LeadFacade(waitlist as never, gym as never, email, () => "id-1");

    const res = await facade.submitGymLead({ gymName: "GB", ownerEmail: "coach@gym.com" });
    expect(res.status).toBe("new");
    expect(gym.insert).toHaveBeenCalledTimes(1);
    expect(email.calls).toEqual(["gymConfirm", "gymAdmin"]);
  });
});
