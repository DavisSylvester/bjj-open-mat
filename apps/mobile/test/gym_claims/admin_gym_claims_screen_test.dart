import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/screens/admin_gym_claims_screen.dart';

class _AdminAuth extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserProfile(id: 'admin1', email: 'a@b.c', displayName: 'Admin', role: 'admin'),
  );
}

class _FakeRepo implements GymClaimRepository {
  final List<String> approvals = [];
  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async => [
    AdminGymClaim(
      claim: const GymClaim(id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner', contact: 'me@gym.com', message: 'mine', status: 'pending'),
      gymName: 'Alliance', gymPhone: '555-1212', claimantEmail: 'me@gym.com',
    ),
  ];
  @override
  Future<void> approve(String claimId) async => approvals.add(claimId);
  @override
  Future<void> reject(String claimId, {String? note}) async {}
  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async => throw UnimplementedError();
  @override
  Future<GymClaim?> myClaimForGym(String gymId) async => null;
  @override
  Future<void> withdraw(String gymId) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gymClaimRepositoryProvider.overrideWithValue(repo),
        adminGymClaimsProvider('pending').overrideWith((_) async => repo.adminList()),
        authStateProvider.overrideWith(() => _AdminAuth()),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const AdminGymClaimsScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('admin sees claim rows with gym + claimant info', (tester) async {
    await pump(tester, _FakeRepo());
    expect(find.text('Alliance'), findsOneWidget);
    expect(find.textContaining('me@gym.com'), findsWidgets);
  });

  testWidgets('tapping Approve calls approve with the claim id', (tester) async {
    final repo = _FakeRepo();
    await pump(tester, repo);
    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(repo.approvals, contains('c1'));
  });
}
