import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/profile/screens/edit_profile_screen.dart';

// A social (Google) user: sub contains '|' and is not auth0|… -> isSocial true.
class _SocialAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(id: 'google-oauth2|1', email: 'g@x.io', displayName: 'Google User'),
      );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('social users can edit belt, training, and location fields', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith(_SocialAuthNotifier.new)],
      child: MaterialApp(theme: AppTheme.glass(), home: const EditProfileScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // Previously hidden for social users — regression guard.
    // (glassSectionLabel renders field labels upper-cased.)
    expect(find.text('BIO'), findsOneWidget);
    expect(find.text('CITY'), findsOneWidget);
    expect(find.text('GENDER'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.text('BELT RANK'), findsOneWidget);

    // Display name stays provider-owned for social users.
    expect(find.text('DISPLAY NAME'), findsNothing);
  });
}
