import type { PushPayload, PushSender, PushSendResult } from "./push.types.mts";

interface FcmOptions {
  projectId: string;
  accessToken: () => Promise<string>;
  fetchImpl?: typeof fetch;
}

export class FcmPushSender implements PushSender {

  private readonly projectId: string;
  private readonly accessToken: () => Promise<string>;
  private readonly fetchImpl: typeof fetch;

  public constructor(opts: FcmOptions) {
    this.projectId = opts.projectId;
    this.accessToken = opts.accessToken;
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  public async send(tokens: string[], payload: PushPayload): Promise<PushSendResult> {
    if (tokens.length === 0) return { unregistered: [] };
    const token = await this.accessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`;
    const unregistered: string[] = [];
    await Promise.all(tokens.map(async (t) => {
      const res = await this.fetchImpl(url, {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title: payload.title, body: payload.body },
            data: payload.data,
          },
        }),
      });
      if (!res.ok) {
        const parsed = (await res.json().catch(() => ({}))) as { error?: { status?: string } };
        const status = parsed.error?.status;
        if (status === "UNREGISTERED" || status === "NOT_FOUND" || res.status === 404) unregistered.push(t);
      }
    }));
    return { unregistered };
  }
}
