import { describe, expect, it } from "bun:test";
import * as XLSX from "xlsx";
import { rowsToCandidates } from "../lib/xlsx-parse.mjs";

function sheetFromRows(rows: Record<string, string>[]): XLSX.WorkSheet {
  return XLSX.utils.json_to_sheet(rows);
}

describe("rowsToCandidates", () => {
  it("maps typical schedule columns to candidates", () => {
    const ws = sheetFromRows([
      { Gym: "Atos Jiu Jitsu", City: "Frisco", State: "TX", Day: "Sunday", Time: "10am-12pm", Type: "No-Gi" },
    ]);
    const out = rowsToCandidates(ws, "https://facebook.com/groups/x/files/y.xlsx");
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({
      gymName: "Atos Jiu Jitsu", city: "Frisco", state: "TX",
      dayOfWeek: 0, startTime: "10:00", endTime: "12:00", giType: "nogi", isRecurring: true,
    });
  });
  it("skips rows without a gym or without a parseable time", () => {
    const ws = sheetFromRows([
      { Gym: "", City: "X", Day: "Sunday", Time: "10am" },
      { Gym: "Test BJJ", City: "X", Day: "Sunday", Time: "" },
    ]);
    expect(rowsToCandidates(ws, "u")).toHaveLength(0);
  });
});
