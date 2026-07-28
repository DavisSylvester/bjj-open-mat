import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';
import 'package:bjj_open_mat/features/classes/models/class_journal_entry.dart';
import 'package:bjj_open_mat/features/training/data/training_provider.dart';
import 'package:bjj_open_mat/features/training/screens/my_training_screen.dart';

// ── Fake entries ──────────────────────────────────────────────────────────────

final _entry1 = ClassJournalEntry(
  id: 'je1',
  classId: 'c1',
  gymId: 'g1',
  userId: 'u1',
  date: '2026-07-20',
  whatWasTaught: 'guard passing fundamentals',
  techniqueTags: const ['guard pass', 'torreando'],
);

final _entry2 = ClassJournalEntry(
  id: 'je2',
  classId: 'c2',
  gymId: 'g1',
  userId: 'u1',
  date: '2026-07-27',
  whatWasTaught: 'back attacks and seatbelt',
  techniqueTags: const ['rear naked choke', 'body lock'],
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Stub myTrainingProvider so the screen shell builds
        myTrainingProvider.overrideWith(
          (ref) async => TrainingHistory(items: const [], total: 0),
        ),
        // Override ALL family args for myJournalProvider
        myJournalProvider.overrideWith(
          (ref, arg) async => [_entry2, _entry1],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const MyTrainingScreen(),
      ),
    ),
  );

  // Pump twice: once to build, once to resolve futures
  await tester.pump();
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders "Class journal" section heading', (tester) async {
    await _pump(tester);
    expect(find.text('Class journal'), findsOneWidget);
  });

  testWidgets('renders first entry whatWasTaught under Class journal heading',
      (tester) async {
    await _pump(tester);
    expect(find.text('back attacks and seatbelt'), findsOneWidget);
  });

  testWidgets('renders second entry whatWasTaught under Class journal heading',
      (tester) async {
    await _pump(tester);
    expect(find.text('guard passing fundamentals'), findsOneWidget);
  });

  testWidgets('renders technique-tag chips for entries', (tester) async {
    await _pump(tester);
    expect(find.text('torreando'), findsOneWidget);
    expect(find.text('rear naked choke'), findsOneWidget);
  });
}
