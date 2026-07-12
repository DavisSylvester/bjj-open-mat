import { describe, expect, it, mock } from "bun:test";
import { Elysia } from "elysia";
import { leadRoutes } from "../src/routes/lead.routes.mts";

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
function appWith(joinWaitlist: unknown, submitGymLead: unknown) {
  const container = { leadFacade: { joinWaitlist, submitGymLead } };
  return new Elysia().use(leadRoutes(container as never));
}

describe("POST /api/v1/waitlist", () => {
  it("accepts a valid email and returns confirmed", async () => {
    const join = mock(async () => ({ status: "confirmed" }));
    const app = appWith(join, mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "a@b.com" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ data: { status: "confirmed" } });
    expect(join).toHaveBeenCalledTimes(1);
  });

  it("silently drops honeypot submissions without calling the facade", async () => {
    const join = mock(async () => ({ status: "confirmed" }));
    const app = appWith(join, mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "a@b.com", hp: "i-am-a-bot" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(join).toHaveBeenCalledTimes(0);
  });

  it("rejects an invalid email with 422", async () => {
    const app = appWith(mock(), mock());
    const res = await app.handle(
      new Request("http://localhost/api/v1/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: "nope" }),
      }),
    );
    expect(res.status).toBe(422);
  });
});

describe("POST /api/v1/gym-leads", () => {
  it("accepts a valid gym lead", async () => {
    const submit = mock(async () => ({ status: "new" }));
    const app = appWith(mock(), submit);
    const res = await app.handle(
      new Request("http://localhost/api/v1/gym-leads", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ gymName: "GB", ownerEmail: "c@g.com" }),
      }),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ data: { status: "new" } });
  });
});
