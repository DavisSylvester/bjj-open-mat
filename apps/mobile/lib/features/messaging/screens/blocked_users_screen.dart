import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../data/messaging_repository.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final blocksAsync = ref.watch(blocksProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Blocked Users', style: t.h2Style),
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load blocked users",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (blockedIds) => blockedIds.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldOff, color: t.faint, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'No blocked users',
                      style: t.bodyStyle.copyWith(color: t.muted),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: blockedIds.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final userId = blockedIds[index];
                  return _BlockedUserTile(userId: userId, t: t);
                },
              ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerWidget {
  final String userId;
  final AppTokens t;

  const _BlockedUserTile({required this.userId, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.userX, color: t.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(userId, style: t.bodyStyle),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(messagingRepositoryProvider);
              try {
                await repo.unblockUser(userId);
                ref.invalidate(blocksProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Couldn't unblock user. Please try again.")),
                  );
                }
              }
            },
            child: Text(
              'Unblock',
              style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
