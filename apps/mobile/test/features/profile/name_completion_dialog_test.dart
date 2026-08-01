import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/profile/widgets/name_completion_dialog.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  final List<Map<String, dynamic>> updateCalls = [];

  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(id: 'u1', email: 'a@b.io', displayName: ''),
      );

  @override
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    updateCalls.add(updates);
    state = state.copyWith(
      user: UserProfile(
        id: 'u1',
        email: 'a@b.io',
        displayName: '${updates['firstName'] ?? ''} ${updates['lastName'] ?? ''}'.trim(),
        firstName: updates['firstName'] as String?,
        lastName: updates['lastName'] as String?,
      ),
    );
  }
}

/// Pumps a simple scaffold that immediately shows the completion dialog.
Future<_FakeAuthNotifier> _pumpDialog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final notifier = _FakeAuthNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authStateProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showNameCompletionDialog(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  // Open the dialog
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('dialog renders title and both name fields', (tester) async {
    await _pumpDialog(tester);

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'First name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Last name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('tapping Skip dismisses without calling updateProfile', (tester) async {
    final notifier = await _pumpDialog(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(notifier.updateCalls, isEmpty);
    expect(find.text('Complete your profile'), findsNothing);
  });

  testWidgets('tapping Save with filled fields calls updateProfile with firstName and lastName', (tester) async {
    final notifier = await _pumpDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Jordan');
    await tester.enterText(find.widgetWithText(TextField, 'Last name'), 'Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updateCalls, hasLength(1));
    expect(notifier.updateCalls.first['firstName'], 'Jordan');
    expect(notifier.updateCalls.first['lastName'], 'Smith');
    expect(find.text('Complete your profile'), findsNothing);
  });

  testWidgets('tapping Save with only first name sends only firstName', (tester) async {
    final notifier = await _pumpDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Jordan');
    // last name left blank
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updateCalls, hasLength(1));
    expect(notifier.updateCalls.first['firstName'], 'Jordan');
    expect(notifier.updateCalls.first.containsKey('lastName'), isFalse);
  });

  testWidgets('tapping Save with both fields empty dismisses without calling updateProfile', (tester) async {
    final notifier = await _pumpDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.updateCalls, isEmpty);
    expect(find.text('Complete your profile'), findsNothing);
  });
}
