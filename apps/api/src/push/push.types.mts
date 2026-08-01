export interface PushPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface PushSendResult {
  unregistered: string[];
}

export interface PushSender {
  send(tokens: string[], payload: PushPayload): Promise<PushSendResult>;
}

export interface PushNotifier {
  pushToUsers(userIds: string[], payload: PushPayload): Promise<void>;
}
