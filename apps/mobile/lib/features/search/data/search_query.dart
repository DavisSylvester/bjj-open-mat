import 'when_range.dart';

class SearchQuery {
  final String? text;
  final String? giType; // gi|nogi|both
  final bool free;
  final WhenRange? when;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final String? zip;

  const SearchQuery({
    this.text,
    this.giType,
    this.free = false,
    this.when,
    this.lat,
    this.lng,
    this.radiusKm,
    this.zip,
  });

  Map<String, dynamic> toQueryParameters() => {
        if (text != null && text!.trim().isNotEmpty) 'q': text!.trim(),
        if (giType != null) 'giType': giType,
        if (free) 'free': true,
        if (when != null) 'startDate': when!.startIso,
        if (when != null) 'endDate': when!.endIso,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radiusKm': radiusKm,
        if (zip != null && zip!.trim().isNotEmpty) 'zip': zip!.trim(),
        'limit': 50,
      };

  SearchQuery copyWith({
    String? text,
    String? giType,
    bool? free,
    WhenRange? when,
    double? lat,
    double? lng,
    double? radiusKm,
    String? zip,
    bool clearGi = false,
    bool clearWhen = false,
    bool clearGeo = false,
  }) =>
      SearchQuery(
        text: text ?? this.text,
        giType: clearGi ? null : (giType ?? this.giType),
        free: free ?? this.free,
        when: clearWhen ? null : (when ?? this.when),
        lat: clearGeo ? null : (lat ?? this.lat),
        lng: clearGeo ? null : (lng ?? this.lng),
        radiusKm: radiusKm ?? this.radiusKm,
        zip: clearGeo ? null : (zip ?? this.zip),
      );
}
