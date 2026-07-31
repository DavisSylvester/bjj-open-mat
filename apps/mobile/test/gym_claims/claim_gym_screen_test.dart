import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/screens/claim_gym_screen.dart';

class _FakeRepo implements GymClaimRepository {
  final List<Map<String, String>> submits = [];
  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async {
    submits.add({'gymId': gymId, 'relationship': relationship, 'contact': contact, 'message': message});
    return GymClaim(id: 'c1', gymId: gymId, claimantId: 'u1', kind: 'claim', relationship: relationship, contact: contact, message: message, status: 'pending');
  }
  @override
  Future<GymClaim?> myClaimForGym(String gymId) async => null;
  @override
  Future<void> withdraw(String gymId) async {}
  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async => [];
  @override
  Future<void> approve(String claimId) async {}
  @override
  Future<void> reject(String claimId, {String? note}) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [gymClaimRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.glass(), home: const ClaimGymScreen(gymId: 'g1', kind: 'claim')),
    ));
    await tester.pump();
  }

  testWidgets('submits the claim with the entered contact + message', (tester) async {
    final repo = _FakeRepo();
    await pump(tester, repo);
    await tester.enterText(find.byKey(const Key('claim-contact')), 'me@gym.com');
    await tester.enterText(find.byKey(const Key('claim-message')), 'I run this gym');
    await tester.tap(find.byKey(const Key('claim-submit')));
    await tester.pump();
    expect(repo.submits, hasLength(1));
    expect(repo.submits.first['contact'], 'me@gym.com');
  });
}
