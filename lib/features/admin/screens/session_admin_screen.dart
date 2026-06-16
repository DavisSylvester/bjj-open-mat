import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../../open_mats/screens/open_mat_detail_screen.dart';

class SessionAdminScreen extends ConsumerWidget {
  final String sessionId;
  const SessionAdminScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matAsync = ref.watch(openMatDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Session Detail'), actions: [
        IconButton(icon: const Icon(Icons.people), onPressed: () => context.go('/owner/sessions/$sessionId/attendance')),
        IconButton(
          icon: const Icon(Icons.cancel, color: StitchTokens.error),
          onPressed: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Cancel Session?'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel', style: TextStyle(color: StitchTokens.error)))],
            ));
            if (confirm == true) {
              HapticFeedback.heavyImpact();
              final api = ref.read(apiClientProvider);
              await api.delete(Endpoints.openMatById(sessionId));
              if (context.mounted) context.go('/owner/sessions');
            }
          },
        ),
      ]),
      body: matAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (mat) => ListView(
          padding: const EdgeInsets.all(StitchTokens.md),
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(StitchTokens.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mat.title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Row(children: [
                Chip(label: Text(mat.skillBadge), backgroundColor: StitchTokens.accent.withValues(alpha: 0.15)),
                const SizedBox(width: 6),
                Chip(label: Text(mat.giBadge), backgroundColor: StitchTokens.secondary.withValues(alpha: 0.15)),
                if (mat.isCancelled) ...[const SizedBox(width: 6), const Chip(label: Text('Cancelled'), backgroundColor: Color(0x26EB3B5A))],
              ]),
              const SizedBox(height: 8),
              Text('${mat.dayName} ${mat.startTime} – ${mat.endTime}', style: Theme.of(context).textTheme.bodyLarge),
              if (mat.maxParticipants != null) Text('${mat.checkinCount ?? 0} / ${mat.maxParticipants} participants'),
            ]))),
            const SizedBox(height: StitchTokens.md),
            ElevatedButton.icon(icon: const Icon(Icons.list), label: const Text('View Attendance'), onPressed: () => context.go('/owner/sessions/$sessionId/attendance')),
          ],
        ),
      ),
    );
  }
}
