/// All API endpoint constants matching the BJJ Open Mat Finder backend
class Endpoints {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.bjj-open-mat.dsylvester.io');

  // Auth
  static const String authMe = '/api/v1/auth/me';
  static const String authSync = '/api/v1/auth/sync';

  // Users
  static const String usersMe = '/api/v1/users/me';
  static String userById(String id) => '/api/v1/users/$id';

  // Gyms
  static const String gyms = '/api/v1/gyms';
  static const String gymsNearby = '/api/v1/gyms/nearby';
  static String gymById(String id) => '/api/v1/gyms/$id';
  static String gymDirections(String id) => '/api/v1/gyms/$id/directions';
  static String gymFavorite(String id) => '/api/v1/gyms/$id/favorite';

  // Open Mats
  static const String openMats = '/api/v1/open-mats';
  static const String openMatsNearby = '/api/v1/open-mats/nearby';
  static String openMatById(String id) => '/api/v1/open-mats/$id';
  static String openMatCheckin(String id) => '/api/v1/open-mats/$id/checkin';
  static String openMatCheckins(String id) => '/api/v1/open-mats/$id/checkins';
  static String openMatRsvp(String id) => '/api/v1/open-mats/$id/rsvp';
  static String openMatAttendees(String id) => '/api/v1/open-mats/$id/attendees';

  // Check-ins
  static String checkinReview(String id) => '/api/v1/checkins/$id/review';
  static const String myCheckins = '/api/v1/users/me/checkins';

  // Favorites
  static const String myFavorites = '/api/v1/users/me/favorites';

  // Notifications
  static const String notifications = '/api/v1/notifications';
  static String notificationRead(String id) => '/api/v1/notifications/$id/read';
  static const String notificationsReadAll = '/api/v1/notifications/read-all';

  // Geo
  static const String geoReverse = '/api/v1/geo/reverse';
  static const String geoZip = '/api/v1/geo/zip';

  // Reports
  static const String reports = '/api/v1/reports';
  static const String reportAudioUploadUrl = '/api/v1/reports/audio-upload-url';
  static const String reportTranscribe = '/api/v1/reports/transcribe';

  // Health
  static const String health = '/health';

  // Membership
  static String gymMembers(String gymId) => '/api/v1/gyms/$gymId/members';
  static String gymMemberMe(String gymId) => '/api/v1/gyms/$gymId/members/me';
  static String gymMember(String gymId, String userId) => '/api/v1/gyms/$gymId/members/$userId';
  static String gymMemberPromotions(String gymId, String userId) => '/api/v1/gyms/$gymId/members/$userId/promotions';
  static String userPromotions(String userId) => '/api/v1/users/$userId/promotions';
  static const String myMemberships = '/api/v1/users/me/memberships';

  // Classes
  static String gymClasses(String gymId) => '/api/v1/gyms/$gymId/classes';
  static String gymSchedule(String gymId) => '/api/v1/gyms/$gymId/schedule';
  static String classById(String classId) => '/api/v1/classes/$classId';
  static String classOccurrence(String classId, String date) => '/api/v1/classes/$classId/occurrences/$date';
  static String classRsvp(String classId) => '/api/v1/classes/$classId/rsvp';
  static String classAttendees(String classId) => '/api/v1/classes/$classId/attendees';

  // Class Journal & Ratings
  static String classJournal(String classId) => '/api/v1/classes/$classId/journal';
  static const String myJournal = '/api/v1/users/me/journal';
  static String classInstructorRating(String classId) => '/api/v1/classes/$classId/instructor-rating';
  static String userInstructorRating(String userId) => '/api/v1/users/$userId/instructor-rating';
  static String gymInstructorFeedback(String gymId) => '/api/v1/gyms/$gymId/instructor-feedback';

  // Forum
  static String gymForumQuestions(String gymId) => '/api/v1/gyms/$gymId/forum/questions';
  static String forumQuestion(String questionId) => '/api/v1/forum/questions/$questionId';
  static String forumQuestionAnswers(String questionId) => '/api/v1/forum/questions/$questionId/answers';
  static String forumQuestionAccept(String questionId) => '/api/v1/forum/questions/$questionId/accept';
  static String forumAnswer(String answerId) => '/api/v1/forum/answers/$answerId';

  // Messaging
  static const String messagingDirect = '/api/v1/messaging/direct';
  static const String messagingGroups = '/api/v1/messaging/groups';
  static const String messagingConversations = '/api/v1/messaging/conversations';
  static String messagingConversationMessages(String id) => '/api/v1/messaging/conversations/$id/messages';
  static String messagingConversationRead(String id) => '/api/v1/messaging/conversations/$id/read';
  static String messagingConversationMute(String id) => '/api/v1/messaging/conversations/$id/mute';
  static String messagingConversationLeave(String id) => '/api/v1/messaging/conversations/$id/leave';
  static String messagingConversationParticipants(String id) => '/api/v1/messaging/conversations/$id/participants';
  static String messagingMessage(String id) => '/api/v1/messaging/messages/$id';
  static String messagingMessageReport(String id) => '/api/v1/messaging/messages/$id/report';
  static const String messagingReports = '/api/v1/messaging/reports';
  static String messagingReportResolve(String id) => '/api/v1/messaging/reports/$id/resolve';
  static const String messagingBlocks = '/api/v1/messaging/blocks';
  static String messagingBlock(String id) => '/api/v1/messaging/blocks/$id';
  static String gymChannels(String gymId) => '/api/v1/gyms/$gymId/channels';
  static String gymMessageReports(String gymId) => '/api/v1/gyms/$gymId/message-reports';
}
