import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/belt_promotion.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/promote_belt_sheet.dart';

// ---------------------------------------------------------------------------
// Fake MembershipRepository that records promote / manageMember calls.
// ---------------------------------------------------------------------------
class _FakeMembershipRepo implements MembershipRepository {
  final List<Map<String, dynamic>> promoteCalls = [];
  final List<Map<String, dynamic>> manageCalls = [];

  @override
  Future<BeltPromotion> promote(
    String gymId,
    String userId, {
    required String beltRank,
    required int beltStripes,
    String? note,
  }) async {
    promoteCalls.add({
      'gymId': gymId,
      'userId': userId,
      'beltRank': beltRank,
      'beltStripes': beltStripes,
      'note': note,
    });
    return BeltPromotion(
      id: 'promo-1',
      userId: userId,
      gymId: gymId,
      beltRank: beltRank,
      beltStripes: beltStripes,
      promotedByUserId: 'owner-1',
      promotedAt: '2026-07-27T00:00:00.000Z',
    );
  }

  @override
  Future<GymMembership> manageMember(
    String gymId,
    String userId, {
    bool? verifiedMember,
    String? gymRole,
    String? status,
  }) async {
    manageCalls.add({
      'gymId': gymId,
      'userId': userId,
      'verifiedMember': verifiedMember,
      'gymRole': gymRole,
      'status': status,
    });
    return GymMembership(
      id: 'mem-1',
      gymId: gymId,
      userId: userId,
      status: status ?? 'active',
      verifiedMember: verifiedMember ?? false,
      gymRole: gymRole ?? 'member',
      isHome: false,
      visibleInRoster: true,
      joinMethod: 'self',
      joinedAt: '2026-01-01T00:00:00.000Z',
    );
  }

  @override
  Future<GymMembership> join(String gymId) async => throw UnimplementedError();

  @override
  Future<void> leave(String gymId) async => throw UnimplementedError();

  @override
  Future<List<RosterMember>> roster(String gymId) async => [];

  @override
  Future<List<RosterMember>> manageRoster(String gymId) async => [];

  @override
  Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome}) async =>
      throw UnimplementedError();

  @override
  Future<List<BeltPromotion>> userPromotions(String userId) async => [];

  @override
  Future<List<GymMembership>> myMemberships() async => [];
}

// ---------------------------------------------------------------------------
// Helper to pump the sheet inside a Scaffold (bottom sheet host).
// ---------------------------------------------------------------------------
Future<_FakeMembershipRepo> _pumpSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeMembershipRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(repo),
        rosterProvider('g1').overrideWith((_) async => []),
        userPromotionsProvider('u2').overrideWith((_) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => const PromoteBeltSheet(gymId: 'g1', targetUserId: 'u2'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  // Open the sheet.
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return repo;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows belt dropdown and stripes selector', (tester) async {
    await _pumpSheet(tester);

    // Belt dropdown should be present.
    expect(find.text('Belt'), findsOneWidget);
    // Stripes label should be visible.
    expect(find.textContaining('Stripes'), findsOneWidget);
    // Confirm button.
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('select blue belt and 2 stripes, tap Confirm — promote called correctly',
      (tester) async {
    final repo = await _pumpSheet(tester);

    // Open the belt dropdown.
    await tester.tap(find.text('white')); // default selection
    await tester.pumpAndSettle();

    // Choose 'blue'.
    await tester.tap(find.text('blue').last);
    await tester.pumpAndSettle();

    // Increment stripes to 2 by tapping the + button twice.
    final plusBtn = find.byIcon(Icons.add);
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();

    // Tap Confirm.
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repo.promoteCalls, hasLength(1));
    expect(repo.promoteCalls.first['beltRank'], equals('blue'));
    expect(repo.promoteCalls.first['beltStripes'], equals(2));
  });

  testWidgets('stripes selector cannot exceed 4', (tester) async {
    await _pumpSheet(tester);

    final plusBtn = find.byIcon(Icons.add);

    // Tap + five times — should cap at 4.
    for (var i = 0; i < 5; i++) {
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();
    }

    // Find the stripes count display — should show '4'.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('stripes cannot go below 0', (tester) async {
    await _pumpSheet(tester);

    final minusBtn = find.byIcon(Icons.remove);

    // Tapping minus when already 0 — should stay at 0.
    await tester.tap(minusBtn);
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
  });
}
