import type { AuthSyncRequest, UpdateSettingsRequest, UpdateUserRequest, User, UserSettings } from "@bjj/contract";
import type { AuthIdentity } from "../auth/auth.types.mts";
import { isSocial } from "../auth/is-social.mts";
import { AppError } from "../http/errors.mts";
import type { UserRepository } from "../repositories/user.repository.mts";

const DEFAULT_SETTINGS: UserSettings = { theme: "glass", notifyRsvp: true, notifySessionUpdates: true };

export class UserFacade {

  public constructor(private readonly users: Pick<UserRepository, "findById" | "upsertByAuth0Id" | "update" | "insert">) {}

  public async getOrCreate(identity: AuthIdentity): Promise<User> {
    const existing = await this.users.findById(identity.userId);
    if (existing) return existing;
    // Auth0 access tokens for social logins don't carry the `email` claim, so
    // identity.email is often "". A blank email violated the unique `email`
    // index (E11000) the moment a second email-less user was created -> 500.
    // Synthesize a valid, per-user-unique placeholder; `/auth/sync` then patches
    // in the real email from the ID token on the client's next call.
    const email = this.resolveEmail(identity);
    return this.users.insert({
      id: identity.userId,
      email,
      displayName: email.split("@")[0] ?? identity.userId,
      settings: DEFAULT_SETTINGS,
      createdAt: new Date().toISOString(),
    });
  }

  // A real email from the token when present; otherwise a unique, RFC-valid
  // placeholder derived from the (globally unique) Auth0 subject id.
  private resolveEmail(identity: AuthIdentity): string {
    if (identity.email && identity.email.includes("@")) return identity.email;
    const localPart = identity.userId.replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "user";
    return `${localPart}@users.bjj-open-mat.app`;
  }

  public async syncFromProvider(identity: AuthIdentity, claims: AuthSyncRequest): Promise<User> {
    const user = await this.getOrCreate(identity);
    if (!isSocial(identity.userId)) return user; // db/bypass users manage their own identity
    const patch: Partial<User> = {};
    if (claims.displayName) patch.displayName = claims.displayName;
    if (claims.email) patch.email = claims.email;
    if (claims.avatarUrl) patch.avatarUrl = claims.avatarUrl;
    if (Object.keys(patch).length === 0) return user;
    const updated = await this.users.update(identity.userId, patch);
    return updated ?? user;
  }

  public async getById(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new AppError("not_found", `User ${id} not found`);
    return user;
  }

  public async updateProfile(id: string, patch: UpdateUserRequest, isSocialUser = false): Promise<User> {
    const effective: UpdateUserRequest = isSocialUser ? this.socialAllowed(patch) : patch;
    const updated = await this.users.update(id, effective);
    if (!updated) throw new AppError("not_found", `User ${id} not found`);
    return updated;
  }

  // Social/SSO users own all their profile app-data (belt, birthday, weight,
  // gender, city/state, bio, division, home gym, role). Only displayName and
  // avatarUrl come from the provider and are re-synced on each login via
  // syncFromProvider, so edits to those are ignored here to avoid being
  // silently overwritten. Everything else passes through.
  private socialAllowed(patch: UpdateUserRequest): UpdateUserRequest {
    const allowed: UpdateUserRequest = { ...patch };
    delete allowed.displayName;
    delete allowed.avatarUrl;
    return allowed;
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
