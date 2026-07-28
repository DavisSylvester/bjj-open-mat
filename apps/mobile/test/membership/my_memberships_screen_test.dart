import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/belt_promotion.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/screens/my_memberships_screen.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kGymAId = 'gA';
const _kGymBId = 'gB';

final _membershipA = GymMembership(
  id: 'm1',
  gymId: _kGymAId,
  userId: 'u1',
  status: 'active',
  verifiedMember: true,
  gymRole: 'member',
  isHome: true,
  visibleInRoster: false,
  joinMethod: 'manual',
  joinedAt: '2024-01-01T00:00:00Z',
);

final _membershipB = GymMembership(
  id: 'm2',
  gymId: _kGymBId,
  userId: 'u1',
  status: 'active',
  verifiedMember: false,
  gymRole: 'member',
  isHome: false,
  visibleInRoster: true,
  joinMethod: 'manual',
  joinedAt: '2024-02-01T00:00:00Z',
);

const _gymA = Gym(id: _kGymAId, name: 'Alpha Gym', address: '1 Main St');
const _gymB = Gym(id: _kGymBId, name: 'Beta Academy', address: '2 Side Ave');

// ── Fake MembershipRepository ─────────────────────────────────────────────────

class _FakeMembershipRepository implements MembershipRepository {
  final List<String> updateCalls = [];

  @override
  Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome}) async {
    final suffix = visibleInRoster != null
        ? 'visibleInRoster:$visibleInRoster'
        : 'isHome:$isHome';
    updateCalls.add('$gymId.$suffix');
    // Return the unmodified membership (invalidation drives the reload in prod).
    return _membershipB;
  }

  @override
  Future<GymMembership> join(String gymId) async => _membershipB;

  @override
  Future<void> leave(String gymId) async {}

  @override
  Future<List<RosterMember>> roster(String gymId) async => [];

  @override
  Future<GymMembership> manageMember(String gymId, String userId, {bool? verifiedMember, String? gymRole}) async =>
      _membershipB;

  @override
  Future<BeltPromotion> promote(String gymId, String userId, {required String beltRank, required int beltStripes, String? note}) async =>
      throw UnimplementedError();

  @override
  Future<List<BeltPromotion>> userPromotions(String userId) async => [];

  @override
  Future<List<GymMembership>> myMemberships() async => [_membershipA, _membershipB];
}

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<_FakeMembershipRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeRepo = _FakeMembershipRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(fakeRepo),
        myMembershipsProvider.overrideWith((_) async => [_membershipA, _membershipB]),
        gymByIdProvider(_kGymAId).overrideWith((_) async => _gymA),
        gymByIdProvider(_kGymBId).overrideWith((_) async => _gymB),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const MyMembershipsScreen(),
      ),
    ),
  );

  // Let the FutureProviders resolve.
  await tester.pump();
  await tester.pump();

  return fakeRepo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders both gym names', (tester) async {
    await _pump(tester);
    expect(find.text('Alpha Gym'), findsOneWidget);
    expect(find.text('Beta Academy'), findsOneWidget);
  });

  testWidgets('shows Home gym badge for isHome membership', (tester) async {
    await _pump(tester);
    expect(find.text('Home gym'), findsOneWidget);
  });

  testWidgets('shows Verified chip for verifiedMember membership', (tester) async {
    await _pump(tester);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('roster switch reflects visibleInRoster state', (tester) async {
    await _pump(tester);
    // gymA: visibleInRoster=false → switch should be OFF
    final switchA = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('roster-switch-$_kGymAId')),
        matching: find.byType(Switch),
      ),
    );
    expect(switchA.value, isFalse);

    // gymB: visibleInRoster=true → switch should be ON
    final switchB = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('roster-switch-$_kGymBId')),
        matching: find.byType(Switch),
      ),
    );
    expect(switchB.value, isTrue);
  });

  testWidgets('toggling roster switch on gymB calls updateMine with visibleInRoster:false', (tester) async {
    final fakeRepo = await _pump(tester);

    // Tap the switch for gymB (currently ON → toggle to OFF).
    await tester.tap(find.byKey(const Key('roster-switch-$_kGymBId')));
    await tester.pump();

    expect(fakeRepo.updateCalls, contains('$_kGymBId.visibleInRoster:false'));
  });

  testWidgets('tapping Set home on gymB calls updateMine with isHome:true', (tester) async {
    final fakeRepo = await _pump(tester);

    await tester.tap(find.byKey(const Key('set-home-$_kGymBId')));
    await tester.pump();

    expect(fakeRepo.updateCalls, contains('$_kGymBId.isHome:true'));
  });
}
