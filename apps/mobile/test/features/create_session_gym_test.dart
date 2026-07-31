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

  testWidgets('preselects the gym when initialGymId is provided', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allGymsProvider.overrideWith((ref) async => <Gym>[
          const Gym(id: 'gym-1', name: 'Atos HQ', address: '123 Main St'),
          const Gym(id: 'gym-2', name: 'Gracie Barra', address: '456 Oak Ave'),
        ]),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const CreateSessionScreen(initialGymId: 'gym-2'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    // The selected gym name should appear in the posting-as card.
    expect(find.text('Gracie Barra'), findsWidgets);
    // The other gym should not be shown as selected (not visible in the card).
    expect(find.text('Atos HQ'), findsNothing);
  });
}
