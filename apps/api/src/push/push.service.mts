import type { DeviceToken } from "@bjj/contract";
import { logger } from "../config/logger.mts";
import type { PushNotifier, PushPayload, PushSender } from "./push.types.mts";

interface TokenReader {
  listByUser(userId: string): Promise<DeviceToken[]>;
  pruneTokens(tokens: string[]): Promise<void>;
}

export class PushService implements PushNotifier {

  public constructor(
    private readonly tokens: TokenReader,
    private readonly sender: PushSender,
  ) {}

  public async pushToUsers(userIds: string[], payload: PushPayload): Promise<void> {
    let unregistered: string[] = [];
    try {
      const rows = await Promise.all([...new Set(userIds)].map((u) => this.tokens.listByUser(u)));
      const tokens = [...new Set(rows.flat().map((r) => r.token))];
      if (tokens.length === 0) return;
      ({ unregistered } = await this.sender.send(tokens, payload));
    } catch (err) {
      logger.warn("push send failed (swallowed)", { err });
      return;
    }
    if (unregistered.length > 0) {
      try {
        await this.tokens.pruneTokens(unregistered);
      } catch (err) {
        logger.warn("push token pruning failed (swallowed)", { err });
      }
    }
  }
}
