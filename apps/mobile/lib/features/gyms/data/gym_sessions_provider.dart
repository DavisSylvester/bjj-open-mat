import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../shared/widgets/session_row.dart';
import '../../open_mats/models/open_mat.dart';

/// Maps the API skill level to the short code SessionRowData expects.
/// (Mirrors `_expLevel` in discover_screen.dart.)
String _expLevel(String skillLevel) => switch (skillLevel) {
      'beginner' => 'beg',
      'intermediate' => 'int',
      'advanced' => 'adv',
      _ => 'all',
    };

SessionRowData sessionRowFromOpenMat(OpenMat m) => SessionRowData(
      id: m.id,
      gymName: m.gymName ?? m.title,
      giType: m.giType,
      expLevel: _expLevel(m.skillLevel),
      time: m.startLabel,
      day: m.dayName,
      distance: m.distanceKm != null ? '${(m.distanceKm! / 1.60934).toStringAsFixed(1)} mi' : '',
      fee: (m.feeCents ?? 0) / 100,
      isLive: m.status == 'live',
      unverified: !m.verified,
    );

final gymSessionsProvider = FutureProvider.family<List<OpenMat>, String>((ref, gymId) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.openMats, queryParameters: {'gymId': gymId, 'limit': 50});
  return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
});
