/// An immutable gym-search request. Coordinates and ZIP are mutually exclusive
/// on the wire: when GPS coordinates are available they win, and the ZIP is
/// dropped rather than sent alongside — the API would ignore it anyway, and
/// sending both invites confusion about which origin produced the results.
class GymSearchQuery {
  final String? q;
  final double? lat;
  final double? lng;
  final String? zip;
  final double radiusKm;
  final int page;
  final int limit;

  const GymSearchQuery({
    this.q,
    this.lat,
    this.lng,
    this.zip,
    required this.radiusKm,
    this.page = 1,
    this.limit = 20,
  });

  bool get hasCoords => lat != null && lng != null;
  bool get hasOrigin => hasCoords || (zip != null && zip!.trim().length == 5);

  Map<String, dynamic> toQueryParameters() {
    final text = q?.trim() ?? '';
    return <String, dynamic>{
      if (hasCoords) 'lat': lat,
      if (hasCoords) 'lng': lng,
      if (!hasCoords && zip != null && zip!.trim().isNotEmpty) 'zip': zip!.trim(),
      if (text.isNotEmpty) 'q': text,
      'radiusKm': radiusKm,
      'page': page,
      'limit': limit,
    };
  }

  GymSearchQuery copyWith({
    String? q,
    double? lat,
    double? lng,
    String? zip,
    double? radiusKm,
    int? page,
    int? limit,
    bool clearGeo = false,
  }) =>
      GymSearchQuery(
        q: q ?? this.q,
        lat: clearGeo ? null : (lat ?? this.lat),
        lng: clearGeo ? null : (lng ?? this.lng),
        zip: clearGeo ? null : (zip ?? this.zip),
        radiusKm: radiusKm ?? this.radiusKm,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GymSearchQuery &&
          q == other.q &&
          lat == other.lat &&
          lng == other.lng &&
          zip == other.zip &&
          radiusKm == other.radiusKm &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(q, lat, lng, zip, radiusKm, page, limit);
}
