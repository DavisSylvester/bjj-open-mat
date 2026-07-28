import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';
import 'package:bjj_open_mat/features/classes/models/instructor_feedback_item.dart';
import 'package:bjj_open_mat/features/classes/screens/instructor_feedback_screen.dart';

void main() {
  const namedItem = InstructorFeedbackItem(
    classId: 'c1',
    date: '2026-07-28',
    stars: 4,
    comment: 'great class',
    ratedByName: 'Alice',
    anonymous: false,
  );

  const anonymousItem = InstructorFeedbackItem(
    classId: 'c2',
    date: '2026-07-27',
    stars: 3,
    comment: 'tough',
    ratedByName: 'Bob',
    anonymous: true,
  );

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        gymInstructorFeedbackProvider('g1').overrideWith(
          (ref) async => [namedItem, anonymousItem],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const InstructorFeedbackScreen(gymId: 'g1'),
      ),
    );
  }

  testWidgets('renders named and anonymous feedback items', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump(); // trigger FutureProvider
    await tester.pump(); // settle

    // Comments are visible
    expect(find.text('great class'), findsOneWidget);
    expect(find.text('tough'), findsOneWidget);

    // Named item shows ratedByName
    expect(find.text('Alice'), findsOneWidget);

    // Anonymous item shows "Anonymous" — NOT "Bob"
    expect(find.text('Anonymous'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
  });
}
