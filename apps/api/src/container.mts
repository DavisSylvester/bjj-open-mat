import { randomUUID } from "node:crypto";
import type { Db } from "mongodb";
import type { UserRole } from "@bjj/contract";
import type { AppEnv } from "./config/env.mts";
import { JwtVerifier } from "./auth/jwt-verifier.mts";
import { CheckInFacade } from "./facades/check-in.facade.mts";
import { GymFacade } from "./facades/gym.facade.mts";
import { NotificationFacade } from "./facades/notification.facade.mts";
import { OpenMatFacade } from "./facades/open-mat.facade.mts";
import { UserFacade } from "./facades/user.facade.mts";
import { ZipcodesGeocoder } from "./services/geocoder.mts";
import { CheckInRepository } from "./repositories/check-in.repository.mts";
import { FavoriteRepository } from "./repositories/favorite.repository.mts";
import { GymRepository } from "./repositories/gym.repository.mts";
import { NotificationRepository } from "./repositories/notification.repository.mts";
import { OpenMatRepository } from "./repositories/open-mat.repository.mts";
import { RsvpRepository } from "./repositories/rsvp.repository.mts";
import { UserRepository } from "./repositories/user.repository.mts";

export interface Container {
  readonly db: Db;
  readonly verifier: JwtVerifier;
  readonly roleLookup: (userId: string) => Promise<UserRole | null>;
  readonly userFacade: UserFacade;
  readonly gymFacade: GymFacade;
  readonly openMatFacade: OpenMatFacade;
  readonly checkInFacade: CheckInFacade;
  readonly notificationFacade: NotificationFacade;
  ensureIndexes(): Promise<void>;
}

export function createContainer(db: Db, env: AppEnv): Container {
  const userRepo = new UserRepository(db);
  const gymRepo = new GymRepository(db);
  const openMatRepo = new OpenMatRepository(db);
  const rsvpRepo = new RsvpRepository(db);
  const checkInRepo = new CheckInRepository(db);
  const favoriteRepo = new FavoriteRepository(db);
  const notificationRepo = new NotificationRepository(db);
  const id = (): string => randomUUID();
  const geocoder = new ZipcodesGeocoder();

  return {
    db,
    verifier: new JwtVerifier({
      bypassSecret: env.bypassSecret,
      demoUser: env.demoUser,
      auth0Domain: env.auth0Domain,
      auth0Audience: env.auth0Audience,
    }),
    roleLookup: async (userId: string): Promise<UserRole | null> => {
      const user = await userRepo.findById(userId);
      return user?.role ?? null;
    },
    userFacade: new UserFacade(userRepo),
    gymFacade: new GymFacade(gymRepo, favoriteRepo, id, geocoder),
    openMatFacade: new OpenMatFacade(openMatRepo, gymRepo, rsvpRepo, id, geocoder),
    checkInFacade: new CheckInFacade(checkInRepo, openMatRepo, userRepo, id),
    notificationFacade: new NotificationFacade(notificationRepo, id),
    async ensureIndexes(): Promise<void> {
      await Promise.all([
        userRepo.ensureIndexes(),
        gymRepo.ensureIndexes(),
        openMatRepo.ensureIndexes(),
        rsvpRepo.ensureIndexes(),
        checkInRepo.ensureIndexes(),
        favoriteRepo.ensureIndexes(),
        notificationRepo.ensureIndexes(),
      ]);
    },
  };
}
