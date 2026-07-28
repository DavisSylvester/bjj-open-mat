import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';
import 'package:bjj_open_mat/features/classes/models/instructor_feedback_item.dart';
import 'package:bjj_open_mat/features/classes/models/instructor_rating_summary.dart';
import 'package:bjj_open_mat/features/classes/screens/class_journal_form_screen.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeJournalRepo implements ClassJournalRepository {
  final List<Map<String, dynamic>> upsertCalls = [];
  final List<Map<String, dynamic>> rateCalls = [];

  @override
  Future<ClassJournalEntry> upsertJournal(
    String classId,
    Map<String, dynamic> body,
  ) async {
    upsertCalls.add({'classId': classId, ...body});
    return ClassJournalEntry(
      id: 'je1',
      classId: classId,
      gymId: 'g1',
      userId: 'u1',
      date: '2026-08-03',
    );
  }

  @override
  Future<void> rateInstructor(String classId, Map<String, dynamic> body) async {
    rateCalls.add({'classId': classId, ...body});
  }

  @override
  Future<List<ClassJournalEntry>> myJournal({
    required String from,
    required String to,
  }) async => [];

  @override
  Future<List<ClassJournalEntry>> sharedForOccurrence(
    String classId,
    String date,
  ) async => [];

  @override
  Future<InstructorRatingSummary> instructorSummary(String userId) async =>
      throw UnimplementedError();

  @override
  Future<List<InstructorFeedbackItem>> gymInstructorFeedback(
    String gymId, {
    String? instructorUserId,
    String? from,
    String? to,
  }) async => throw UnimplementedError();
}

// ── Harness ───────────────────────────────────────────────────────────────────

Future<_FakeJournalRepo> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeJournalRepo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classJournalRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ClassJournalFormScreen(
          classId: 'c1',
          gymId: 'g1',
          date: '2026-08-03',
        ),
      ),
    ),
  );
  await tester.pump();
  return repo;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'Save calls upsertJournal with whatWasTaught, techniqueTags, shared; '
      'and rateInstructor with stars and date', (tester) async {
    final repo = await _pump(tester);

    // Enter whatWasTaught
    await tester.enterText(
      find.byKey(const Key('whatWasTaught')),
      'guard passing',
    );
    await tester.pump();

    // Add tag "armbar"
    await tester.enterText(find.byKey(const Key('tagInput')), 'armbar');
    await tester.pump();
    await tester.tap(find.byKey(const Key('addTagButton')));
    await tester.pump();

    // Toggle Share on (find the SwitchListTile for sharing)
    await tester.tap(find.byKey(const Key('shareSwitch')));
    await tester.pump();

    // Scroll to find star rating (if needed) and pick 5th star
    await tester.ensureVisible(find.byKey(const Key('star_5')));
    await tester.tap(find.byKey(const Key('star_5')));
    await tester.pump();

    // Tap Save
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump();
    await tester.pump();

    // Assert upsertJournal called with correct args
    expect(repo.upsertCalls, hasLength(1));
    final upsertCall = repo.upsertCalls.first;
    expect(upsertCall['classId'], equals('c1'));
    expect(upsertCall['whatWasTaught'], equals('guard passing'));
    expect(upsertCall['techniqueTags'], contains('armbar'));
    expect(upsertCall['shared'], isTrue);

    // Assert rateInstructor called with stars==5, date=='2026-08-03'
    expect(repo.rateCalls, hasLength(1));
    final rateCall = repo.rateCalls.first;
    expect(rateCall['classId'], equals('c1'));
    expect(rateCall['stars'], equals(5));
    expect(rateCall['date'], equals('2026-08-03'));
  });
}
