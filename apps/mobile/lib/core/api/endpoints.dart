/// All API endpoint constants matching the BJJ Open Mat Finder backend
class Endpoints {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.bjj-open-mat.dsylvester.io');

  // Auth
  static const String authMe = '/api/v1/auth/me';

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

  // Check-ins
  static String checkinReview(String id) => '/api/v1/checkins/$id/review';
  static const String myCheckins = '/api/v1/users/me/checkins';

  // Favorites
  static const String myFavorites = '/api/v1/users/me/favorites';

  // Health
  static const String health = '/health';
}
