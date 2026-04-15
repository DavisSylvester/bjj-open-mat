class Gym {
  final String id;
  final String? ownerId;
  final String name;
  final String? description;
  final String address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final GeoLocation? location;
  final String? googlePlaceId;
  final String? phone;
  final String? website;
  final List<String> amenities;
  final bool isVerified;
  final double? distanceKm;
  final String? createdAt;

  const Gym({
    required this.id,
    this.ownerId,
    required this.name,
    this.description,
    required this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.location,
    this.googlePlaceId,
    this.phone,
    this.website,
    this.amenities = const [],
    this.isVerified = false,
    this.distanceKm,
    this.createdAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) {
    GeoLocation? loc;
    if (json['location'] != null && json['location']['coordinates'] != null) {
      final coords = json['location']['coordinates'] as List;
      loc = GeoLocation(lng: (coords[0] as num).toDouble(), lat: (coords[1] as num).toDouble());
    }

    return Gym(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      ownerId: json['ownerId'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postalCode'] as String?,
      location: loc,
      googlePlaceId: json['googlePlaceId'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      amenities: (json['amenities'] as List?)?.cast<String>() ?? [],
      isVerified: json['isVerified'] as bool? ?? false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String?,
    );
  }
}

class GeoLocation {
  final double lat;
  final double lng;
  const GeoLocation({required this.lat, required this.lng});
}
