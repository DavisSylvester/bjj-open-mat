import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart' show ErrorState;
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

/// Back affordance for full-screen routes reached via push (falls back to
/// /profile if there is nothing to pop).
Widget _backButton(BuildContext context, AppTokens t) => GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Icon(LucideIcons.arrowLeft, color: t.text, size: 22),
    );

IconData _iconFor(String type) => switch (type) {
      'rsvp' => LucideIcons.users,
      'review' => LucideIcons.star,
      'session_update' => LucideIcons.calendarCheck,
      _ => LucideIcons.bell,
    };

Color _colorFor(String type, AppTokens t) => switch (type) {
      'rsvp' => t.gi,
      'review' => t.amber,
      'session_update' => t.green,
      _ => t.muted,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final async = ref.watch(myNotificationsProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              _backButton(context, t),
              const SizedBox(width: 12),
              Expanded(child: Text('Notifications', style: t.h1Style)),
              GestureDetector(
                onTap: () async {
                  try {
                    await ref.read(notificationRepositoryProvider).markAllRead();
                    ref.invalidate(myNotificationsProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't mark all read")),
                      );
                    }
                  }
                },
                child: Text('Mark all read', style: t.miniStyle.copyWith(color: t.primary, fontSize: 12)),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: "Couldn't load notifications",
                onRetry: () => ref.invalidate(myNotificationsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.bell,
                      title: 'No notifications',
                      subtitle: "You're all caught up.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _NotificationRow(t: t, n: items[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AppTokens t;
  final AppNotification n;
  const _NotificationRow({required this.t, required this.n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: n.read
          ? null
          : () async {
              try {
                await ref.read(notificationRepositoryProvider).markRead(n.id);
                ref.invalidate(myNotificationsProvider);
              } catch (_) {/* leave unread */}
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.read ? Colors.white : t.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: n.read ? t.border : t.primary.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_iconFor(n.type), size: 18, color: _colorFor(n.type, t)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: t.h2Style.copyWith(fontSize: 14, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
              const SizedBox(height: 3),
              Text(n.body, style: t.bodyStyle.copyWith(color: t.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(relativeTime(n.createdAt), style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
        ]),
      ),
    );
  }
}
