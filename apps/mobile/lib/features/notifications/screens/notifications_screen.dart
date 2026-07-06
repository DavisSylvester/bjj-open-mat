import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/glass_form.dart';

/// Back affordance for full-screen routes reached via push (falls back to
/// /profile if there is nothing to pop).
Widget _backButton(BuildContext context, AppTokens t) => GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Icon(LucideIcons.arrowLeft, color: t.text, size: 22),
    );

class _NotificationItem {
  final IconData icon;
  final Color Function(AppTokens t) iconColor;
  final String title;
  final String body;
  final String timestamp;

  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

final _stubNotifications = <_NotificationItem>[
  _NotificationItem(
    icon: LucideIcons.calendarCheck,
    iconColor: (t) => t.green,
    title: 'Session Reminder',
    body: 'Atos HQ open mat starts in 1 hour.',
    timestamp: '1h ago',
  ),
  _NotificationItem(
    icon: LucideIcons.star,
    iconColor: (t) => t.amber,
    title: 'Leave a Review',
    body: 'How was your session at Renzo Westwood?',
    timestamp: '3h ago',
  ),
  _NotificationItem(
    icon: LucideIcons.users,
    iconColor: (t) => t.gi,
    title: 'New Open Mat Posted',
    body: 'Gracie Barra Pasadena added a Sunday session.',
    timestamp: 'Yesterday',
  ),
  _NotificationItem(
    icon: LucideIcons.bell,
    iconColor: (t) => t.muted,
    title: 'Session Updated',
    body: 'Alliance Jiu-Jitsu changed Friday start time to 7:00 PM.',
    timestamp: '2d ago',
  ),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _GlassNotifications(t: t);
  }
}

class _GlassNotifications extends StatelessWidget {
  final AppTokens t;
  const _GlassNotifications({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              _backButton(context, t),
              const SizedBox(width: 12),
              Text('Notifications', style: t.h1Style),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: glassSectionLabel(t, 'Recent'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _stubNotifications.length,
              itemBuilder: (_, i) {
                final n = _stubNotifications[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: n.iconColor(t).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(n.icon, size: 18, color: n.iconColor(t)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: t.h2Style.copyWith(fontSize: 14),
                              ),
                            ),
                            Text(
                              n.timestamp,
                              style: t.miniStyle.copyWith(fontSize: 11),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            n.body,
                            style: t.bodyStyle.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
