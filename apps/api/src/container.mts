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
import { GooglePlacesClient, NullPlacesClient, type PlacesClient } from "./services/places-client.mts";
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
import { MembershipFacade } from "./facades/membership.facade.mts";
import { ClassFacade } from "./facades/class.facade.mts";
import { ClassRepository } from "./repositories/class.repository.mts";
import { ClassOccurrenceRepository } from "./repositories/class-occurrence.repository.mts";
import { ClassRsvpRepository } from "./repositories/class-rsvp.repository.mts";
import { CheckInRepository } from "./repositories/check-in.repository.mts";
import { FavoriteRepository } from "./repositories/favorite.repository.mts";
import { GymRepository } from "./repositories/gym.repository.mts";
import { MembershipRepository } from "./repositories/membership.repository.mts";
import { PromotionRepository } from "./repositories/promotion.repository.mts";
import { NotificationRepository } from "./repositories/notification.repository.mts";
import { OpenMatRepository } from "./repositories/open-mat.repository.mts";
import { ReportRepository } from "./repositories/report.repository.mts";
import { RsvpRepository } from "./repositories/rsvp.repository.mts";
import { UserRepository } from "./repositories/user.repository.mts";
import { LeadFacade } from "./facades/lead.facade.mts";
import { WaitlistLeadRepository } from "./repositories/waitlist-lead.repository.mts";
import { GymLeadRepository } from "./repositories/gym-lead.repository.mts";
import { SesEmailService, UnconfiguredEmailService, type EmailService } from "./services/email.service.mts";
import {
  HttpAuth0ManagementService,
  UnconfiguredAuth0ManagementService,
  type Auth0ManagementService,
} from "./services/auth0-management.service.mts";
import { AccountDeletionOrchestrator, type AccountDeletionService } from "./services/account-deletion.service.mts";
import { ClassJournalRepository } from "./repositories/class-journal.repository.mts";
import { InstructorRatingRepository } from "./repositories/instructor-rating.repository.mts";
import { ClassJournalFacade } from "./facades/class-journal.facade.mts";
import { ForumFacade } from "./facades/forum.facade.mts";
import { ForumQuestionRepository } from "./repositories/forum-question.repository.mts";
import { ForumAnswerRepository } from "./repositories/forum-answer.repository.mts";
import { MessagingFacade } from "./facades/messaging.facade.mts";
import { ConversationRepository } from "./repositories/conversation.repository.mts";
import { MessageRepository } from "./repositories/message.repository.mts";
import { ConversationParticipantRepository } from "./repositories/conversation-participant.repository.mts";
import { ChannelReadStateRepository } from "./repositories/channel-read-state.repository.mts";
import { UserBlockRepository } from "./repositories/user-block.repository.mts";
import { MessageReportRepository } from "./repositories/message-report.repository.mts";
import { GymClaimFacade } from "./facades/gym-claim.facade.mts";
import { GymClaimRepository } from "./repositories/gym-claim.repository.mts";
import { DeviceTokenRepository } from "./repositories/device-token.repository.mts";
import { FcmPushSender } from "./push/fcm-push-sender.mts";
import { PushService } from "./push/push.service.mts";
import type { PushSender } from "./push/push.types.mts";
import { logger } from "./config/logger.mts";
import { GoogleAuth } from "google-auth-library";

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
  readonly membershipFacade: MembershipFacade;
  readonly classFacade: ClassFacade;
  readonly classJournalFacade: ClassJournalFacade;
  readonly forumFacade: ForumFacade;
  readonly messagingFacade: MessagingFacade;
  readonly gymClaimFacade: GymClaimFacade;
  readonly deviceTokenRepo: DeviceTokenRepository;
  readonly pushService: PushService;
  readonly id: () => string;
  readonly accountDeletionService: AccountDeletionService;
  readonly env: AppEnv;
  readonly geocoder: Geocoder;
  readonly assetStorage: AssetStorage;
  readonly audioStorage: AudioStorage;
  readonly placesClient: PlacesClient;
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
  const membershipRepo = new MembershipRepository(db);
  const promotionRepo = new PromotionRepository(db);
  const classRepo = new ClassRepository(db);
  const classOccurrenceRepo = new ClassOccurrenceRepository(db);
  const classRsvpRepo = new ClassRsvpRepository(db);
  const classJournalRepo = new ClassJournalRepository(db);
  const instructorRatingRepo = new InstructorRatingRepository(db);
  const forumQuestionRepo = new ForumQuestionRepository(db);
  const forumAnswerRepo = new ForumAnswerRepository(db);
  const conversationRepo = new ConversationRepository(db);
  const messageRepo = new MessageRepository(db);
  const conversationParticipantRepo = new ConversationParticipantRepository(db);
  const channelReadStateRepo = new ChannelReadStateRepository(db);
  const userBlockRepo = new UserBlockRepository(db);
  const messageReportRepo = new MessageReportRepository(db);
  const gymClaimRepo = new GymClaimRepository(db);
  const deviceTokenRepo = new DeviceTokenRepository(db);

  let pushSender: PushSender;
  if (env.fcmProjectId && env.fcmServiceAccountJson) {
    try {
      const credentials = JSON.parse(env.fcmServiceAccountJson) as Record<string, unknown>;
      const auth = new GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
      });
      const accessToken = async (): Promise<string> => {
        const c = await auth.getClient();
        const t = await c.getAccessToken();
        if (!t.token) throw new Error("no FCM access token");
        return t.token;
      };
      pushSender = new FcmPushSender({ projectId: env.fcmProjectId, accessToken });
    } catch (err) {
      logger.error("push notifications disabled — FCM_SERVICE_ACCOUNT_JSON is invalid JSON", { err });
      pushSender = { send: async (): Promise<{ unregistered: string[] }> => ({ unregistered: [] }) };
    }
  } else {
    pushSender = { send: async (): Promise<{ unregistered: string[] }> => ({ unregistered: [] }) };
    logger.info("push notifications disabled — FCM_PROJECT_ID or FCM_SERVICE_ACCOUNT_JSON not set");
  }
  const pushService = new PushService(deviceTokenRepo, pushSender);

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
  const auth0Management: Auth0ManagementService =
    env.auth0Domain && env.auth0M2mClientId && env.auth0M2mClientSecret
      ? new HttpAuth0ManagementService(env.auth0Domain, env.auth0M2mClientId, env.auth0M2mClientSecret)
      : new UnconfiguredAuth0ManagementService();
  const placesClient: PlacesClient = env.googlePlacesApiKey
    ? new GooglePlacesClient(env.googlePlacesApiKey)
    : new NullPlacesClient();

  const membershipFacade = new MembershipFacade(membershipRepo, promotionRepo, gymRepo, userRepo, id);

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
    userFacade: new UserFacade(userRepo, membershipFacade),
    gymFacade: new GymFacade(gymRepo, favoriteRepo, id, geocoder, placesClient),
    openMatFacade: new OpenMatFacade(openMatRepo, gymRepo, rsvpRepo, id, geocoder),
    checkInFacade: new CheckInFacade(checkInRepo, openMatRepo, userRepo, gymRepo, id),
    notificationFacade: new NotificationFacade(notificationRepo, pushService, id),
    reportFacade: new ReportFacade(reportRepo, githubIssueService, audioStorage, transcription, id, env.githubRepo),
    leadFacade: new LeadFacade(waitlistLeadRepo, gymLeadRepo, emailService, id),
    membershipFacade,
    classFacade: new ClassFacade(classRepo, classOccurrenceRepo, classRsvpRepo, membershipRepo, gymRepo, userRepo, id),
    classJournalFacade: new ClassJournalFacade(classJournalRepo, instructorRatingRepo, classRepo, classOccurrenceRepo, membershipRepo, gymRepo, userRepo, id),
    forumFacade: new ForumFacade(forumQuestionRepo, forumAnswerRepo, membershipRepo, gymRepo, notificationRepo, pushService, id),
    messagingFacade: new MessagingFacade(conversationRepo, messageRepo, conversationParticipantRepo, channelReadStateRepo, userBlockRepo, messageReportRepo, membershipRepo, gymRepo, userRepo, id),
    gymClaimFacade: new GymClaimFacade(gymClaimRepo, gymRepo, userRepo, membershipRepo, notificationRepo, pushService, id),
    deviceTokenRepo,
    pushService,
    id,
    accountDeletionService: new AccountDeletionOrchestrator(
      userRepo,
      checkInRepo,
      favoriteRepo,
      rsvpRepo,
      notificationRepo,
      auth0Management,
    ),
    env,
    geocoder,
    assetStorage,
    audioStorage,
    placesClient,
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
        membershipRepo.ensureIndexes(),
        promotionRepo.ensureIndexes(),
        classRepo.ensureIndexes(),
        classOccurrenceRepo.ensureIndexes(),
        classRsvpRepo.ensureIndexes(),
        classJournalRepo.ensureIndexes(),
        instructorRatingRepo.ensureIndexes(),
        forumQuestionRepo.ensureIndexes(),
        forumAnswerRepo.ensureIndexes(),
        conversationRepo.ensureIndexes(),
        messageRepo.ensureIndexes(),
        conversationParticipantRepo.ensureIndexes(),
        channelReadStateRepo.ensureIndexes(),
        userBlockRepo.ensureIndexes(),
        messageReportRepo.ensureIndexes(),
        gymClaimRepo.ensureIndexes(),
        deviceTokenRepo.ensureIndexes(),
      ]);
    },
  };
}
