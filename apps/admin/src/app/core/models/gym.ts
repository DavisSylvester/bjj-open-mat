export interface Gym {
  id: string;
  ownerId?: string;
  name: string;
  address: string;
  city?: string;
  state?: string;
  isVerified: boolean;
  verifiedAt?: string;
  joinCode?: string;
  createdAt?: string;
}
