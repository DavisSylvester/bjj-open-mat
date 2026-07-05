import type { Gender } from "../enums/gender.mjs";
import type { WeightDivision } from "../enums/weight-division.mjs";

export type GiContext = "gi" | "nogi";

export interface WeightClassRow {
  division: WeightDivision;
  label: string;
  maxKg: number | null; // null => no upper limit (open class)
  maxLb: number | null;
}

export const IBJJF_WEIGHT_CLASSES: Record<Gender, Record<GiContext, readonly WeightClassRow[]>> = {
  male: {
    gi: [
      { division: "rooster", label: "Rooster", maxKg: 57.5, maxLb: 126.8 },
      { division: "light_feather", label: "Light Feather", maxKg: 64, maxLb: 141.1 },
      { division: "feather", label: "Feather", maxKg: 70, maxLb: 154.3 },
      { division: "light", label: "Light", maxKg: 76, maxLb: 167.6 },
      { division: "middle", label: "Middle", maxKg: 82.3, maxLb: 181.4 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 88.3, maxLb: 194.7 },
      { division: "heavy", label: "Heavy", maxKg: 94.3, maxLb: 207.9 },
      { division: "super_heavy", label: "Super Heavy", maxKg: 100.5, maxLb: 221.6 },
      { division: "ultra_heavy", label: "Ultra Heavy", maxKg: null, maxLb: null },
    ],
    nogi: [
      { division: "rooster", label: "Rooster", maxKg: 55.5, maxLb: 122.4 },
      { division: "light_feather", label: "Light Feather", maxKg: 61.5, maxLb: 135.6 },
      { division: "feather", label: "Feather", maxKg: 67.5, maxLb: 148.8 },
      { division: "light", label: "Light", maxKg: 73.5, maxLb: 162.0 },
      { division: "middle", label: "Middle", maxKg: 79.5, maxLb: 175.3 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 85.5, maxLb: 188.5 },
      { division: "heavy", label: "Heavy", maxKg: 91.5, maxLb: 201.7 },
      { division: "super_heavy", label: "Super Heavy", maxKg: 97.5, maxLb: 215.0 },
      { division: "ultra_heavy", label: "Ultra Heavy", maxKg: null, maxLb: null },
    ],
  },
  female: {
    gi: [
      { division: "rooster", label: "Rooster", maxKg: 48.5, maxLb: 106.9 },
      { division: "light_feather", label: "Light Feather", maxKg: 53.5, maxLb: 117.9 },
      { division: "feather", label: "Feather", maxKg: 58.5, maxLb: 129.0 },
      { division: "light", label: "Light", maxKg: 64, maxLb: 141.1 },
      { division: "middle", label: "Middle", maxKg: 69, maxLb: 152.1 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 74, maxLb: 163.1 },
      { division: "super_heavy", label: "Super Heavy", maxKg: null, maxLb: null },
    ],
    nogi: [
      { division: "rooster", label: "Rooster", maxKg: 46.5, maxLb: 102.5 },
      { division: "light_feather", label: "Light Feather", maxKg: 51.5, maxLb: 113.5 },
      { division: "feather", label: "Feather", maxKg: 56.5, maxLb: 124.6 },
      { division: "light", label: "Light", maxKg: 61.5, maxLb: 135.6 },
      { division: "middle", label: "Middle", maxKg: 66.5, maxLb: 146.6 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 71.5, maxLb: 157.6 },
      { division: "super_heavy", label: "Super Heavy", maxKg: null, maxLb: null },
    ],
  },
};

export function divisionsFor(gender: Gender, context: GiContext): readonly WeightClassRow[] {
  return IBJJF_WEIGHT_CLASSES[gender][context];
}
