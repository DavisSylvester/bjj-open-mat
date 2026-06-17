import '../models/gym.dart';

class CreateGymRequest {
  final String name;
  final String address;
  final String? description;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final GeoLocation? location;
  final String? phone;
  final String? website;
  final List<String> amenities;

  const CreateGymRequest({
    required this.name,
    required this.address,
    this.description,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.location,
    this.phone,
    this.website,
    this.amenities = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (country != null && country!.isNotEmpty) 'country': country,
        if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
        if (location != null) 'location': {'lat': location!.lat, 'lng': location!.lng},
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (website != null && website!.isNotEmpty) 'website': website,
        if (amenities.isNotEmpty) 'amenities': amenities,
      };
}

class UpdateGymRequest {
  final Map<String, dynamic> _fields;
  const UpdateGymRequest(this._fields);
  Map<String, dynamic> toJson() => _fields;
}
