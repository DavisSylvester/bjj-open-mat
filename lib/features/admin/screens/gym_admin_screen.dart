import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../../gyms/models/gym.dart';
import '../../gyms/screens/gym_detail_screen.dart';

class GymAdminScreen extends ConsumerWidget {
  final String gymId;
  const GymAdminScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Admin'), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () => context.go('/owner/gyms/add')),
        IconButton(
          icon: const Icon(Icons.delete, color: StitchTokens.error),
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Deactivate Gym?'),
              content: const Text('This will hide the gym from public listings.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate', style: TextStyle(color: StitchTokens.error)))],
            ));
            if (confirm == true) {
              HapticFeedback.heavyImpact();
              final api = ref.read(apiClientProvider);
              await api.delete(Endpoints.gymById(gymId));
              if (context.mounted) context.go('/owner/gyms');
            }
          },
        ),
      ]),
      body: gymAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (gym) => ListView(
          padding: const EdgeInsets.all(StitchTokens.md),
          children: [
            Card(child: Padding(
              padding: const EdgeInsets.all(StitchTokens.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gym.name, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text(gym.address, style: Theme.of(context).textTheme.bodyMedium),
                if (gym.amenities.isNotEmpty) ...[
                  const SizedBox(height: StitchTokens.sm),
                  Wrap(spacing: 4, children: gym.amenities.map((a) => Chip(label: Text(a), visualDensity: VisualDensity.compact)).toList()),
                ],
              ]),
            )),
            const SizedBox(height: StitchTokens.md),
            ListTile(
              leading: const Icon(Icons.event, color: StitchTokens.accent),
              title: const Text('Manage Sessions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/owner/sessions'),
            ),
          ],
        ),
      ),
    );
  }
}
