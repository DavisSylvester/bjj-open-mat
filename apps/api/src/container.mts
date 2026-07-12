import { randomUUID } from "node:crypto";
import type { Db } from "mongodb";
import type { UserRole } from "@bjj/contract";
import type { AppEnv } from "./config/env.mts";
import { JwtVerifier } from "./auth/jwt-verifier.mts";
import { CheckInFacade } from "./facades/check-in.facade.mts";
import { GymFacade } from "./facades/gym.facade.mts";
import { NotificationFacade } from "./facades/notification.facade.mts";
import { OpenMatFacade } from "./facades/open-mat.facade.mts";
import { ReportFacade } from "./facades/report.facade.mts";
import { UserFacade } from "./facades/user.facade.mts";
import { ZipcodesGeocoder, type Geocoder } from "./services/geocoder.mts";
import {
  S3AssetStorage,
  UnconfiguredAssetStorage,
  type AssetStorage,
} from "./services/asset-storage.mts";
import {
  S3AudioStorage,
  UnconfiguredAudioStorage,
  type AudioStorage,
} from "./services/audio-storage.mts";
import { WhisperTranscriptionService, type TranscriptionService } from "./services/transcription.mts";
import {
  HttpGitHubIssueService,
  type GitHubIssueService,
} from "./services/github-issue.service.mts";
import { CheckInRepository } from "./repositories/check-in.repository.mts";
import { FavoriteRepository } from "./repositories/favorite.repository.mts";
import { GymRepository } from "./repositories/gym.repository.mts";
import { NotificationRepository } from "./repositories/notification.repository.mts";
import { OpenMatRepository } from "./repositories/open-mat.repository.mts";
import { ReportRepository } from "./repositories/report.repository.mts";
import { RsvpRepository } from "./repositories/rsvp.repository.mts";
import { UserRepository } from "./repositories/user.repository.mts";
import { LeadFacade } from "./facades/lead.facade.mts";
import { WaitlistLeadRepository } from "./repositories/waitlist-lead.repository.mts";
import { GymLeadRepository } from "./repositories/gym-lead.repository.mts";
import { SesEmailService, UnconfiguredEmailService, type EmailService } from "./services/email.service.mts";

export interface Container {
  readonly db: Db;
  readonly verifier: JwtVerifier;
  readonly roleLookup: (userId: string) => Promise<UserRole | null>;
  readonly userFacade: UserFacade;
  readonly gymFacade: GymFacade;
  readonly openMatFacade: OpenMatFacade;
  readonly checkInFacade: CheckInFacade;
  readonly notificationFacade: NotificationFacade;
  readonly reportFacade: ReportFacade;
  readonly leadFacade: LeadFacade;
  readonly env: AppEnv;
  readonly geocoder: Geocoder;
  readonly assetStorage: AssetStorage;
  readonly audioStorage: AudioStorage;
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
  const reportRepo = new ReportRepository(db);
  const waitlistLeadRepo = new WaitlistLeadRepository(db);
  const gymLeadRepo = new GymLeadRepository(db);
  const emailService: EmailService =
    env.sesFrom && env.adminEmail
      ? new SesEmailService({ from: env.sesFrom, adminEmail: env.adminEmail }, undefined, env.sesRegion)
      : new UnconfiguredEmailService();
  const id = (): string => randomUUID();
  const geocoder = new ZipcodesGeocoder();
  const assetStorage: AssetStorage = env.assetsBucket
    ? new S3AssetStorage(env.assetsBucket, env.assetsRegion)
    : new UnconfiguredAssetStorage();
  const githubIssueService: GitHubIssueService | null = env.githubToken
    ? new HttpGitHubIssueService(env.githubToken, env.githubRepo)
    : null;
  const audioStorage: AudioStorage = env.audioBucket
    ? new S3AudioStorage(env.audioBucket, env.audioRegion)
    : new UnconfiguredAudioStorage();
  const transcription: TranscriptionService | null = env.openaiApiKey
    ? new WhisperTranscriptionService(env.openaiApiKey)
    : null;

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
    checkInFacade: new CheckInFacade(checkInRepo, openMatRepo, userRepo, gymRepo, id),
    notificationFacade: new NotificationFacade(notificationRepo, id),
    reportFacade: new ReportFacade(reportRepo, githubIssueService, audioStorage, transcription, id, env.githubRepo),
    leadFacade: new LeadFacade(waitlistLeadRepo, gymLeadRepo, emailService, id),
    env,
    geocoder,
    assetStorage,
    audioStorage,
    async ensureIndexes(): Promise<void> {
      await Promise.all([
        userRepo.ensureIndexes(),
        gymRepo.ensureIndexes(),
        openMatRepo.ensureIndexes(),
        rsvpRepo.ensureIndexes(),
        checkInRepo.ensureIndexes(),
        favoriteRepo.ensureIndexes(),
        notificationRepo.ensureIndexes(),
        reportRepo.ensureIndexes(),
        waitlistLeadRepo.ensureIndexes(),
        gymLeadRepo.ensureIndexes(),
      ]);
    },
  };
}
