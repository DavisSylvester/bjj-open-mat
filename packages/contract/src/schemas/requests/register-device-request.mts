import { type Static, Type as t } from "@sinclair/typebox";
import { DevicePlatform } from "../device-token.mjs";

export const RegisterDeviceRequest = t.Object(
  { token: t.String({ minLength: 1 }), platform: DevicePlatform },
  { $id: "RegisterDeviceRequest" },
);
export type RegisterDeviceRequest = Static<typeof RegisterDeviceRequest>;
