import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/report/data/report_repository.dart';
import 'package:bjj_open_mat/features/report/models/report.dart';
import 'package:bjj_open_mat/features/report/screens/report_screen.dart';

class _FakeReportRepository implements ReportRepository {
  String? capturedType;
  String? capturedTitle;
  String? capturedDescription;
  int calls = 0;

  @override
  Future<Report> create({
    required String type,
    required String title,
    required String description,
    List<String> audioKeys = const [],
  }) async {
    calls++;
    capturedType = type;
    capturedTitle = title;
    capturedDescription = description;
    return Report(
      id: 'r1',
      userId: 'u1',
      type: type,
      title: title,
      description: description,
      status: 'open',
    );
  }

  @override
  Future<List<Report>> listMine() async => [];
}

Future<void> _pump(WidgetTester tester, _FakeReportRepository fake) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      theme: AppTheme.glass(),
      home: const ReportScreen(),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('submit is disabled with empty fields and does not call create', (tester) async {
    final fake = _FakeReportRepository();
    await _pump(tester, fake);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls, 0);
  });

  testWidgets('valid input submits with default bug type', (tester) async {
    final fake = _FakeReportRepository();
    await _pump(tester, fake);

    await tester.enterText(find.widgetWithText(TextField, 'Short summary'), 'App crash');
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened / what would you like?'),
      'It crashes on launch every time',
    );
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pump();
    await tester.pump();

    expect(fake.calls, 1);
    expect(fake.capturedType, 'bug');
    expect(fake.capturedTitle, 'App crash');
    expect(fake.capturedDescription, 'It crashes on launch every time');
  });

  testWidgets('toggling to Feature submits with feature type', (tester) async {
    final fake = _FakeReportRepository();
    await _pump(tester, fake);

    await tester.tap(find.text('Feature'));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Short summary'), 'Dark mode');
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened / what would you like?'),
      'Please add a dark theme option',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pump();
    await tester.pump();

    expect(fake.calls, 1);
    expect(fake.capturedType, 'feature');
  });
}
