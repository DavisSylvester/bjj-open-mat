import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/onboarding/screens/login_screen.dart';

// Unauthenticated state so LoginScreen renders without triggering navigation
// (the ref.listen redirect only fires on AuthStatus.authenticated).
class _UnauthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  testWidgets('login screen shows Google, Apple, Facebook, Amazon, Microsoft, email', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith(_UnauthNotifier.new)],
      child: MaterialApp(theme: AppTheme.glass(), home: const LoginScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Amazon'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });
}
