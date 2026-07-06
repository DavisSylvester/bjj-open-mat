import { type Static, Type as t } from "@sinclair/typebox";

export const AuthSyncRequest = t.Object(
  {
    displayName: t.Optional(t.String()),
    email: t.Optional(t.String()),
    avatarUrl: t.Optional(t.String()),
  },
  { $id: "AuthSyncRequest" },
);
export type AuthSyncRequest = Static<typeof AuthSyncRequest>;
