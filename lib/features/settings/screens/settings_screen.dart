import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class _ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode value) => state = value;
}

final themeModeProvider = NotifierProvider<_ThemeModeNotifier, ThemeMode>(_ThemeModeNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Theme
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              onSelectionChanged: (v) { HapticFeedback.selectionClick(); ref.read(themeModeProvider.notifier).set(v.first); },
            ),
          ),
          const Divider(),

          // Location
          ListTile(leading: const Icon(Icons.location_on), title: const Text('Location Precision'), subtitle: const Text('While using the app'), trailing: const Icon(Icons.chevron_right), onTap: () {}),

          // Search radius
          ListTile(leading: const Icon(Icons.radar), title: const Text('Default Search Radius'), subtitle: const Text('25 km'), trailing: const Icon(Icons.chevron_right), onTap: () {}),

          const Divider(),

          // Notifications
          ListTile(leading: const Icon(Icons.notifications), title: const Text('Notification Preferences'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/notifications')),

          const Divider(),

          // About
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('About'), subtitle: const Text('BJJ Open Mat Finder v0.1.0')),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: StitchTokens.error),
            title: const Text('Log Out', style: TextStyle(color: StitchTokens.error)),
            onTap: () async {
              HapticFeedback.heavyImpact();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
