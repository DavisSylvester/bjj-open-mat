import { describe, expect, it } from "bun:test";
import { UnconfiguredEmailService } from "../src/services/email.service.mts";

describe("sendGymMemberInvite", () => {
  it("UnconfiguredEmailService no-ops without throwing", async () => {
    const svc = new UnconfiguredEmailService();
    await expect(svc.sendGymMemberInvite("a@b.dev", "Gracie HQ", "JOIN123")).resolves.toBeUndefined();
  });
});
