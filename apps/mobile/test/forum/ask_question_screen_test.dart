import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/forum/data/forum_repository.dart';
import 'package:bjj_open_mat/features/forum/models/forum_answer.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question_detail.dart';
import 'package:bjj_open_mat/features/forum/screens/ask_question_screen.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeForumRepository implements ForumRepository {
  final List<({String gymId, Map<String, dynamic> body})> createCalls = [];

  @override
  Future<ForumQuestion> createQuestion(
    String gymId,
    Map<String, dynamic> body,
  ) async {
    createCalls.add((gymId: gymId, body: body));
    return ForumQuestion(
      id: 'q-new',
      gymId: gymId,
      authorId: 'u1',
      category: body['category'] as String,
      title: body['title'] as String,
      body: body['body'] as String,
      pinned: false,
      locked: false,
      answerCount: 0,
    );
  }

  @override
  Future<List<ForumQuestion>> listQuestions(
    String gymId, {
    String? category,
    int page = 1,
    int limit = 20,
  }) async => [];

  @override
  Future<ForumQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  ) async => throw UnimplementedError();

  @override
  Future<void> deleteQuestion(String questionId) async =>
      throw UnimplementedError();

  @override
  Future<ForumQuestionDetail> getDetail(String questionId) async =>
      throw UnimplementedError();

  @override
  Future<ForumAnswer> createAnswer(String questionId, String body) async =>
      throw UnimplementedError();

  @override
  Future<void> updateAnswer(String answerId, String body) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAnswer(String answerId) async =>
      throw UnimplementedError();

  @override
  Future<void> accept(String questionId, String answerId) async =>
      throw UnimplementedError();
}

// ── Harness ───────────────────────────────────────────────────────────────────

_FakeForumRepository _fakeRepo = _FakeForumRepository();

Future<void> _pump(WidgetTester tester) async {
  _fakeRepo = _FakeForumRepository();

  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(_fakeRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const AskQuestionScreen(gymId: 'g1'),
      ),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Save is disabled when body is empty', (tester) async {
    await _pump(tester);

    // Enter title but leave body empty.
    await tester.enterText(find.byKey(const Key('ask_title')), 'How to pass?');
    await tester.pump();

    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('ask_save')),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('Save is disabled when title is empty', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byKey(const Key('ask_body')), 'Any tips?');
    await tester.pump();

    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('ask_save')),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets(
    'picks category, enters title+body, taps Save, calls createQuestion',
    (tester) async {
      await _pump(tester);

      // Open category dropdown and select 'technique'.
      await tester.tap(find.byKey(const Key('ask_category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('technique').last);
      await tester.pumpAndSettle();

      // Enter title and body.
      await tester.enterText(
        find.byKey(const Key('ask_title')),
        'How to pass?',
      );
      await tester.enterText(find.byKey(const Key('ask_body')), 'Any tips?');
      await tester.pump();

      // Save should now be enabled.
      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('ask_save')),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap Save.
      await tester.tap(find.byKey(const Key('ask_save')));
      await tester.pumpAndSettle();

      // Assert createQuestion was called with correct args.
      expect(_fakeRepo.createCalls.length, 1);
      final call = _fakeRepo.createCalls.first;
      expect(call.gymId, 'g1');
      expect(call.body['category'], 'technique');
      expect(call.body['title'], 'How to pass?');
      expect(call.body['body'], 'Any tips?');
    },
  );
}
