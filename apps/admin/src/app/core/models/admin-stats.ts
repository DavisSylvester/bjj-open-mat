export interface SignupWindows {
  today: number;
  last3Days: number;
  last7Days: number;
  last14Days: number;
  monthToDate: number;
  yearToDate: number;
}

export interface AdminOverviewStats {
  signups: SignupWindows;
  totalUsers: number;
  totalGyms: number;
  totalOpenMats: number;
}

export interface StateOpenMatCount {
  state: string;
  count: number;
}

export interface AdminOpenMatsByState {
  totalOpenMats: number;
  topStates: StateOpenMatCount[];
}
