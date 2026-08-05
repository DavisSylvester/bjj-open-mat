import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/gym_membership.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/screens/roster_screen.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Auth stubs ────────────────────────────────────────────────────────────────

/// Returns an unauthenticated / no-user state so the roster does not try to
/// look up a user profile (avoids touching the real AuthStateNotifier).
class _NoUserNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// Returns an authenticated state where the user has the global 'admin' role.
class _AdminUserNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(
          id: 'admin-user',
          email: 'admin@test.com',
          displayName: 'Site Admin',
          role: 'admin',
        ),
      );
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// A stub gym with no ownerId so the base tests are not affected by the
/// gym-owner arm of canManage.
final _stubGym = Gym(
  id: 'g1',
  ownerId: null,
  name: 'Test Gym',
  address: '123 Main St',
);

final _coach = RosterMember(
  userId: 'u1',
  name: 'Coach Rivera',
  beltRank: 'black',
  beltStripes: 3,
  verifiedBeltRank: 'black',
  verifiedBeltStripes: 3,
  gymRole: 'coach',
  verifiedMember: true,
  hasProfile: true,
);

final _member = RosterMember(
  userId: 'u2',
  name: 'Jane Doe',
  beltRank: 'blue',
  beltStripes: 2,
  gymRole: 'member',
  verifiedMember: false,
  hasProfile: false,
);

/// Pumps the RosterScreen as an unauthenticated viewer (no manage affordance).
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_NoUserNotifier.new),
        currentUserIdProvider.overrideWith((ref) => null),
        rosterProvider('g1').overrideWith(
          (ref) async => [_coach, _member],
        ),
        gymByIdProvider('g1').overrideWith((ref) async => _stubGym),
        // Unauthenticated viewer: no self-membership, so canManage stays
        // false and the screen watches rosterProvider (not manageRoster).
        myMembershipsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const RosterScreen(gymId: 'g1'),
      ),
    ),
  );
  // Allow the FutureProvider to resolve.
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders both member names', (tester) async {
    await _pump(tester);
    expect(find.text('Coach Rivera'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('shows Coach chip for coach role', (tester) async {
    await _pump(tester);
    expect(find.text('Coach'), findsOneWidget);
  });

  testWidgets('does not show role chip for plain member', (tester) async {
    await _pump(tester);
    expect(find.text('Member'), findsNothing);
    expect(find.text('Owner'), findsNothing);
  });

  testWidgets('shows verified belt badge for verified belt rank', (tester) async {
    await _pump(tester);
    // The ✓ badge is rendered as a Text widget when verifiedBeltRank is set.
    expect(find.text('✓'), findsOneWidget);
  });

  // ── Admin gate tests ────────────────────────────────────────────────────────

  testWidgets(
      'global admin sees manage affordance even with plain member gymRole',
      (tester) async {
    // The admin user is on the roster as a plain 'member' (not coach/owner).
    // Without the admin arm in canManage they would see no manage icons.
    final adminMember = RosterMember(
      userId: 'admin-user',
      name: 'Site Admin',
      beltRank: 'white',
      beltStripes: 0,
      gymRole: 'member',
      verifiedMember: true,
      hasProfile: true,
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_AdminUserNotifier.new),
          currentUserIdProvider.overrideWith((ref) => 'admin-user'),
          // canManage is true via the isAdmin arm, so the screen watches
          // manageRosterProvider rather than rosterProvider.
          manageRosterProvider('g1')
              .overrideWith((ref) async => [adminMember, _member]),
          gymByIdProvider('g1').overrideWith((ref) async => _stubGym),
          myMembershipsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const RosterScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The promote-belt icon (military_tech) is the always-shown manage affordance.
    expect(find.byIcon(Icons.military_tech), findsWidgets);
  });

  testWidgets('plain non-admin member does NOT see manage affordance',
      (tester) async {
    // Current user is on the roster as 'member' with no admin role.
    // _NoUserNotifier returns unauthenticated (role == null); currentUserId is
    // 'u2' which maps to _member whose gymRole is 'member' — not coach/owner.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_NoUserNotifier.new),
          currentUserIdProvider.overrideWith((ref) => 'u2'),
          rosterProvider('g1').overrideWith(
            (ref) async => [_coach, _member],
          ),
          gymByIdProvider('g1').overrideWith((ref) async => _stubGym),
          // Own membership is a plain 'member' on an active row — not
          // coach/owner — so canManage stays false and the screen keeps
          // watching rosterProvider (matching the override above).
          myMembershipsProvider.overrideWith(
            (ref) async => const [
              GymMembership(
                id: 'm2',
                gymId: 'g1',
                userId: 'u2',
                status: 'active',
                verifiedMember: false,
                gymRole: 'member',
                isHome: false,
                visibleInRoster: true,
                joinMethod: 'manual',
                joinedAt: '2024-01-01T00:00:00.000Z',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const RosterScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // No manage icons should be present for a plain member.
    expect(find.byIcon(Icons.military_tech), findsNothing);
    expect(find.byIcon(Icons.verified_user), findsNothing);
    expect(find.byIcon(Icons.sports_martial_arts), findsNothing);
  });

  testWidgets(
      'gym owner via ownerId sees manage affordance even as plain member gymRole',
      (tester) async {
    // The current user ('owner-user') is on the roster as a plain 'member'
    // and has no global admin role, but gym 'g1' has ownerId == 'owner-user'.
    // The fix in roster_screen.dart watches gymByIdProvider and grants
    // canManage=true via the isOwner arm.
    const ownerUserId = 'owner-user';

    final ownerMember = RosterMember(
      userId: ownerUserId,
      name: 'Gym Owner',
      beltRank: 'purple',
      beltStripes: 0,
      gymRole: 'member',
      verifiedMember: true,
      hasProfile: true,
    );

    final gym = Gym(
      id: 'g1',
      ownerId: ownerUserId,
      name: 'Test Gym',
      address: '123 Main St',
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_NoUserNotifier.new),
          currentUserIdProvider.overrideWith((ref) => ownerUserId),
          // canManage is true via the isOwner arm (gym.ownerId == myId). The
          // screen now waits for gymByIdProvider and myMembershipsProvider to
          // settle before picking a roster provider at all, so it goes
          // straight to manageRosterProvider and never touches
          // rosterProvider — deliberately NOT overridden here; if the screen
          // regressed to watching it transiently, this test would hit the
          // real (unstubbed) provider and fail.
          manageRosterProvider('g1').overrideWith(
            (ref) async => [ownerMember, _member],
          ),
          gymByIdProvider('g1').overrideWith((ref) async => gym),
          // No membership row needed — the isOwner arm grants canManage
          // without myMembershipsProvider containing an entry for this gym.
          myMembershipsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const RosterScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The promote-belt icon is the always-visible manage affordance; it must
    // appear because the user owns the gym via ownerId even though their
    // RosterMember.gymRole is only 'member'.
    expect(find.byIcon(Icons.military_tech), findsWidgets);
  });

  testWidgets(
      'logged-out viewer gets the public roster immediately, without waiting on myMembershipsProvider',
      (tester) async {
    // Regression guard: myMembershipsProvider is auth-only (401 for a
    // logged-out caller). If the screen ever waited on it before deciding
    // which roster to request, an anonymous visitor's roster would hang or
    // error. Deliberately never resolve myMembershipsProvider or
    // gymByIdProvider here — if the screen's canManage logic regressed to
    // waiting on them regardless of whether there's a current user, this
    // test would hang on a spinner forever instead of rendering the roster
    // after two pumps, and the icon assertions below would fail.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_NoUserNotifier.new),
          currentUserIdProvider.overrideWith((ref) => null),
          rosterProvider('g1').overrideWith(
            (ref) async => [_coach, _member],
          ),
          // Never resolves — proves the screen doesn't wait on it for an
          // anonymous viewer.
          gymByIdProvider('g1').overrideWith((ref) => Completer<Gym>().future),
          myMembershipsProvider.overrideWith((ref) => Completer<List<GymMembership>>().future),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const RosterScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The public roster renders — no manage affordance, no hang.
    expect(find.text('Coach Rivera'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byIcon(Icons.military_tech), findsNothing);
  });

  testWidgets(
      'manageRosterProvider error falls back to the public roster instead of the error state',
      (tester) async {
    // A demoted coach can carry a stale myMembershipsProvider for the
    // session: the client derives canManage == true, but the server (which
    // resolves the role fresh via roleLookup) returns 403. Before this fix
    // the screen rendered "Couldn't load roster" with no members at all;
    // now it must fall back to the public roster.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_NoUserNotifier.new),
          currentUserIdProvider.overrideWith((ref) => 'u1'),
          // canManage resolves true locally (coach gymRole on an active
          // membership) so the screen requests manageRosterProvider first.
          manageRosterProvider('g1').overrideWith(
            (ref) async => Future<List<RosterMember>>.error(
              Exception('403 forbidden'),
            ),
          ),
          rosterProvider('g1').overrideWith(
            (ref) async => [_coach, _member],
          ),
          gymByIdProvider('g1').overrideWith((ref) async => _stubGym),
          myMembershipsProvider.overrideWith(
            (ref) async => const [
              GymMembership(
                id: 'm1',
                gymId: 'g1',
                userId: 'u1',
                status: 'active',
                verifiedMember: true,
                gymRole: 'coach',
                isHome: false,
                visibleInRoster: true,
                joinMethod: 'manual',
                joinedAt: '2024-01-01T00:00:00.000Z',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.glass(),
          home: const RosterScreen(gymId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // The public roster's members render — no "Couldn't load roster" error.
    expect(find.text('Coach Rivera'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text("Couldn't load roster"), findsNothing);
  });
}
