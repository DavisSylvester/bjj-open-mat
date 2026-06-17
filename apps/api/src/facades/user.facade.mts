import type { UpdateSettingsRequest, UpdateUserRequest, User, UserSettings } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { AppError } from "../http/errors.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

const DEFAULT_SETTINGS: UserSettings = { theme: "glass", notifyRsvp: true, notifySessionUpdates: true };

export class UserFacade {

  public constructor(private readonly users: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert">) {}

  public async getOrCreate(identity: AuthIdentity): Promise<User> {
    const existing = await this.users.findById(identity.userId);
    if (existing) return existing;
    return this.users.insert({
      id: identity.userId,
      email: identity.email,
      displayName: identity.email.split("@")[0] ?? identity.userId,
      role: identity.role,
      settings: DEFAULT_SETTINGS,
      createdAt: new Date().toISOString(),
    });
  }

  public async getById(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new AppError("not_found", `User ${id} not found`);
    return user;
  }

  public async updateProfile(id: string, patch: UpdateUserRequest): Promise<User> {
    const updated = await this.users.update(id, patch);
    if (!updated) throw new AppError("not_found", `User ${id} not found`);
    return updated;
  }

  public async getSettings(id: string): Promise<UserSettings> {
    const user = await this.getById(id);
    return user.settings ?? DEFAULT_SETTINGS;
  }

  public async updateSettings(id: string, patch: UpdateSettingsRequest): Promise<UserSettings> {
    const current = await this.getSettings(id);
    const next: UserSettings = { ...current, ...patch };
    await this.users.update(id, { settings: next });
    return next;
  }
}
