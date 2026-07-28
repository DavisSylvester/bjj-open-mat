import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/belt_promotion.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ---------------------------------------------------------------------------
// Fake MembershipRepository that records join/leave calls.
// ---------------------------------------------------------------------------
class _FakeMembershipRepo implements MembershipRepository {
  final List<String> joinCalls = [];
  final List<String> leaveCalls = [];

  @override
  Future<GymMembership> join(String gymId) async {
    joinCalls.add(gymId);
    return GymMembership(
      id: 'mem1',
      gymId: gymId,
      userId: 'user-1',
      status: 'active',
      verifiedMember: false,
      gymRole: 'member',
      isHome: false,
      visibleInRoster: true,
      joinMethod: 'self',
      joinedAt: '2026-01-01T00:00:00.000Z',
    );
  }

  @override
  Future<void> leave(String gymId) async {
    leaveCalls.add(gymId);
  }

  @override
  Future<List<RosterMember>> roster(String gymId) async => [];

  @override
  Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome}) async =>
      throw UnimplementedError();

  @override
  Future<GymMembership> manageMember(String gymId, String userId,
          {bool? verifiedMember, String? gymRole}) async =>
      throw UnimplementedError();

  @override
  Future<BeltPromotion> promote(String gymId, String userId,
          {required String beltRank, required int beltStripes, String? note}) async =>
      throw UnimplementedError();

  @override
  Future<List<BeltPromotion>> userPromotions(String userId) async => [];

  @override
  Future<List<GymMembership>> myMemberships() async => [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
RosterMember _member(String userId) => RosterMember(
      userId: userId,
      name: 'Test User',
      gymRole: 'member',
      verifiedMember: true,
      hasProfile: true,
    );

Future<void> _pump(
  WidgetTester tester, {
  required _FakeMembershipRepo repo,
  required List<RosterMember> roster,
  String? currentUserId = 'user-1',
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        membershipRepositoryProvider.overrideWithValue(repo),
        rosterProvider('g1').overrideWith((_) async => roster),
        // Override the injectable currentUserIdProvider so no AuthStateNotifier
        // (and no AuthService / Dio / FlutterSecureStorage) is needed in tests.
        currentUserIdProvider.overrideWithValue(currentUserId),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const Scaffold(
          body: Center(child: JoinGymButton(gymId: 'g1')),
        ),
      ),
    ),
  );
  // Let the FutureProvider resolve.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('JoinGymButton — not a member', () {
    testWidgets('shows Join button when user is not in roster', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: []);

      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('tapping Join calls repo.join with the gym id', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: []);

      await tester.tap(find.text('Join'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.joinCalls, contains('g1'));
    });

    testWidgets('shows member count label (0 members)', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: []);

      expect(find.textContaining('member'), findsWidgets);
    });
  });

  group('JoinGymButton — already a member', () {
    testWidgets('shows Leave button when user is in roster', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: [_member('user-1')]);

      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('tapping Leave calls repo.leave with the gym id', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: [_member('user-1')]);

      await tester.tap(find.text('Leave'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.leaveCalls, contains('g1'));
    });

    testWidgets('shows member count label (1 member)', (tester) async {
      final repo = _FakeMembershipRepo();
      await _pump(tester, repo: repo, roster: [_member('user-1')]);

      expect(find.textContaining('member'), findsWidgets);
    });
  });

  group('JoinGymButton — unauthenticated', () {
    testWidgets('Join button is disabled when not authenticated', (tester) async {
      final repo = _FakeMembershipRepo();
      // Pass null for currentUserId to simulate an unauthenticated user.
      await _pump(tester, repo: repo, roster: [], currentUserId: null);

      // Button should be visible but disabled (onPressed == null).
      final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Join'));
      expect(btn.onPressed, isNull);
    });
  });
}
