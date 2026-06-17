import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class SessionAdminScreen extends ConsumerWidget {
  final String sessionId;
  const SessionAdminScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/owner/sessions'),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Session Admin', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => context.go('/owner/sessions/$sessionId/attendance'),
                child: Icon(LucideIcons.users, size: 18, color: t.muted),
              ),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Session ID', style: t.labelStyle),
                    const SizedBox(height: 4),
                    Text(sessionId, style: t.bodyStyle),
                  ]),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.go('/owner/sessions/$sessionId/attendance'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.cardRadius),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.users, size: 20, color: t.muted),
                      const SizedBox(width: 12),
                      Text('Attendance', style: t.bodyStyle),
                      const Spacer(),
                      Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
