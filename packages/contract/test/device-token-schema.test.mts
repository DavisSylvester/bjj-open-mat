import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { DeviceToken, RegisterDeviceRequest } from "../src/index.mts";

describe("device token schemas", () => {
  it("DeviceToken parses a valid ios token", () => {
    const d = Value.Parse(DeviceToken, {
      id: "d1", userId: "u1", token: "abc", platform: "ios", createdAt: "t",
    });
    expect(d.platform).toBe("ios");
  });

  it("RegisterDeviceRequest rejects an unknown platform", () => {
    expect(Value.Check(RegisterDeviceRequest, { token: "abc", platform: "web" })).toBe(false);
    expect(Value.Check(RegisterDeviceRequest, { token: "abc", platform: "android" })).toBe(true);
  });
});
