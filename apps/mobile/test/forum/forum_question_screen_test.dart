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

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeForumRepo implements ForumRepository {
  final List<Map<String, String>> createAnswerCalls = [];
  final List<Map<String, String>> acceptCalls = [];

  @override
  Future<ForumAnswer> createAnswer(String questionId, String body) async {
    createAnswerCalls.add({'questionId': questionId, 'body': body});
    return ForumAnswer(
      id: 'new-answer',
      questionId: questionId,
      gymId: 'g1',
      authorId: 'user1',
      body: body,
      accepted: false,
    );
  }

  @override
  Future<void> accept(String questionId, String answerId) async {
    acceptCalls.add({'questionId': questionId, 'answerId': answerId});
  }

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

  @override
  Future<ForumQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteQuestion(String questionId) async =>
      throw UnimplementedError();

  @override
  Future<void> updateAnswer(String answerId, String body) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAnswer(String answerId) async =>
      throw UnimplementedError();
}

// ── Fake auth notifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kCurrentUserId = 'user1';

final _question = ForumQuestion(
  id: 'q1',
  gymId: 'g1',
  authorId: _kCurrentUserId,
  category: 'technique',
  title: 'How to escape side control?',
  body: 'Any tips on escaping side control effectively?',
  pinned: false,
  locked: false,
  acceptedAnswerId: 'a1',
  answerCount: 2,
);

final _lockedQuestion = ForumQuestion(
  id: 'q1',
  gymId: 'g1',
  authorId: _kCurrentUserId,
  category: 'technique',
  title: 'How to escape side control?',
  body: 'Any tips on escaping side control effectively?',
  pinned: false,
  locked: true,
  acceptedAnswerId: null,
  answerCount: 2,
);

final _acceptedAnswer = ForumAnswer(
  id: 'a1',
  questionId: 'q1',
  gymId: 'g1',
  authorId: 'user2',
  body: 'Use the elbow-knee escape.',
  accepted: true,
);

final _nonAcceptedAnswer = ForumAnswer(
  id: 'a2',
  questionId: 'q1',
  gymId: 'g1',
  authorId: 'user3',
  body: 'Try bridging to create space.',
  accepted: false,
);

final _detail = ForumQuestionDetail(
  question: _question,
  answers: [_acceptedAnswer, _nonAcceptedAnswer],
);

final _lockedDetail = ForumQuestionDetail(
  question: _lockedQuestion,
  answers: [_acceptedAnswer, _nonAcceptedAnswer],
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeForumRepo> _pump(
  WidgetTester tester, {
  ForumQuestionDetail? detail,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeForumRepo();
  final resolvedDetail = detail ?? _detail;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => _kCurrentUserId),
        authStateProvider.overrideWith(() => _FakeAuthNotifier()),
        forumQuestionDetailProvider('q1').overrideWith(
          (_) async => resolvedDetail,
        ),
        // Stub out providers used by the manage-gate so no network calls are made.
        gymByIdProvider('g1').overrideWith(
          (_) async => const Gym(id: 'g1', name: 'Test Gym', address: '123 Main St'),
        ),
        rosterProvider('g1').overrideWith((_) async => <RosterMember>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ForumQuestionScreen(questionId: 'q1', gymId: 'g1'),
      ),
    ),
  );
  // Allow FutureProviders to resolve.
  await tester.pump();
  await tester.pump();
  return repo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders question title and body', (tester) async {
    await _pump(tester);
    expect(find.text('How to escape side control?'), findsWidgets);
    expect(find.text('Any tips on escaping side control effectively?'), findsOneWidget);
  });

  testWidgets('accepted answer shows Accepted marker', (tester) async {
    await _pump(tester);
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('both answer bodies are rendered', (tester) async {
    await _pump(tester);
    expect(find.text('Use the elbow-knee escape.'), findsOneWidget);
    expect(find.text('Try bridging to create space.'), findsOneWidget);
  });

  testWidgets('posting an answer calls createAnswer with question id and text',
      (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'My new answer text');
    await tester.pump();

    final postButton = find.text('Post');
    expect(postButton, findsOneWidget);
    await tester.tap(postButton);
    await tester.pump();

    expect(repo.createAnswerCalls, hasLength(1));
    expect(repo.createAnswerCalls.first['questionId'], equals('q1'));
    expect(repo.createAnswerCalls.first['body'], equals('My new answer text'));
  });

  testWidgets('tapping Accept on non-accepted answer calls accept()',
      (tester) async {
    final repo = await _pump(tester);
    // The "Accept" button should appear on the non-accepted answer (a2).
    final acceptButton = find.text('Accept');
    expect(acceptButton, findsOneWidget);
    await tester.tap(acceptButton);
    await tester.pump();

    expect(repo.acceptCalls, hasLength(1));
    expect(repo.acceptCalls.first['questionId'], equals('q1'));
    expect(repo.acceptCalls.first['answerId'], equals('a2'));
  });

  testWidgets('composer is NOT shown when question is locked', (tester) async {
    await _pump(tester, detail: _lockedDetail);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Post'), findsNothing);
  });
}
