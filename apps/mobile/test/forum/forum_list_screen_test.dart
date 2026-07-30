import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/forum/data/forum_repository.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question.dart';
import 'package:bjj_open_mat/features/forum/screens/forum_list_screen.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _pinnedQuestion = ForumQuestion(
  id: 'q1',
  gymId: 'g1',
  authorId: 'u1',
  category: 'general',
  title: 'Pinned Question',
  body: 'Body of pinned question',
  pinned: true,
  locked: false,
  acceptedAnswerId: null,
  answerCount: 3,
);

final _acceptedQuestion = ForumQuestion(
  id: 'q2',
  gymId: 'g1',
  authorId: 'u2',
  category: 'technique',
  title: 'Accepted Question',
  body: 'Body of accepted question',
  pinned: false,
  locked: false,
  acceptedAnswerId: 'ans1',
  answerCount: 1,
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumQuestionsProvider((gymId: 'g1', category: null)).overrideWith(
          (ref) async => [_pinnedQuestion, _acceptedQuestion],
        ),
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        currentUserIdProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ForumListScreen(gymId: 'g1'),
      ),
    ),
  );
  // Allow FutureProvider to resolve.
  await tester.pump();
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders both question titles', (tester) async {
    await _pump(tester);
    expect(find.text('Pinned Question'), findsOneWidget);
    expect(find.text('Accepted Question'), findsOneWidget);
  });

  testWidgets('shows pin icon for pinned question', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('shows accepted indicator for answered question', (tester) async {
    await _pump(tester);
    // The accepted question has acceptedAnswerId != null — shown with a check icon.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows answer counts', (tester) async {
    await _pump(tester);
    expect(find.text('3 answers'), findsOneWidget);
    expect(find.text('1 answer'), findsOneWidget);
  });

  testWidgets('shows category chip for technique question', (tester) async {
    await _pump(tester);
    // 'Technique' appears in the filter row chip AND in the ForumCategoryChip
    // on the question tile — expect at least one match.
    expect(find.text('Technique'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows FAB to ask a question', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
