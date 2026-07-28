import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/screens/roster_screen.dart';

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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
}
