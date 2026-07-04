import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/admin/screens/create_session_screen.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows gym search and an add-new-gym affordance', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allGymsProvider.overrideWith((ref) async => <Gym>[
          const Gym(id: 'gym-1', name: 'Atos HQ', address: '123 Main St'),
        ]),
      ],
      child: MaterialApp(theme: AppTheme.glass(), home: const CreateSessionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Atos HQ'), findsWidgets);
    expect(find.textContaining('Add'), findsWidgets); // "Add a gym" affordance present
  });
}
