import { type Static, Type as t } from "@sinclair/typebox";

export const DevicePlatform = t.Union([t.Literal("ios"), t.Literal("android")], { $id: "DevicePlatform" });
export type DevicePlatform = Static<typeof DevicePlatform>;

export const DeviceToken = t.Object(
  {
    id: t.String(),
    userId: t.String(),
    token: t.String(),
    platform: DevicePlatform,
    createdAt: t.String(),
    lastSeenAt: t.Optional(t.String()),
  },
  { $id: "DeviceToken" },
);
export type DeviceToken = Static<typeof DeviceToken>;
