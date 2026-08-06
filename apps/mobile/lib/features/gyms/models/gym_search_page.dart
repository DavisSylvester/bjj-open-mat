import 'gym.dart';

/// One page of gym search results.
///
/// [effectiveRadiusKm] is the radius that actually produced these results. The
/// API widens the search when the first page would be empty, so this can exceed
/// what the user asked for — the UI must surface that rather than let the
/// radius control misreport.
class GymSearchPage {
  final List<Gym> items;
  final int total;
  final double effectiveRadiusKm;

  const GymSearchPage({
    required this.items,
    required this.total,
    required this.effectiveRadiusKm,
  });

  static const GymSearchPage empty =
      GymSearchPage(items: <Gym>[], total: 0, effectiveRadiusKm: 0);

  factory GymSearchPage.fromEnvelope(
    Map<String, dynamic> body, {
    double requestedRadiusKm = 0,
  }) {
    final raw = body['data'];
    final list = raw is List ? raw : const <dynamic>[];
    final items = list
        .cast<Map<String, dynamic>>()
        .map(Gym.fromJson)
        .toList(growable: false);

    final meta = body['meta'];
    final metaMap = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};

    return GymSearchPage(
      items: items,
      total: (metaMap['total'] as num?)?.toInt() ?? items.length,
      effectiveRadiusKm:
          (metaMap['effectiveRadiusKm'] as num?)?.toDouble() ?? requestedRadiusKm,
    );
  }
}
