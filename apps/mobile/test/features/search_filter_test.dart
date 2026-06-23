// Verifies the Search screen's gi-type and "Free" filters are a combination
// (multi-select) rather than mutually exclusive: gi-types OR among themselves,
// and "Free" ANDs with them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/search/screens/search_screen.dart';
import 'package:bjj_open_mat/shared/widgets/session_row.dart';

void main() {
  setUpAll(() {
    // Don't hit the network for fonts during the test.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('gi-type and Free filters combine (multi-select)', (WidgetTester tester) async {
    // Tall surface so the lazy results ListView builds every SessionRow.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.glass(), home: const SearchScreen()));
    await tester.pumpAndSettle();

    // No filters: all 8 stub sessions are within the default 10mi range.
    expect(find.byType(SessionRow), findsNWidgets(8));

    // The first ListView is the horizontal filter-chip row: [Gi, No-Gi, Gi·No-Gi, Free].
    final Finder chips =
        find.descendant(of: find.byType(ListView).first, matching: find.byType(GestureDetector));

    // Gi only -> 3 gi sessions.
    await tester.tap(chips.at(0));
    await tester.pumpAndSettle();
    expect(find.byType(SessionRow), findsNWidgets(3));

    // Add No-Gi -> gi OR no-gi = 5. (Both chips active at once = the combination
    // that the old single-select could not express.)
    await tester.tap(chips.at(1));
    await tester.pumpAndSettle();
    expect(find.byType(SessionRow), findsNWidgets(5));

    // Add Free -> (gi OR no-gi) AND free = the 3 free gi sessions.
    await tester.tap(chips.at(3));
    await tester.pumpAndSettle();
    expect(find.byType(SessionRow), findsNWidgets(3));

    // Toggling Free back off returns to the 5 gi/no-gi sessions.
    await tester.tap(chips.at(3));
    await tester.pumpAndSettle();
    expect(find.byType(SessionRow), findsNWidgets(5));
  });
}
