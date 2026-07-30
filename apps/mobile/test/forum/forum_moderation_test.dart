import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';
import 'package:bjj_open_mat/features/forum/data/forum_repository.dart';
import 'package:bjj_open_mat/features/forum/models/forum_answer.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question_detail.dart';
import 'package:bjj_open_mat/features/forum/screens/forum_question_screen.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';
import 'package:bjj_open_mat/features/membership/models/roster_member.dart';
import 'package:bjj_open_mat/features/membership/widgets/join_gym_button.dart';

// ── Fake forum repo with moderation-call tracking ─────────────────────────────

class _FakeForumRepo implements ForumRepository {
  final List<Map<String, dynamic>> updateQuestionCalls = [];
  final List<String> deleteQuestionCalls = [];
  final List<String> deleteAnswerCalls = [];
  final List<Map<String, String>> updateAnswerCalls = [];

  @override
  Future<ForumQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  ) async {
    updateQuestionCalls.add({'questionId': questionId, ...body});
    return _questionUnlocked.copyWith(
      locked: body['locked'] as bool? ?? _questionUnlocked.locked,
      pinned: body['pinned'] as bool? ?? _questionUnlocked.pinned,
    );
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    deleteQuestionCalls.add(questionId);
  }

  @override
  Future<void> deleteAnswer(String answerId) async {
    deleteAnswerCalls.add(answerId);
  }

  @override
  Future<void> updateAnswer(String answerId, String body) async {
    updateAnswerCalls.add({'answerId': answerId, 'body': body});
  }

  @override
  Future<ForumAnswer> createAnswer(String questionId, String body) async =>
      throw UnimplementedError();

  @override
  Future<void> accept(String questionId, String answerId) async =>
      throw UnimplementedError();

  @override
  Future<List<ForumQuestion>> listQuestions(
    String gymId, {
    String? category,
    int page = 1,
    int limit = 20,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ForumQuestion> createQuestion(
    String gymId,
    Map<String, dynamic> body,
  ) async =>
      throw UnimplementedError();

  @override
  Future<ForumQuestionDetail> getDetail(String questionId) async =>
      throw UnimplementedError();
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kManagerUserId = 'manager1';
const _kPlainUserId = 'plain1';
const _kQuestionAuthorId = 'author1';
const _kAnswerAuthorId = 'answerauthor1';

extension _CopyWith on ForumQuestion {
  ForumQuestion copyWith({bool? locked, bool? pinned}) => ForumQuestion(
        id: id,
        gymId: gymId,
        authorId: authorId,
        category: category,
        title: title,
        body: body,
        pinned: pinned ?? this.pinned,
        locked: locked ?? this.locked,
        acceptedAnswerId: acceptedAnswerId,
        answerCount: answerCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

final _questionUnlocked = ForumQuestion(
  id: 'q1',
  gymId: 'g1',
  authorId: _kQuestionAuthorId,
  category: 'technique',
  title: 'How to escape side control?',
  body: 'Any tips on escaping side control effectively?',
  pinned: false,
  locked: false,
  acceptedAnswerId: null,
  answerCount: 1,
);

// Answer authored by someone else (not currentUser)
final _otherAnswer = ForumAnswer(
  id: 'a1',
  questionId: 'q1',
  gymId: 'g1',
  authorId: _kAnswerAuthorId,
  body: 'Use the elbow-knee escape.',
  accepted: false,
);

// Answer authored by the question author
final _authorOwnAnswer = ForumAnswer(
  id: 'a2',
  questionId: 'q1',
  gymId: 'g1',
  authorId: _kQuestionAuthorId,
  body: 'Actually I figured it out.',
  accepted: false,
);

final _detailWithAnswers = ForumQuestionDetail(
  question: _questionUnlocked,
  answers: [_otherAnswer, _authorOwnAnswer],
);

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeForumRepo> _pumpAsManager(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeForumRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => _kManagerUserId),
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        forumQuestionDetailProvider('q1').overrideWith(
          (_) async => _detailWithAnswers,
        ),
        // Manager is gym owner via gymByIdProvider
        gymByIdProvider('g1').overrideWith(
          (_) async => const Gym(
            id: 'g1',
            name: 'Test Gym',
            address: '123 Main St',
            ownerId: _kManagerUserId,
          ),
        ),
        rosterProvider('g1').overrideWith((_) async => <RosterMember>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ForumQuestionScreen(questionId: 'q1', gymId: 'g1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

Future<_FakeForumRepo> _pumpAsPlainMember(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeForumRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(repo),
        // Plain member: different user, not author, not manager
        currentUserIdProvider.overrideWith((ref) => _kPlainUserId),
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        forumQuestionDetailProvider('q1').overrideWith(
          (_) async => _detailWithAnswers,
        ),
        // Not the gym owner
        gymByIdProvider('g1').overrideWith(
          (_) async => const Gym(
            id: 'g1',
            name: 'Test Gym',
            address: '123 Main St',
            ownerId: 'someone-else',
          ),
        ),
        // Roster member with no elevated role
        rosterProvider('g1').overrideWith((_) async => [
          RosterMember(
            userId: _kPlainUserId,
            name: 'Plain User',
            gymRole: 'member',
            verifiedMember: false,
            hasProfile: true,
          ),
        ]),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ForumQuestionScreen(questionId: 'q1', gymId: 'g1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Case A — manager sees moderation actions', () {
    testWidgets('Pin and Lock actions appear in AppBar popup menu',
        (tester) async {
      await _pumpAsManager(tester);

      // Open the popup menu in the AppBar
      final menuButton = find.byIcon(Icons.more_vert);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Both Pin and Lock should appear
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Lock'), findsOneWidget);
    });

    testWidgets('tapping Lock calls updateQuestion with locked:true',
        (tester) async {
      final repo = await _pumpAsManager(tester);

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Lock
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      // Verify updateQuestion was called with the right args
      expect(repo.updateQuestionCalls, hasLength(1));
      expect(repo.updateQuestionCalls.first['questionId'], equals('q1'));
      expect(repo.updateQuestionCalls.first['locked'], equals(true));
    });

    testWidgets('tapping Pin calls updateQuestion with pinned:true',
        (tester) async {
      final repo = await _pumpAsManager(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      expect(repo.updateQuestionCalls, hasLength(1));
      expect(repo.updateQuestionCalls.first['questionId'], equals('q1'));
      expect(repo.updateQuestionCalls.first['pinned'], equals(true));
    });

    testWidgets('Delete Question option appears for manager', (tester) async {
      await _pumpAsManager(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete Question'), findsOneWidget);
    });

    testWidgets('manager can delete any answer', (tester) async {
      final repo = await _pumpAsManager(tester);

      // Find the delete icon button on the first answer (by another user)
      final deleteButtons = find.byTooltip('Delete answer');
      expect(deleteButtons, findsWidgets);

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Confirm the delete dialog that appears
      final deleteConfirmButton = find.text('Delete');
      expect(deleteConfirmButton, findsOneWidget);
      await tester.tap(deleteConfirmButton);
      await tester.pumpAndSettle();

      expect(repo.deleteAnswerCalls, hasLength(1));
    });
  });

  group('Case B — plain member sees NO moderation actions', () {
    testWidgets('no more_vert icon (or menu has no mod actions)', (tester) async {
      await _pumpAsPlainMember(tester);

      // If there's no popup menu icon, great. If there is one but it only has
      // non-mod items, the next tests verify content. Check there's no
      // moderation popup at all.
      final menuButton = find.byIcon(Icons.more_vert);
      // For a plain member who is not author, there should be NO menu at all
      expect(menuButton, findsNothing);
    });

    testWidgets('no Pin, Lock, or Delete Question text visible', (tester) async {
      await _pumpAsPlainMember(tester);

      expect(find.text('Pin'), findsNothing);
      expect(find.text('Lock'), findsNothing);
      expect(find.text('Unpin'), findsNothing);
      expect(find.text('Unlock'), findsNothing);
      expect(find.text('Delete Question'), findsNothing);
    });

    testWidgets('no delete buttons on answers authored by others',
        (tester) async {
      await _pumpAsPlainMember(tester);

      // Plain member should see no delete answer buttons at all
      expect(find.byTooltip('Delete answer'), findsNothing);
      expect(find.byTooltip('Edit answer'), findsNothing);
    });

    testWidgets('no Accept button visible (plain member is not question author)',
        (tester) async {
      await _pumpAsPlainMember(tester);
      // Question author is _kQuestionAuthorId, current user is _kPlainUserId
      // so no accept button should appear
      expect(find.text('Accept'), findsNothing);
    });
  });
}
