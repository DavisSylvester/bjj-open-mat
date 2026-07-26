import { describe, expect, it } from "bun:test";
import { parseTime, parseDayOfWeek, parseGiType, parseFeeCents, parseSchedule } from "../lib/parse.mjs";

describe("parseTime", () => {
  it("parses 12h times to 24h HH:mm", () => {
    expect(parseTime("10am")).toBe("10:00");
    expect(parseTime("10:30 AM")).toBe("10:30");
    expect(parseTime("12pm")).toBe("12:00");
    expect(parseTime("12am")).toBe("00:00");
    expect(parseTime("6:45pm")).toBe("18:45");
  });
  it("returns null on garbage", () => {
    expect(parseTime("noon-ish")).toBeNull();
  });
});

describe("parseDayOfWeek", () => {
  it("maps weekday names to 0..6", () => {
    expect(parseDayOfWeek("every Sunday")).toBe(0);
    expect(parseDayOfWeek("Saturdays")).toBe(6);
    expect(parseDayOfWeek("Weds")).toBe(3);
  });
  it("returns null when no weekday present", () => {
    expect(parseDayOfWeek("this weekend")).toBeNull();
  });
});

describe("parseGiType", () => {
  it("detects gi/nogi/both", () => {
    expect(parseGiType("No-Gi open mat")).toBe("nogi");
    expect(parseGiType("Gi only")).toBe("gi");
    expect(parseGiType("gi and no-gi")).toBe("both");
    expect(parseGiType("open mat")).toBe("both"); // default
  });
});

describe("parseFeeCents", () => {
  it("detects free and dollar amounts", () => {
    expect(parseFeeCents("Free open mat")).toBe(0);
    expect(parseFeeCents("$10 drop-in")).toBe(1000);
    expect(parseFeeCents("open mat")).toBe(0); // default free
  });
});

describe("parseSchedule", () => {
  it("parses a recurring weekly time range", () => {
    const s = parseSchedule("Open mat every Sunday 10am-12pm");
    expect(s).toEqual({ isRecurring: true, dayOfWeek: 0, startTime: "10:00", endTime: "12:00", specificDate: undefined });
  });
  it("defaults end time to +90m when only a start is given", () => {
    const s = parseSchedule("Sunday open mat at 10am");
    expect(s?.startTime).toBe("10:00");
    expect(s?.endTime).toBe("11:30");
  });
  it("returns null when no time can be found", () => {
    expect(parseSchedule("Open mat this weekend, details TBA")).toBeNull();
  });
});
