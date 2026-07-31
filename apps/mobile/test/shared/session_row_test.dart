import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/shared/widgets/session_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRowData _data({
  String gymName = 'Downtown BJJ',
  String? title = 'Sunday No-Gi',
}) =>
    SessionRowData(
      gymName: gymName,
      title: title,
      giType: 'nogi',
      expLevel: 'all',
      time: '2:00 PM',
      day: 'Sun',
      distance: '1.2 mi',
      fee: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  SessionRowData data, {
  bool showGymName = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.glass(),
      home: Scaffold(
        body: SessionRow(session: data, showGymName: showGymName),
      ),
    ),
  );
}

void main() {
  group('SessionRow', () {
    testWidgets('leads with the session title when title is set', (tester) async {
      await _pump(tester, _data());
      expect(find.text('Sunday No-Gi'), findsOneWidget);
    });

    testWidgets('falls back to day · time when title is null', (tester) async {
      await _pump(tester, _data(title: null));
      expect(find.text('Sun · 2:00 PM'), findsOneWidget);
    });

    testWidgets('shows gym name as secondary line when showGymName is true (global default)', (tester) async {
      await _pump(tester, _data(), showGymName: true);
      expect(find.text('Sunday No-Gi'), findsOneWidget);
      expect(find.text('Downtown BJJ'), findsOneWidget);
    });

    testWidgets('omits gym name when showGymName is false (gym-scoped screen)', (tester) async {
      await _pump(tester, _data(), showGymName: false);
      expect(find.text('Sunday No-Gi'), findsOneWidget);
      expect(find.text('Downtown BJJ'), findsNothing);
    });
  });
}
