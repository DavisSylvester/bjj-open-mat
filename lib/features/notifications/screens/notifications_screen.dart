import 'package:flutter/material.dart';
import '../../../shared/widgets/error_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In production, this would use a provider connected to FCM/push notifications
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const EmptyState(
        title: 'No notifications',
        subtitle: 'Session reminders and updates will appear here',
        icon: Icons.notifications_none,
      ),
    );
  }
}
