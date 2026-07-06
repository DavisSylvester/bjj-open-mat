import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../checkins/models/checkin.dart';

typedef ProfileStats = ({int checkIns, int reviews, int gyms});

ProfileStats computeProfileStats(List<CheckIn> checkins) {
  final gyms = <String>{};
  var reviews = 0;
  for (final c in checkins) {
    if (c.gymId != null && c.gymId!.isNotEmpty) gyms.add(c.gymId!);
    if (c.rating != null) reviews += 1;
  }
  return (checkIns: checkins.length, reviews: reviews, gyms: gyms.length);
}

int? ageFromBirthday(String iso, {DateTime? now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final ref = now ?? DateTime.now();
  var age = ref.year - d.year;
  if (ref.month < d.month || (ref.month == d.month && ref.day < d.day)) age -= 1;
  return age < 0 ? null : age;
}

final myStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.myCheckins);
  final items = unwrapList(res.data as Map<String, dynamic>).items;
  final checkins = items.map((j) => CheckIn.fromJson(j)).toList();
  return computeProfileStats(checkins);
});
