# BJJ Open Mat — UI Redesign & Feature Expansion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the BJJ Open Mat Flutter UI and add gym creation with Google Maps address validation, full open mat scheduling (gi type, mat fee, 2/day limit), GPS + location-based search, and a multi-category post-session rating system.

**Architecture:** All features live in the existing Flutter + Riverpod v3 + GoRouter v17 stack. New features follow the existing feature-folder pattern (`lib/features/<feature>/`). Address validation calls the Google Maps Places Autocomplete and Geocoding REST APIs via Dio. The 2-per-day open mat limit is enforced client-side by fetching existing sessions for the gym+day before submission. Ratings are submitted per-category (gym quality, experience level, cleanliness, friendliness) to the existing checkin review endpoint with an expanded payload.

**Tech Stack:** Flutter 3.29, Riverpod v3, GoRouter v17, Dio, `google_maps_flutter`, `geolocator`

**Prerequisite:** A Google Maps API key with Places API + Geocoding API enabled. Pass it at run time with `--dart-define=GOOGLE_MAPS_API_KEY=<key>`.

---

## File Map

**New files:**
- `lib/core/maps/models/place_result.dart` — address suggestion + validated lat/lng
- `lib/core/maps/google_maps_service.dart` — Places Autocomplete + Details REST calls
- `lib/features/gyms/widgets/address_search_field.dart` — autocomplete text field for address input
- `lib/features/gyms/screens/create_gym_screen.dart` — 3-step gym creation wizard
- `lib/shared/widgets/gi_type_selector.dart` — Gi / No-Gi / Gi+No-Gi chip selector
- `lib/shared/widgets/star_rating_row.dart` — tappable 5-star row
- `lib/shared/widgets/category_rating_row.dart` — label + star rating in a row
- `test/unit/features/open_mats/open_mat_model_test.dart`
- `test/unit/core/maps/google_maps_service_test.dart`
- `test/widget/shared/star_rating_row_test.dart`
- `test/widget/shared/gi_type_selector_test.dart`

**Modified files:**
- `lib/core/api/endpoints.dart` — fix `/healthz` → `/health`; add gym reviews, search, per-gym session endpoints
- `lib/app/theme.dart` — add gi-type colors, success color, `GiColors` helper
- `lib/features/open_mats/models/open_mat.dart` — replace `isGiSession: bool` with `giType: String`; add `matFee`
- `lib/features/gyms/models/gym.dart` — add `averageRating`, `reviewCount`
- `lib/features/admin/screens/create_session_screen.dart` — full overhaul with gi type, mat fee, gymId, 2/day check
- `lib/features/checkins/screens/review_screen.dart` — expand to 4 category ratings + comments
- `lib/features/search/screens/search_screen.dart` — GPS button, query field (city/ZIP), giType filter
- `lib/features/gyms/screens/gym_detail_screen.dart` — show open mat schedule table + ratings summary
- `lib/app/router.dart` — add `/owner/gyms/new` route; thread `gymId` into session create

---

## Task 1: Fix Health Endpoint + Add Missing Endpoints

**Files:**
- Modify: `lib/core/api/endpoints.dart`

- [ ] **Step 1: Replace endpoints.dart**

```dart
class Endpoints {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3100');

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
  static String gymReviews(String id) => '/api/v1/gyms/$id/reviews';

  // Open Mats
  static const String openMats = '/api/v1/open-mats';
  static const String openMatsNearby = '/api/v1/open-mats/nearby';
  static const String openMatsSearch = '/api/v1/open-mats/search';
  static String openMatById(String id) => '/api/v1/open-mats/$id';
  static String openMatCheckin(String id) => '/api/v1/open-mats/$id/checkin';
  static String openMatCheckins(String id) => '/api/v1/open-mats/$id/checkins';
  static String openMatsByGym(String gymId) => '/api/v1/gyms/$gymId/open-mats';

  // Check-ins & Reviews
  static String checkinReview(String id) => '/api/v1/checkins/$id/review';
  static const String myCheckins = '/api/v1/users/me/checkins';

  // Favorites
  static const String myFavorites = '/api/v1/users/me/favorites';

  // Health
  static const String health = '/health';
  static const String ready = '/ready';
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/core/api/endpoints.dart
git commit -m "fix: correct health endpoint to /health and add gym reviews + search endpoints"
```

---

## Task 2: Design System — Gi Colors + Success Token

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Add tokens to StitchTokens (after `glassBorder`)**

```dart
  static const success = Color(0xFF10B981);
  static const giColor = Color(0xFF3B82F6);
  static const noGiColor = Color(0xFFF59E0B);
  static const bothColor = Color(0xFF8B5CF6);
  static const divider = Color(0xFFE5E7EB);
  static const surfaceCard = Color(0xFFFFFFFF);

  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
```

- [ ] **Step 2: Add GiColors helper class (after BeltColors)**

```dart
class GiColors {
  static Color from(String giType) {
    switch (giType) {
      case 'no_gi': return StitchTokens.noGiColor;
      case 'both': return StitchTokens.bothColor;
      default: return StitchTokens.giColor;
    }
  }

  static String label(String giType) {
    switch (giType) {
      case 'no_gi': return 'No-Gi';
      case 'both': return 'Gi + No-Gi';
      default: return 'Gi';
    }
  }
}
```

- [ ] **Step 3: Add labelSmall style to `_textTheme` (inside the TextTheme(...) call)**

```dart
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: StitchTokens.textSecondary),
```

- [ ] **Step 4: Run analyze**
```
flutter analyze lib/app/theme.dart
```
Expected: No issues.

- [ ] **Step 5: Commit**
```bash
git add lib/app/theme.dart
git commit -m "feat: add gi-type colors, success token, GiColors helper, and labelSmall style"
```

---

## Task 3: OpenMat Model — Add `giType` and `matFee`

**Files:**
- Modify: `lib/features/open_mats/models/open_mat.dart`
- Create: `test/unit/features/open_mats/open_mat_model_test.dart`

- [ ] **Step 1: Write failing unit test**

Create `test/unit/features/open_mats/open_mat_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/open_mats/models/open_mat.dart';

void main() {
  group('OpenMat.fromJson', () {
    test('parses giType field directly', () {
      final mat = OpenMat.fromJson({
        'id': '1', 'gymId': 'g1', 'title': 'T',
        'startTime': '10:00', 'endTime': '12:00',
        'giType': 'both',
      });
      expect(mat.giType, 'both');
    });

    test('falls back: isGiSession true → gi', () {
      final mat = OpenMat.fromJson({
        'id': '1', 'gymId': 'g1', 'title': 'T',
        'startTime': '10:00', 'endTime': '12:00',
        'isGiSession': true,
      });
      expect(mat.giType, 'gi');
    });

    test('falls back: isGiSession false → no_gi', () {
      final mat = OpenMat.fromJson({
        'id': '1', 'gymId': 'g1', 'title': 'T',
        'startTime': '10:00', 'endTime': '12:00',
        'isGiSession': false,
      });
      expect(mat.giType, 'no_gi');
    });

    test('parses matFee as double', () {
      final mat = OpenMat.fromJson({
        'id': '1', 'gymId': 'g1', 'title': 'T',
        'startTime': '10:00', 'endTime': '12:00',
        'matFee': 10,
      });
      expect(mat.matFee, 10.0);
    });
  });

  group('OpenMat.giBadge', () {
    test('returns "Gi" for gi', () {
      const mat = OpenMat(id: '1', gymId: 'g1', title: 'T', startTime: '10:00', endTime: '12:00', giType: 'gi');
      expect(mat.giBadge, 'Gi');
    });
    test('returns "No-Gi" for no_gi', () {
      const mat = OpenMat(id: '1', gymId: 'g1', title: 'T', startTime: '10:00', endTime: '12:00', giType: 'no_gi');
      expect(mat.giBadge, 'No-Gi');
    });
    test('returns "Gi + No-Gi" for both', () {
      const mat = OpenMat(id: '1', gymId: 'g1', title: 'T', startTime: '10:00', endTime: '12:00', giType: 'both');
      expect(mat.giBadge, 'Gi + No-Gi');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
```
flutter test test/unit/features/open_mats/open_mat_model_test.dart
```
Expected: FAIL — `giType` field not found.

- [ ] **Step 3: Replace OpenMat model**

Replace `lib/features/open_mats/models/open_mat.dart`:

```dart
class OpenMat {
  final String id;
  final String gymId;
  final String? hostId;
  final String title;
  final String? description;
  final int? dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isRecurring;
  final String? specificDate;
  final int? maxParticipants;
  final String skillLevel;
  final String giType; // 'gi' | 'no_gi' | 'both'
  final double? matFee;
  final bool isCancelled;
  final int? checkinCount;
  final String? gymName;
  final double? distanceKm;
  final String? createdAt;

  const OpenMat({
    required this.id,
    required this.gymId,
    this.hostId,
    required this.title,
    this.description,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isRecurring = true,
    this.specificDate,
    this.maxParticipants,
    this.skillLevel = 'all',
    this.giType = 'gi',
    this.matFee,
    this.isCancelled = false,
    this.checkinCount,
    this.gymName,
    this.distanceKm,
    this.createdAt,
  });

  factory OpenMat.fromJson(Map<String, dynamic> json) {
    final String giType;
    if (json['giType'] != null) {
      giType = json['giType'] as String;
    } else {
      giType = (json['isGiSession'] as bool? ?? false) ? 'gi' : 'no_gi';
    }
    return OpenMat(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      gymId: json['gymId'] as String? ?? '',
      hostId: json['hostId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dayOfWeek: json['dayOfWeek'] as int?,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      isRecurring: json['isRecurring'] as bool? ?? true,
      specificDate: json['specificDate'] as String?,
      maxParticipants: json['maxParticipants'] as int?,
      skillLevel: json['skillLevel'] as String? ?? 'all',
      giType: giType,
      matFee: (json['matFee'] as num?)?.toDouble(),
      isCancelled: json['isCancelled'] as bool? ?? false,
      checkinCount: json['checkinCount'] as int?,
      gymName: json['gymName'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'skillLevel': skillLevel,
    'giType': giType,
    'matFee': matFee,
    'isRecurring': isRecurring,
    'maxParticipants': maxParticipants ?? 0,
  };

  String get skillBadge {
    switch (skillLevel) {
      case 'beginner': return 'Beginner';
      case 'intermediate': return 'Intermediate';
      case 'advanced': return 'Advanced';
      default: return 'All Levels';
    }
  }

  String get giBadge {
    switch (giType) {
      case 'no_gi': return 'No-Gi';
      case 'both': return 'Gi + No-Gi';
      default: return 'Gi';
    }
  }

  String get dayName {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7
        ? days[dayOfWeek!]
        : '';
  }
}
```

- [ ] **Step 4: Run tests**
```
flutter test test/unit/features/open_mats/open_mat_model_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run analyze**
```
flutter analyze
```
Expected: No issues.

- [ ] **Step 6: Commit**
```bash
git add lib/features/open_mats/models/open_mat.dart test/unit/features/open_mats/open_mat_model_test.dart
git commit -m "feat: replace isGiSession with giType enum, add matFee to OpenMat model"
```

---

## Task 4: Shared Widgets — GiTypeSelector + StarRatingRow + CategoryRatingRow

**Files:**
- Create: `lib/shared/widgets/gi_type_selector.dart`
- Create: `lib/shared/widgets/star_rating_row.dart`
- Create: `lib/shared/widgets/category_rating_row.dart`
- Create: `test/widget/shared/gi_type_selector_test.dart`
- Create: `test/widget/shared/star_rating_row_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/widget/shared/gi_type_selector_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/gi_type_selector.dart';

void main() {
  group('GiTypeSelector', () {
    testWidgets('renders three options', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GiTypeSelector(value: 'gi', onChanged: (_) {})),
      ));
      expect(find.text('Gi'), findsOneWidget);
      expect(find.text('No-Gi'), findsOneWidget);
      expect(find.text('Gi + No-Gi'), findsOneWidget);
    });

    testWidgets('tapping No-Gi calls onChanged with no_gi', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GiTypeSelector(value: 'gi', onChanged: (v) => result = v)),
      ));
      await tester.tap(find.text('No-Gi'));
      await tester.pump();
      expect(result, 'no_gi');
    });
  });
}
```

Create `test/widget/shared/star_rating_row_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/shared/widgets/star_rating_row.dart';

void main() {
  group('StarRatingRow', () {
    testWidgets('shows filled stars up to rating', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StarRatingRow(rating: 3, onChanged: (_) {})),
      ));
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    });

    testWidgets('tapping 4th star calls onChanged(4)', (tester) async {
      int? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StarRatingRow(rating: 0, onChanged: (v) => tapped = v)),
      ));
      await tester.tap(find.byType(GestureDetector).at(3));
      await tester.pump();
      expect(tapped, 4);
    });

    testWidgets('readOnly: taps do not trigger onChanged', (tester) async {
      int calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StarRatingRow(rating: 4, onChanged: (_) => calls++, readOnly: true)),
      ));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(calls, 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**
```
flutter test test/widget/shared/
```
Expected: FAIL — widgets not found.

- [ ] **Step 3: Create GiTypeSelector**

Create `lib/shared/widgets/gi_type_selector.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';

class GiTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const GiTypeSelector({super.key, required this.value, required this.onChanged});

  static const _options = [
    ('gi', 'Gi'),
    ('no_gi', 'No-Gi'),
    ('both', 'Gi + No-Gi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.map((opt) {
        final (key, label) = opt;
        final isSelected = value == key;
        final color = GiColors.from(key);
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          selectedColor: color.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: isSelected ? color : StitchTokens.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(color: isSelected ? color : StitchTokens.divider),
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onChanged(key);
          },
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Create StarRatingRow**

Create `lib/shared/widgets/star_rating_row.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';

class StarRatingRow extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final bool readOnly;
  final double size;

  const StarRatingRow({
    super.key,
    required this.rating,
    required this.onChanged,
    this.readOnly = false,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starNum = i + 1;
        return GestureDetector(
          onTap: readOnly
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onChanged(starNum);
                },
          child: Icon(
            starNum <= rating ? Icons.star : Icons.star_border_rounded,
            color: starNum <= rating ? StitchTokens.warning : StitchTokens.textSecondary,
            size: size,
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 5: Create CategoryRatingRow**

Create `lib/shared/widgets/category_rating_row.dart`:
```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'star_rating_row.dart';

class CategoryRatingRow extends StatelessWidget {
  final String label;
  final int rating;
  final ValueChanged<int> onChanged;

  const CategoryRatingRow({
    super.key,
    required this.label,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StitchTokens.sm),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          StarRatingRow(rating: rating, onChanged: onChanged, size: 28),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests**
```
flutter test test/widget/shared/
```
Expected: PASS all.

- [ ] **Step 7: Commit**
```bash
git add lib/shared/widgets/gi_type_selector.dart lib/shared/widgets/star_rating_row.dart lib/shared/widgets/category_rating_row.dart test/widget/shared/
git commit -m "feat: add GiTypeSelector, StarRatingRow, and CategoryRatingRow shared widgets"
```

---

## Task 5: Google Maps Address Service + AddressSearchField

**Files:**
- Create: `lib/core/maps/models/place_result.dart`
- Create: `lib/core/maps/google_maps_service.dart`
- Create: `lib/features/gyms/widgets/address_search_field.dart`
- Create: `test/unit/core/maps/google_maps_service_test.dart`

- [ ] **Step 1: Create PlaceResult model**

Create `lib/core/maps/models/place_result.dart`:
```dart
class PlaceResult {
  final String placeId;
  final String description;
  final String? streetNumber;
  final String? route;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? lat;
  final double? lng;

  const PlaceResult({
    required this.placeId,
    required this.description,
    this.streetNumber,
    this.route,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.lat,
    this.lng,
  });

  String get streetAddress {
    final parts = [streetNumber, route].whereType<String>().toList();
    return parts.isEmpty ? description : parts.join(' ');
  }
}
```

- [ ] **Step 2: Write failing unit test**

Create `test/unit/core/maps/google_maps_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/maps/google_maps_service.dart';

void main() {
  group('GoogleMapsService.parseComponents', () {
    test('extracts all address parts', () {
      final components = [
        {'types': ['street_number'], 'long_name': '123'},
        {'types': ['route'], 'long_name': 'Main St'},
        {'types': ['locality'], 'long_name': 'Austin'},
        {'types': ['administrative_area_level_1'], 'long_name': 'Texas'},
        {'types': ['postal_code'], 'long_name': '78701'},
        {'types': ['country'], 'long_name': 'United States'},
      ];
      final result = GoogleMapsService.parseComponents(components, 'p1', '123 Main St, Austin, TX');
      expect(result.streetNumber, '123');
      expect(result.route, 'Main St');
      expect(result.city, 'Austin');
      expect(result.state, 'Texas');
      expect(result.postalCode, '78701');
      expect(result.country, 'United States');
    });

    test('returns empty fields when no components', () {
      final result = GoogleMapsService.parseComponents([], 'p1', 'Somewhere');
      expect(result.city, isNull);
      expect(result.description, 'Somewhere');
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**
```
flutter test test/unit/core/maps/google_maps_service_test.dart
```
Expected: FAIL.

- [ ] **Step 4: Create GoogleMapsService**

Create `lib/core/maps/google_maps_service.dart`:
```dart
import 'package:dio/dio.dart';
import 'models/place_result.dart';

class GoogleMapsService {
  static const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  final Dio _dio;

  GoogleMapsService({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<PlaceResult>> autocomplete(String input) async {
    if (input.length < 3 || _apiKey.isEmpty) return [];
    try {
      final response = await _dio.get(_autocompleteUrl, queryParameters: {
        'input': input,
        'types': 'address',
        'key': _apiKey,
      });
      final predictions = response.data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlaceResult(
                placeId: p['place_id'] as String,
                description: p['description'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<PlaceResult?> getDetails(String placeId) async {
    if (_apiKey.isEmpty) return null;
    try {
      final response = await _dio.get(_detailsUrl, queryParameters: {
        'place_id': placeId,
        'fields': 'address_components,geometry,formatted_address',
        'key': _apiKey,
      });
      final result = response.data['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final components = (result['address_components'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final location =
          result['geometry']?['location'] as Map<String, dynamic>?;
      final place = parseComponents(
        components,
        placeId,
        result['formatted_address'] as String? ?? '',
      );
      if (location == null) return place;
      return PlaceResult(
        placeId: place.placeId,
        description: place.description,
        streetNumber: place.streetNumber,
        route: place.route,
        city: place.city,
        state: place.state,
        country: place.country,
        postalCode: place.postalCode,
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static PlaceResult parseComponents(
    List<Map<String, dynamic>> components,
    String placeId,
    String description,
  ) {
    String? streetNumber, route, city, state, country, postalCode;
    for (final c in components) {
      final types = (c['types'] as List).cast<String>();
      final name = c['long_name'] as String;
      if (types.contains('street_number')) streetNumber = name;
      if (types.contains('route')) route = name;
      if (types.contains('locality')) city = name;
      if (types.contains('administrative_area_level_1')) state = name;
      if (types.contains('country')) country = name;
      if (types.contains('postal_code')) postalCode = name;
    }
    return PlaceResult(
      placeId: placeId,
      description: description,
      streetNumber: streetNumber,
      route: route,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
    );
  }
}
```

- [ ] **Step 5: Run tests**
```
flutter test test/unit/core/maps/google_maps_service_test.dart
```
Expected: PASS.

- [ ] **Step 6: Create AddressSearchField widget**

Create `lib/features/gyms/widgets/address_search_field.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/maps/google_maps_service.dart';
import '../../../core/maps/models/place_result.dart';

class AddressSearchField extends StatefulWidget {
  final ValueChanged<PlaceResult> onSelected;
  final String? initialValue;

  const AddressSearchField({
    super.key,
    required this.onSelected,
    this.initialValue,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final _ctrl = TextEditingController();
  final _maps = GoogleMapsService();
  List<PlaceResult> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _ctrl.text = widget.initialValue!;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    if (value.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    final results = await _maps.autocomplete(value);
    if (mounted) setState(() { _suggestions = results; _loading = false; });
  }

  Future<void> _onTap(PlaceResult suggestion) async {
    setState(() { _loading = true; _suggestions = []; });
    final details = await _maps.getDetails(suggestion.placeId);
    if (!mounted) return;
    _ctrl.text = (details ?? suggestion).description;
    setState(() => _loading = false);
    widget.onSelected(details ?? suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: 'Gym Address *',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(_suggestions[i].description,
                    style: Theme.of(context).textTheme.bodyMedium),
                onTap: () => _onTap(_suggestions[i]),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 7: Run analyze**
```
flutter analyze lib/core/maps/ lib/features/gyms/widgets/address_search_field.dart
```
Expected: No issues.

- [ ] **Step 8: Commit**
```bash
git add lib/core/maps/ lib/features/gyms/widgets/address_search_field.dart test/unit/core/maps/
git commit -m "feat: Google Maps service with Places autocomplete and AddressSearchField widget"
```

---

## Task 6: Gym Creation Wizard (3-Step)

**Files:**
- Create: `lib/features/gyms/screens/create_gym_screen.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create CreateGymScreen**

Create `lib/features/gyms/screens/create_gym_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/maps/models/place_result.dart';
import '../widgets/address_search_field.dart';

class CreateGymScreen extends ConsumerStatefulWidget {
  const CreateGymScreen({super.key});

  @override
  ConsumerState<CreateGymScreen> createState() => _CreateGymScreenState();
}

class _CreateGymScreenState extends ConsumerState<CreateGymScreen> {
  int _step = 0;
  bool _isSaving = false;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Step 2 — set by AddressSearchField
  PlaceResult? _selectedPlace;

  // Step 3
  static const _amenityOptions = [
    'showers', 'parking', 'water', 'changing_rooms', 'wifi', 'pro_shop',
  ];
  final Set<String> _selectedAmenities = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  bool get _step1Valid => _nameCtrl.text.trim().isNotEmpty;
  bool get _step2Valid =>
      _selectedPlace != null &&
      _selectedPlace!.lat != null &&
      _selectedPlace!.lng != null;

  Future<void> _submit() async {
    if (!_step2Valid) return;
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.gyms, data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'address': _selectedPlace!.streetAddress,
        'city': _selectedPlace!.city,
        'state': _selectedPlace!.state,
        'country': _selectedPlace!.country,
        'postalCode': _selectedPlace!.postalCode,
        'googlePlaceId': _selectedPlace!.placeId,
        'location': {
          'type': 'Point',
          'coordinates': [_selectedPlace!.lng, _selectedPlace!.lat],
        },
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'amenities': _selectedAmenities.toList(),
      });
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gym created!')));
        context.go('/owner/gyms');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Gym'),
        leading: _step == 0
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, total: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StitchTokens.lg),
              child: [_buildStep1(), _buildStep2(), _buildStep3()][_step],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildStep1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Gym Details', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: StitchTokens.sm),
      Text('Start with the basics.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: StitchTokens.textSecondary)),
      const SizedBox(height: StitchTokens.lg),
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Gym Name *',
          prefixIcon: Icon(Icons.sports_martial_arts),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: StitchTokens.md),
      TextField(
        controller: _descCtrl,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Description (optional)'),
      ),
      const SizedBox(height: StitchTokens.md),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone (optional)',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      ),
      const SizedBox(height: StitchTokens.md),
      TextField(
        controller: _websiteCtrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Website (optional)',
          prefixIcon: Icon(Icons.language_outlined),
        ),
      ),
    ],
  );

  Widget _buildStep2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Location', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: StitchTokens.sm),
      Text(
        'Type your address — we\'ll validate it with Google Maps.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: StitchTokens.textSecondary),
      ),
      const SizedBox(height: StitchTokens.lg),
      AddressSearchField(
        onSelected: (place) => setState(() => _selectedPlace = place),
      ),
      if (_selectedPlace != null && _selectedPlace!.lat != null) ...[
        const SizedBox(height: StitchTokens.md),
        _ConfirmedAddressBadge(place: _selectedPlace!),
      ],
      if (_selectedPlace != null && _selectedPlace!.lat == null)
        Padding(
          padding: const EdgeInsets.only(top: StitchTokens.sm),
          child: Text(
            'Address could not be verified. Try a more specific address.',
            style: TextStyle(color: StitchTokens.error, fontSize: 13),
          ),
        ),
    ],
  );

  Widget _buildStep3() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Amenities', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: StitchTokens.sm),
      Text('What does your gym offer? (optional)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: StitchTokens.textSecondary)),
      const SizedBox(height: StitchTokens.lg),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _amenityOptions.map((a) {
          final selected = _selectedAmenities.contains(a);
          return FilterChip(
            label: Text(a.replaceAll('_', ' ')),
            selected: selected,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => selected ? _selectedAmenities.remove(a) : _selectedAmenities.add(a));
            },
          );
        }).toList(),
      ),
    ],
  );

  Widget _buildFooter() {
    final isLast = _step == 2;
    final canProceed = _step == 0 ? _step1Valid : _step == 1 ? _step2Valid : true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            StitchTokens.lg, 0, StitchTokens.lg, StitchTokens.md),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canProceed && !_isSaving
                ? () {
                    HapticFeedback.lightImpact();
                    isLast ? _submit() : setState(() => _step++);
                  }
                : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(isLast ? 'Create Gym' : 'Next →'),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          StitchTokens.lg, StitchTokens.sm, StitchTokens.lg, 0),
      child: Row(
        children: List.generate(total, (i) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i <= current ? StitchTokens.secondary : StitchTokens.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }
}

class _ConfirmedAddressBadge extends StatelessWidget {
  final PlaceResult place;
  const _ConfirmedAddressBadge({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StitchTokens.md),
      decoration: BoxDecoration(
        color: StitchTokens.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
        border: Border.all(color: StitchTokens.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: StitchTokens.success),
          const SizedBox(width: StitchTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.description,
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${place.lat!.toStringAsFixed(5)}, ${place.lng!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add import + route in router.dart**

Add to imports at top of `lib/app/router.dart`:
```dart
import '../features/gyms/screens/create_gym_screen.dart';
```

In the owner gyms branch, replace the existing `add` route:
```dart
GoRoute(
  path: 'add',
  builder: (context, state) => const CreateGymScreen(),
),
```

- [ ] **Step 3: Run analyze**
```
flutter analyze
```
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add lib/features/gyms/screens/create_gym_screen.dart lib/app/router.dart
git commit -m "feat: 3-step gym creation wizard with Google Maps address validation"
```

---

## Task 7: Open Mat Creation — Gi Type, Mat Fee, 2/Day Limit

**Files:**
- Modify: `lib/features/admin/screens/create_session_screen.dart`
- Modify: `lib/app/router.dart` — thread `gymId` query param

- [ ] **Step 1: Replace CreateSessionScreen**

Replace `lib/features/admin/screens/create_session_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/gi_type_selector.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  final String gymId;
  const CreateSessionScreen({super.key, required this.gymId});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _matFeeCtrl = TextEditingController();
  int _dayOfWeek = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  String _skillLevel = 'all';
  String _giType = 'gi';
  bool _isRecurring = true;
  bool _isSaving = false;
  String? _dayLimitError;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _levels = [
    ('all', 'All Levels'),
    ('beginner', 'Beginner'),
    ('intermediate', 'Intermediate'),
    ('advanced', 'Advanced'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _matFeeCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<bool> _checkDayLimit() async {
    if (widget.gymId.isEmpty) return true;
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        Endpoints.openMatsByGym(widget.gymId),
        queryParameters: {'dayOfWeek': _dayOfWeek},
      );
      final data = response.data['data'];
      final List items = data is List
          ? data
          : (data is Map ? (data['items'] as List? ?? []) : []);
      if (items.length >= 2) {
        setState(() => _dayLimitError =
            'Already 2 open mats on ${_days[_dayOfWeek]}. Maximum is 2 per day.');
        return false;
      }
      setState(() => _dayLimitError = null);
      return true;
    } catch (_) {
      setState(() => _dayLimitError = null);
      return true;
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final ok = await _checkDayLimit();
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.openMats, data: {
        'gymId': widget.gymId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'dayOfWeek': _dayOfWeek,
        'startTime': _fmtTime(_startTime),
        'endTime': _fmtTime(_endTime),
        'skillLevel': _skillLevel,
        'giType': _giType,
        'matFee': double.tryParse(_matFeeCtrl.text.trim()) ?? 0.0,
        'isRecurring': _isRecurring,
      });
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Open mat created!')));
        context.go('/owner/sessions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Open Mat')),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.lg),
        children: [
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Session Title *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: StitchTokens.md),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: StitchTokens.lg),

          // Day of week
          Text('Day of Week', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(
            spacing: 6,
            children: List.generate(7, (i) => ChoiceChip(
              label: Text(_days[i]),
              selected: _dayOfWeek == i,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() { _dayOfWeek = i; _dayLimitError = null; });
              },
            )),
          ),
          if (_dayLimitError != null) ...[
            const SizedBox(height: StitchTokens.sm),
            Text(_dayLimitError!,
                style: TextStyle(color: StitchTokens.error, fontSize: 13)),
          ],
          const SizedBox(height: StitchTokens.md),

          // Time row
          Row(
            children: [
              Expanded(child: _TimeTile(
                label: 'Start',
                time: _startTime,
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: _startTime);
                  if (t != null) setState(() => _startTime = t);
                },
              )),
              const SizedBox(width: StitchTokens.sm),
              Expanded(child: _TimeTile(
                label: 'End',
                time: _endTime,
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: _endTime);
                  if (t != null) setState(() => _endTime = t);
                },
              )),
            ],
          ),
          const SizedBox(height: StitchTokens.lg),

          // Session type
          Text('Session Type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          GiTypeSelector(
              value: _giType,
              onChanged: (v) => setState(() => _giType = v)),
          const SizedBox(height: StitchTokens.lg),

          // Experience level
          Text('Experience Level', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(
            spacing: 6,
            children: _levels.map(((key, label)) => ChoiceChip(
              label: Text(label),
              selected: _skillLevel == key,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _skillLevel = key);
              },
            )).toList(),
          ),
          const SizedBox(height: StitchTokens.lg),

          // Mat fee
          Text('Mat Fee', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          TextField(
            controller: _matFeeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount in USD (leave blank for free)',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: StitchTokens.md),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring Weekly'),
            subtitle: const Text('Repeats every week on the selected day'),
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
          ),
          const SizedBox(height: StitchTokens.xl),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _titleCtrl.text.trim().isEmpty || _isSaving
                  ? null
                  : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Open Mat'),
            ),
          ),
          const SizedBox(height: StitchTokens.lg),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: StitchTokens.md, vertical: StitchTokens.sm),
        decoration: BoxDecoration(
          border: Border.all(color: StitchTokens.divider),
          borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(_fmt(time), style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update session create route in router.dart**

Find the session create route and update it so `gymId` is read from query params:
```dart
GoRoute(
  path: 'create',
  builder: (context, state) => CreateSessionScreen(
    gymId: state.uri.queryParameters['gymId'] ?? '',
  ),
),
```

Navigate to create session from `SessionMgmtScreen` by pushing `/owner/sessions/create?gymId=<id>`.

- [ ] **Step 3: Run analyze**
```
flutter analyze
```
Expected: No issues.

- [ ] **Step 4: Commit**
```bash
git add lib/features/admin/screens/create_session_screen.dart lib/app/router.dart
git commit -m "feat: open mat creation with gi type, mat fee, 2-per-day validation"
```

---

## Task 8: Search Screen — GPS + City/ZIP/Location Query + Gi Filter

**Files:**
- Modify: `lib/features/search/screens/search_screen.dart`

- [ ] **Step 1: Replace search_screen.dart**

Replace the entire file:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../open_mats/models/open_mat.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class SearchFilters {
  final int? dayOfWeek;
  final String? skillLevel;
  final String? giType;
  final String? query;
  final double? lat;
  final double? lng;

  const SearchFilters({
    this.dayOfWeek,
    this.skillLevel,
    this.giType,
    this.query,
    this.lat,
    this.lng,
  });

  SearchFilters withSkill(String? level) => SearchFilters(
    skillLevel: level,
    giType: giType,
    query: query,
    lat: lat,
    lng: lng,
  );

  SearchFilters withGi(String? type) => SearchFilters(
    skillLevel: skillLevel,
    giType: type,
    query: query,
    lat: lat,
    lng: lng,
  );

  SearchFilters withLocation({String? q, double? lat, double? lng}) => SearchFilters(
    skillLevel: skillLevel,
    giType: giType,
    query: q,
    lat: lat,
    lng: lng,
  );
}

class _SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();
  void set(SearchFilters value) => state = value;
}

final searchFiltersProvider =
    NotifierProvider<_SearchFiltersNotifier, SearchFilters>(_SearchFiltersNotifier.new);

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final searchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);

final searchResultsProvider = FutureProvider<List<OpenMat>>((ref) async {
  final filters = ref.watch(searchFiltersProvider);
  final api = ref.read(apiClientProvider);
  final params = <String, dynamic>{'page': 1, 'limit': 30};
  if (filters.dayOfWeek != null) params['dayOfWeek'] = filters.dayOfWeek;
  if (filters.skillLevel != null) params['skillLevel'] = filters.skillLevel;
  if (filters.giType != null) params['giType'] = filters.giType;
  if (filters.query != null && filters.query!.isNotEmpty) params['q'] = filters.query;
  if (filters.lat != null) params['lat'] = filters.lat;
  if (filters.lng != null) params['lng'] = filters.lng;
  final response = await api.get(Endpoints.openMatsSearch, queryParameters: params);
  final data = response.data['data'];
  final List items = data is List
      ? data
      : (data is Map ? (data['items'] as List? ?? []) : []);
  return items.map((e) => OpenMat.fromJson(e as Map<String, dynamic>)).toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryCtrl = TextEditingController();
  bool _locating = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGPS() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      ref.read(searchFiltersProvider.notifier).set(
        ref.read(searchFiltersProvider).withLocation(
          lat: pos.latitude,
          lng: pos.longitude,
        ),
      );
      _queryCtrl.text = 'Near my location';
      ref.invalidate(searchResultsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onQuerySubmit(String value) {
    ref.read(searchFiltersProvider.notifier).set(
      ref.read(searchFiltersProvider).withLocation(q: value.trim()),
    );
    ref.invalidate(searchResultsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final filters = ref.watch(searchFiltersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Open Mats')),
      body: Column(
        children: [
          // Location search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                StitchTokens.md, 0, StitchTokens.md, StitchTokens.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      hintText: 'City, ZIP, or address...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onSubmitted: _onQuerySubmit,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: StitchTokens.sm),
                IconButton.filled(
                  tooltip: 'Use my location',
                  onPressed: _locating ? null : _useGPS,
                  icon: _locating
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: StitchTokens.md),
            child: Row(
              children: [
                // Skill level
                _Chip(label: 'All Levels', selected: filters.skillLevel == null,
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withSkill(null)); ref.invalidate(searchResultsProvider); }),
                _Chip(label: 'Beginner', selected: filters.skillLevel == 'beginner',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withSkill('beginner')); ref.invalidate(searchResultsProvider); }),
                _Chip(label: 'Intermediate', selected: filters.skillLevel == 'intermediate',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withSkill('intermediate')); ref.invalidate(searchResultsProvider); }),
                _Chip(label: 'Advanced', selected: filters.skillLevel == 'advanced',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withSkill('advanced')); ref.invalidate(searchResultsProvider); }),
                const SizedBox(width: 12),
                // Gi type
                _Chip(label: 'Gi', selected: filters.giType == 'gi',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withGi(filters.giType == 'gi' ? null : 'gi')); ref.invalidate(searchResultsProvider); }),
                _Chip(label: 'No-Gi', selected: filters.giType == 'no_gi',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withGi(filters.giType == 'no_gi' ? null : 'no_gi')); ref.invalidate(searchResultsProvider); }),
                _Chip(label: 'Gi + No-Gi', selected: filters.giType == 'both',
                    onTap: () { ref.read(searchFiltersProvider.notifier).set(filters.withGi(filters.giType == 'both' ? null : 'both')); ref.invalidate(searchResultsProvider); }),
              ],
            ),
          ),
          const SizedBox(height: StitchTokens.sm),

          // Results list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(searchResultsProvider),
              child: resultsAsync.when(
                loading: () => const ShimmerList(itemCount: 8),
                error: (e, _) => ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(searchResultsProvider)),
                data: (mats) {
                  if (mats.isEmpty) {
                    return const EmptyState(
                        title: 'No open mats found', icon: Icons.search_off);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(StitchTokens.md),
                    itemCount: mats.length,
                    itemBuilder: (context, i) {
                      final mat = mats[i];
                      final giColor = GiColors.from(mat.giType);
                      return Card(
                        margin: const EdgeInsets.only(bottom: StitchTokens.sm),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: giColor.withValues(alpha: 0.15),
                            child: Icon(Icons.sports_martial_arts, color: giColor),
                          ),
                          title: Text(mat.title),
                          subtitle: Text(
                              '${mat.gymName ?? ""} • ${mat.dayName} ${mat.startTime}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: giColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      StitchTokens.radiusPill),
                                ),
                                child: Text(mat.giBadge,
                                    style: TextStyle(
                                        color: giColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (mat.matFee != null && mat.matFee! > 0)
                                Text('\$${mat.matFee!.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.go('/open-mat/${mat.id}');
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) { HapticFeedback.selectionClick(); onTap(); },
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**
```
flutter analyze lib/features/search/screens/search_screen.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add lib/features/search/screens/search_screen.dart
git commit -m "feat: search with GPS, city/ZIP query, and gi-type filter"
```

---

## Task 9: Review Screen — Multi-Category Ratings

**Files:**
- Modify: `lib/features/checkins/screens/review_screen.dart`
- Create: `test/widget/features/reviews/review_screen_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/widget/features/reviews/review_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/checkins/screens/review_screen.dart';

void main() {
  testWidgets('ReviewScreen renders 4 category rows', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ReviewScreen(checkinId: 'test-checkin'),
      ),
    ));
    expect(find.text('Gym Quality'), findsOneWidget);
    expect(find.text('Experience Level'), findsOneWidget);
    expect(find.text('Cleanliness'), findsOneWidget);
    expect(find.text('Friendliness'), findsOneWidget);
  });

  testWidgets('Submit button disabled until at least one category rated', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ReviewScreen(checkinId: 'test-checkin'),
      ),
    ));
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**
```
flutter test test/widget/features/reviews/review_screen_test.dart
```
Expected: FAIL — category labels not found.

- [ ] **Step 3: Replace ReviewScreen**

Replace `lib/features/checkins/screens/review_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/category_rating_row.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String checkinId;
  const ReviewScreen({super.key, required this.checkinId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _gymRating = 0;
  int _experienceRating = 0;
  int _cleanlinessRating = 0;
  int _friendlinessRating = 0;
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _gymRating > 0 ||
      _experienceRating > 0 ||
      _cleanlinessRating > 0 ||
      _friendlinessRating > 0;

  int get _overallRating {
    final filled = [_gymRating, _experienceRating, _cleanlinessRating, _friendlinessRating]
        .where((r) => r > 0)
        .toList();
    if (filled.isEmpty) return 0;
    return (filled.reduce((a, b) => a + b) / filled.length).round();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.checkinReview(widget.checkinId), data: {
        'rating': _overallRating,
        'gymRating': _gymRating,
        'experienceRating': _experienceRating,
        'cleanlinessRating': _cleanlinessRating,
        'friendlinessRating': _friendlinessRating,
        'review': _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      });
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review submitted — thanks!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Session')),
      body: Padding(
        padding: const EdgeInsets.all(StitchTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was it?', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: StitchTokens.xs),
            Text(
              'Rate each category — or just the ones that stand out.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: StitchTokens.lg),

            CategoryRatingRow(
              label: 'Gym Quality',
              rating: _gymRating,
              onChanged: (v) => setState(() => _gymRating = v),
            ),
            CategoryRatingRow(
              label: 'Experience Level',
              rating: _experienceRating,
              onChanged: (v) => setState(() => _experienceRating = v),
            ),
            CategoryRatingRow(
              label: 'Cleanliness',
              rating: _cleanlinessRating,
              onChanged: (v) => setState(() => _cleanlinessRating = v),
            ),
            CategoryRatingRow(
              label: 'Friendliness',
              rating: _friendlinessRating,
              onChanged: (v) => setState(() => _friendlinessRating = v),
            ),
            const SizedBox(height: StitchTokens.lg),
            const Divider(),
            const SizedBox(height: StitchTokens.md),

            Text('Comments (optional)',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: StitchTokens.sm),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'How was the vibe? Good rolls? Anything to note?',
              ),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Review'),
              ),
            ),
            const SizedBox(height: StitchTokens.md),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**
```
flutter test test/widget/features/reviews/review_screen_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run full analyze**
```
flutter analyze
```
Expected: No issues.

- [ ] **Step 6: Commit**
```bash
git add lib/features/checkins/screens/review_screen.dart test/widget/features/reviews/
git commit -m "feat: multi-category review screen (gym quality, experience, cleanliness, friendliness)"
```

---

## Task 10: Gym Model — Add Rating Fields

**Files:**
- Modify: `lib/features/gyms/models/gym.dart`

- [ ] **Step 1: Add `averageRating` and `reviewCount` to Gym**

In `lib/features/gyms/models/gym.dart`, add to the `Gym` class fields (after `distanceKm`):
```dart
  final double? averageRating;
  final int? reviewCount;
```

Add to constructor (after `distanceKm`):
```dart
    this.averageRating,
    this.reviewCount,
```

Add to `Gym.fromJson` (after `distanceKm` parse):
```dart
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
```

- [ ] **Step 2: Run analyze**
```
flutter analyze lib/features/gyms/models/gym.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add lib/features/gyms/models/gym.dart
git commit -m "feat: add averageRating and reviewCount to Gym model"
```

---

## Task 11: Gym Detail — Weekly Schedule + Ratings Summary

**Files:**
- Modify: `lib/features/gyms/screens/gym_detail_screen.dart`

- [ ] **Step 1: Add open mat schedule provider**

At the top of `lib/features/gyms/screens/gym_detail_screen.dart`, add a provider that loads sessions for a gym:

```dart
final gymScheduleProvider =
    FutureProvider.family<List<OpenMat>, String>((ref, gymId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.openMatsByGym(gymId));
  final data = response.data['data'];
  final List items = data is List
      ? data
      : (data is Map ? (data['items'] as List? ?? []) : []);
  return items.map((e) => OpenMat.fromJson(e as Map<String, dynamic>)).toList();
});
```

Add import at top:
```dart
import '../../open_mats/models/open_mat.dart';
```

- [ ] **Step 2: Add `_RatingSummary` and `_ScheduleTable` widgets at bottom of the file**

```dart
class _RatingSummary extends StatelessWidget {
  final double? avg;
  final int? count;
  const _RatingSummary({this.avg, this.count});

  @override
  Widget build(BuildContext context) {
    if (avg == null || count == null || count == 0) {
      return const Text('No reviews yet',
          style: TextStyle(color: StitchTokens.textSecondary));
    }
    return Row(
      children: [
        Icon(Icons.star, color: StitchTokens.warning, size: StitchTokens.iconMd),
        const SizedBox(width: 4),
        Text(avg!.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(width: 4),
        Text('($count reviews)',
            style: const TextStyle(color: StitchTokens.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  final List<OpenMat> sessions;
  const _ScheduleTable({required this.sessions});

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Text('No open mats scheduled yet.',
          style: TextStyle(color: StitchTokens.textSecondary));
    }
    final byDay = <int, List<OpenMat>>{};
    for (final s in sessions) {
      if (s.dayOfWeek != null) {
        byDay.putIfAbsent(s.dayOfWeek!, () => []).add(s);
      }
    }
    return Column(
      children: _days.asMap().entries
          .where((e) => byDay.containsKey(e.key))
          .map((e) {
        final day = e.key;
        final daySessions = byDay[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_days[day],
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: StitchTokens.textSecondary)),
            ...daySessions.map((s) {
              final giColor = GiColors.from(s.giType);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: giColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('${s.startTime} – ${s.endTime}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: giColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(StitchTokens.radiusPill),
                      ),
                      child: Text(s.giBadge,
                          style: TextStyle(
                              color: giColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (s.matFee != null && s.matFee! > 0) ...[
                      const SizedBox(width: 8),
                      Text('\$${s.matFee!.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const Spacer(),
                    Text(s.skillBadge,
                        style: const TextStyle(
                            color: StitchTokens.textSecondary, fontSize: 12)),
                  ],
                ),
              );
            }),
            const SizedBox(height: StitchTokens.sm),
          ],
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 3: Add schedule + rating sections to GymDetailScreen build**

In `GymDetailScreen.build`, inside the `SliverList` delegate after the directions buttons, add:

```dart
// Rating summary
const SizedBox(height: StitchTokens.lg),
Text('Rating', style: Theme.of(context).textTheme.headlineMedium),
const SizedBox(height: StitchTokens.sm),
_RatingSummary(avg: gym.averageRating, count: gym.reviewCount),
const SizedBox(height: StitchTokens.lg),

// Weekly schedule
Text('Open Mat Schedule',
    style: Theme.of(context).textTheme.headlineMedium),
const SizedBox(height: StitchTokens.sm),
Consumer(builder: (context, ref, _) {
  final schedAsync = ref.watch(gymScheduleProvider(gymId));
  return schedAsync.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, __) => const Text('Could not load schedule'),
    data: (sessions) => _ScheduleTable(sessions: sessions),
  );
}),
```

- [ ] **Step 4: Run analyze**
```
flutter analyze lib/features/gyms/screens/gym_detail_screen.dart
```
Expected: No issues.

- [ ] **Step 5: Run full test suite**
```
flutter test
```
Expected: All tests pass.

- [ ] **Step 6: Commit**
```bash
git add lib/features/gyms/screens/gym_detail_screen.dart lib/features/gyms/models/gym.dart
git commit -m "feat: gym detail shows weekly open mat schedule and ratings summary"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All requested features covered — gym creation ✓, address validation ✓, open mat schedule ✓, gi/no-gi/both ✓, experience level ✓, mat fees ✓, 2/day limit ✓, GPS search ✓, city/ZIP search ✓, ratings by category ✓
- [x] **No placeholders:** All code blocks are complete
- [x] **Type consistency:** `giType` string ('gi'|'no_gi'|'both') used consistently across model, widgets, form, and search. `GiColors.from(giType)` used in Tasks 2, 8, 11. `CategoryRatingRow` defined in Task 4, used in Task 9
- [x] **Health endpoint:** `/healthz` → `/health` fixed in Task 1
- [x] **Task ordering:** Widgets (Task 4) defined before screens that use them (Tasks 7, 9, 11)
