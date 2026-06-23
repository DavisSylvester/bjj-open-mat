import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/shared/widgets/session_row.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows Unverified pill only when unverified is true', (tester) async {
    Widget wrap(bool unverified) => MaterialApp(
          theme: AppTheme.glass(),
          home: Scaffold(
            body: SessionRow(
              session: SessionRowData(
                gymName: 'X', giType: 'gi', expLevel: 'all', time: '7:00 PM',
                day: 'Mon', distance: '1 mi', fee: 0, unverified: unverified),
            ),
          ),
        );
    await tester.pumpWidget(wrap(true));
    await tester.pump();
    expect(find.text('Unverified'), findsOneWidget);

    await tester.pumpWidget(wrap(false));
    await tester.pump();
    expect(find.text('Unverified'), findsNothing);
  });

  testWidgets('sport theme: shows Unverified pill only when unverified is true', (tester) async {
    Widget wrap(bool unverified) => MaterialApp(
          theme: AppTheme.sport(),
          home: Scaffold(
            body: SessionRow(
              session: SessionRowData(
                gymName: 'X', giType: 'gi', expLevel: 'all', time: '7:00 PM',
                day: 'Mon', distance: '1 mi', fee: 0, unverified: unverified),
            ),
          ),
        );
    await tester.pumpWidget(wrap(true));
    await tester.pump();
    expect(find.text('Unverified'), findsOneWidget);

    await tester.pumpWidget(wrap(false));
    await tester.pump();
    expect(find.text('Unverified'), findsNothing);
  });
}
