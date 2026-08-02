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

export interface CreateGymBody {
  name: string;
  address: string;
  city?: string;
  state?: string;
  description?: string;
  phone?: string;
  website?: string;
}
