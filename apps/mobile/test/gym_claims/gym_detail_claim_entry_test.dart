import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/gym_claims/data/gym_claim_repository.dart';
import 'package:bjj_open_mat/features/gym_claims/models/gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/models/admin_gym_claim.dart';
import 'package:bjj_open_mat/features/gym_claims/widgets/gym_claim_entry.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

class FakeGymClaimRepository implements GymClaimRepository {
  final List<String> withdrawCalls = [];

  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) {
    throw UnimplementedError();
  }

  @override
  Future<GymClaim?> myClaimForGym(String gymId) async => null;

  @override
  Future<void> withdraw(String gymId) async {
    withdrawCalls.add(gymId);
  }

  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) {
    throw UnimplementedError();
  }

  @override
  Future<void> approve(String claimId) {
    throw UnimplementedError();
  }

  @override
  Future<void> reject(String claimId, {String? note}) {
    throw UnimplementedError();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(
    WidgetTester tester, {
    required String? ownerId,
    GymClaim? myClaim,
    String? myId,
    GymClaimRepository? repoOverride,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        myGymClaimProvider('g1').overrideWith((_) async => myClaim),
        currentUserIdProvider.overrideWith((ref) => myId),
        if (repoOverride != null) gymClaimRepositoryProvider.overrideWithValue(repoOverride),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: Scaffold(body: GymClaimEntry(gymId: 'g1', ownerId: ownerId)),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows Claim this gym when unowned and no claim', (tester) async {
    await pump(tester, ownerId: null, myClaim: null, myId: 'u1');
    expect(find.text('Claim this gym'), findsOneWidget);
  });

  testWidgets('shows Request ownership when owned by someone else', (tester) async {
    await pump(tester, ownerId: 'other', myClaim: null, myId: 'u1');
    expect(find.text('Request ownership'), findsOneWidget);
  });

  testWidgets('shows pending chip when a pending claim exists', (tester) async {
    await pump(tester, ownerId: null, myId: 'u1', myClaim: const GymClaim(
      id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner',
      contact: 'x', message: 'y', status: 'pending'));
    expect(find.text('Claim pending review'), findsOneWidget);
  });

  testWidgets('shows nothing when caller is the owner', (tester) async {
    await pump(tester, ownerId: 'u1', myClaim: null, myId: 'u1');
    expect(find.text('Claim this gym'), findsNothing);
    expect(find.text('Request ownership'), findsNothing);
  });

  testWidgets('pending claim shows Withdraw button and tapping it calls withdraw', (tester) async {
    final fakeRepo = FakeGymClaimRepository();
    await pump(
      tester,
      ownerId: null,
      myId: 'u1',
      myClaim: const GymClaim(
        id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner',
        contact: 'x', message: 'y', status: 'pending',
      ),
      repoOverride: fakeRepo,
    );
    expect(find.text('Claim pending review'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
    await tester.pump();
    expect(fakeRepo.withdrawCalls, contains('g1'));
  });

  testWidgets('rejected claim shows Not approved chip and re-submit button', (tester) async {
    await pump(
      tester,
      ownerId: null,
      myId: 'u1',
      myClaim: const GymClaim(
        id: 'c1', gymId: 'g1', claimantId: 'u1', kind: 'claim', relationship: 'owner',
        contact: 'x', message: 'y', status: 'rejected',
      ),
    );
    expect(find.text('Not approved'), findsOneWidget);
    expect(find.text('Claim this gym'), findsOneWidget);
  });
}
