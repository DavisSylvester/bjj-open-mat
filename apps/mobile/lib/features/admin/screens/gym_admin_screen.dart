import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class GymAdminScreen extends ConsumerWidget {
  final String gymId;
  const GymAdminScreen({super.key, required this.gymId});

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
                onTap: () => context.go('/owner/gyms'),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Gym Admin', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => context.go('/owner/gyms/add'),
                child: Icon(LucideIcons.pencil, size: 18, color: t.muted),
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
                    Text('Gym ID', style: t.labelStyle),
                    const SizedBox(height: 4),
                    Text(gymId, style: t.bodyStyle),
                  ]),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.go('/owner/sessions/create'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.cardRadius),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.calendar, size: 20, color: t.muted),
                      const SizedBox(width: 12),
                      Text('Manage Sessions', style: t.bodyStyle),
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
