import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/mygym/data/home_gym_provider.dart';
import 'package:bjj_open_mat/features/mygym/screens/my_gym_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required String? homeGymId}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeGymIdProvider.overrideWith((ref) async => homeGymId),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const MyGymScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the find-your-gym prompt when there is no gym', (tester) async {
    await _pump(tester, homeGymId: null);
    expect(find.text('Find your gym'), findsOneWidget);
    expect(find.textContaining('roster'), findsWidgets);
  });

  testWidgets('the empty state offers a route into gym search', (tester) async {
    await _pump(tester, homeGymId: null);
    expect(find.byKey(const Key('mygym-find-gym-button')), findsOneWidget);
  });
}
