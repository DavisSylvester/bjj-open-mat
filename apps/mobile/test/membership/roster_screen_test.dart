import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
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
          rosterProvider('g1')
              .overrideWith((ref) async => [adminMember, _member]),
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
}
