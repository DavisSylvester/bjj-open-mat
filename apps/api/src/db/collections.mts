export const COLLECTIONS = {
  users: "users",
  gyms: "gyms",
  openMats: "openMats",
  rsvps: "rsvps",
  checkins: "checkins",
  favorites: "favorites",
  notifications: "notifications",
} as const;

export type CollectionName = (typeof COLLECTIONS)[keyof typeof COLLECTIONS];
