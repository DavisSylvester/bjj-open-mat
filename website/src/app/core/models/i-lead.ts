export interface Utm { source?: string; medium?: string; campaign?: string; }

export interface WaitlistRequest { email: string; source?: string; utm?: Utm; hp?: string; }

export interface GymLeadRequest {
  gymName: string; ownerName?: string; ownerEmail: string;
  city?: string; state?: string; message?: string; utm?: Utm; hp?: string;
}

export interface LeadResponse { status: 'confirmed' | 'new'; }
