import { type Static, Type as t } from "@sinclair/typebox";

export const SignupWindows = t.Object(
  {
    today: t.Integer({ minimum: 0 }),
    last3Days: t.Integer({ minimum: 0 }),
    last7Days: t.Integer({ minimum: 0 }),
    last14Days: t.Integer({ minimum: 0 }),
    monthToDate: t.Integer({ minimum: 0 }),
    yearToDate: t.Integer({ minimum: 0 }),
  },
  { $id: "SignupWindows" },
);
export type SignupWindows = Static<typeof SignupWindows>;

export const AdminOverviewStats = t.Object(
  {
    signups: SignupWindows,
    totalUsers: t.Integer({ minimum: 0 }),
    totalGyms: t.Integer({ minimum: 0 }),
    totalOpenMats: t.Integer({ minimum: 0 }),
  },
  { $id: "AdminOverviewStats" },
);
export type AdminOverviewStats = Static<typeof AdminOverviewStats>;

export const StateOpenMatCount = t.Object(
  { state: t.String(), count: t.Integer({ minimum: 0 }) },
  { $id: "StateOpenMatCount" },
);
export type StateOpenMatCount = Static<typeof StateOpenMatCount>;

export const AdminOpenMatsByState = t.Object(
  {
    totalOpenMats: t.Integer({ minimum: 0 }),
    topStates: t.Array(StateOpenMatCount),
  },
  { $id: "AdminOpenMatsByState" },
);
export type AdminOpenMatsByState = Static<typeof AdminOpenMatsByState>;
