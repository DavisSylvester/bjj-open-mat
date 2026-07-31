import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../data/messaging_repository.dart';
import '../models/conversation_summary.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with WidgetsBindingObserver {

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(conversationsProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(conversationsProvider);
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(conversationsProvider);
    await ref.read(conversationsProvider.future).catchError((_) => <ConversationSummary>[]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Messages', style: t.h2Style),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        // TODO: navigate to new-message screen (Task 20: /messages/new)
        onPressed: () => context.push('/messages/new'),
        child: const Icon(Icons.edit_outlined),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load conversations",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (conversations) => conversations.isEmpty
            ? Center(
                child: Text(
                  'No conversations yet. Start one!',
                  style: t.bodyStyle.copyWith(color: t.muted),
                ),
              )
            : RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final summary = conversations[index];
                    return GestureDetector(
                      onTap: () => context.push(
                        '/messages/${summary.conversation.id}',
                        extra: <String, dynamic>{
                          'gymId': summary.conversation.gymId,
                          'kind': summary.conversation.kind,
                        },
                      ),
                      child: _ConversationTile(summary: summary, t: t),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationSummary summary;
  final AppTokens t;

  const _ConversationTile({required this.summary, required this.t});

  String _resolveTitle() {
    final conv = summary.conversation;
    if (conv.kind == 'direct') {
      return summary.otherParticipantIds.isNotEmpty ? summary.otherParticipantIds.first : conv.id;
    }
    return conv.title ?? conv.id;
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolveTitle();
    final preview = summary.conversation.lastMessagePreview;
    final hasUnread = summary.unreadCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: t.bodyStyle.copyWith(
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          color: t.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (summary.muted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.volume_off, size: 14, color: t.muted),
                    ],
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: t.miniStyle.copyWith(
                      color: t.muted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(width: 8),
            _UnreadBadge(count: summary.unreadCount, t: t),
          ],
        ],
      ),
    );
  }
}

// ── Unread badge ──────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  final AppTokens t;

  const _UnreadBadge({required this.count, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: t.miniStyle.copyWith(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
