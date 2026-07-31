import 'dart:async';
import 'dart:typed_data';

import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/design/tokens.dart';
import 'package:bjj_open_mat/features/admin/screens/gym_admin_screen.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_requests.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/gyms/widgets/gym_logo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// A controllable fake so tests can (a) assert the exact request sent to
/// `update` and (b) hold an upload open to observe the Save button's state
/// while `_uploadingLogo` is true.
class _FakeGymRepository implements GymRepository {
  _FakeGymRepository(this._gym);

  Gym _gym;
  int updateCalls = 0;
  Map<String, dynamic>? lastUpdateFields;
  Completer<String>? uploadCompleter;
  String uploadResult = 'https://cdn/logo.jpg';

  @override
  Future<Gym> getById(String id) async => _gym;

  @override
  Future<Gym> update(String id, UpdateGymRequest req) async {
    updateCalls += 1;
    final fields = req.toJson();
    lastUpdateFields = fields;
    _gym = Gym(
      id: _gym.id,
      ownerId: _gym.ownerId,
      name: (fields['name'] as String?) ?? _gym.name,
      address: (fields['address'] as String?) ?? _gym.address,
      logoUrl: fields.containsKey('logoUrl') ? fields['logoUrl'] as String? : _gym.logoUrl,
    );
    return _gym;
  }

  @override
  Future<String> uploadLogo(Uint8List bytes, String contentType) {
    final completer = uploadCompleter;
    if (completer != null) return completer.future;
    return Future.value(uploadResult);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<_FakeGymRepository> _pump(WidgetTester tester, _FakeGymRepository repo, String gymId) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gymRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: GymAdminScreen(gymId: gymId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('gym admin screen embeds the shared logo picker', (tester) async {
    final repo = _FakeGymRepository(const Gym(id: 'g1', ownerId: 'u1', name: 'Test Gym', address: '123 St'));
    await _pump(tester, repo, 'g1');
    expect(find.byType(GymLogoPicker), findsOneWidget,
        reason: 'an existing gym has no other way to get a logo');
  });

  testWidgets('a successful logo upload is persisted immediately, without tapping Save', (tester) async {
    final repo = _FakeGymRepository(const Gym(id: 'g1', ownerId: 'u1', name: 'Test Gym', address: '123 St'))
      ..uploadResult = 'https://cdn/new-logo.jpg';
    await _pump(tester, repo, 'g1');

    final pickerState = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await pickerState.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1,
        reason: 'the admin screen must persist the logo as soon as it uploads, not wait for a manual Save '
            '— otherwise a user who leaves after seeing the "Logo added" badge silently loses it');
    expect(repo.lastUpdateFields?['logoUrl'], 'https://cdn/new-logo.jpg');
  });

  testWidgets('Save Changes is disabled (no tap, muted color) while a logo upload is in flight', (tester) async {
    final gym = const Gym(id: 'g1', ownerId: 'u1', name: 'Test Gym', address: '123 St');
    final completer = Completer<String>();
    final repo = _FakeGymRepository(gym)..uploadCompleter = completer;
    await _pump(tester, repo, 'g1');

    final t = AppTheme.glass().extension<AppTokens>()!;

    final pickerState = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    unawaited(pickerState.uploadBytes(Uint8List.fromList([1, 2, 3])));
    await tester.pump(); // upload starts; _uploadingLogo becomes true, upload itself stays pending

    final gestureDetector = tester.widget<GestureDetector>(
      find.ancestor(of: find.text('Save Changes'), matching: find.byType(GestureDetector)).first,
    );
    expect(gestureDetector.onTap, isNull,
        reason: 'tapping Save mid-upload must be visibly disabled, not a silent no-op');

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Save Changes'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, t.border,
        reason: 'the button must render in its disabled (muted) color while _uploadingLogo is true');

    // Let the upload resolve so the pending future doesn't leak into the next test.
    completer.complete('https://cdn/logo.jpg');
    await tester.pumpAndSettle();
  });

  testWidgets('Save Changes is enabled again once the upload completes', (tester) async {
    final gym = const Gym(id: 'g1', ownerId: 'u1', name: 'Test Gym', address: '123 St');
    final repo = _FakeGymRepository(gym)..uploadResult = 'https://cdn/logo.jpg';
    await _pump(tester, repo, 'g1');

    final t = AppTheme.glass().extension<AppTokens>()!;

    final pickerState = tester.state<GymLogoPickerState>(find.byType(GymLogoPicker));
    await pickerState.uploadBytes(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Save Changes'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, t.gi);
  });

  testWidgets('back arrow pops when the route stack can pop', (tester) async {
    final repo = _FakeGymRepository(const Gym(id: 'g1', ownerId: 'u1', name: 'Test Gym', address: '123 St'));

    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => ctx.push('/admin/g1'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/admin/g1',
          builder: (context, state) => ProviderScope(
            overrides: [gymRepositoryProvider.overrideWithValue(repo)],
            child: const GymAdminScreen(gymId: 'g1'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.glass(),
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    // Navigate to the admin screen so the stack has a previous route (canPop == true).
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // Confirm we are on the admin screen.
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

    // Tap the back arrow — it should pop back to /start, not hard-navigate.
    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();

    // After popping, the "go" button on /start should be visible again.
    expect(find.text('go'), findsOneWidget,
        reason: 'back arrow must pop to the previous route when canPop is true');
  });
}
