import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../features/membership/widgets/join_gym_button.dart';
import '../data/messaging_repository.dart';
import '../models/message.dart';

class ConversationScreen extends ConsumerStatefulWidget {

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.gymId,
    required this.kind,
  });

  final String conversationId;
  final String? gymId;
  final String kind; // 'direct', 'group', 'channel'

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {

  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(messagesProvider(widget.conversationId));
      }
    });
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(messagingRepositoryProvider);
      await repo.sendMessage(widget.conversationId, body);
      _composer.clear();
      ref.invalidate(messagesProvider(widget.conversationId));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final repo = ref.read(messagingRepositoryProvider);
    await repo.deleteMessage(messageId);
    ref.invalidate(messagesProvider(widget.conversationId));
  }

  Future<void> _editMessage(String messageId, String currentBody) async {
    final controller = TextEditingController(text: currentBody);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      final repo = ref.read(messagingRepositoryProvider);
      await repo.editMessage(messageId, result);
      ref.invalidate(messagesProvider(widget.conversationId));
    }
  }

  Future<void> _reportMessage(Message message) async {
    String? selectedReason;
    final reasons = ['spam', 'harassment', 'inappropriate', 'other'];
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (r) => ListTile(
                    dense: true,
                    leading: Icon(
                      selectedReason == r
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(r),
                    onTap: () => setDialogState(() => selectedReason = r),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (selectedReason != null) Navigator.pop(ctx);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    if (selectedReason != null) {
      final repo = ref.read(messagingRepositoryProvider);
      await repo.reportMessage(
        messageId: message.id,
        reportedUserId: message.authorId,
        reason: selectedReason!,
      );
    }
  }

  Future<void> _blockUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user'),
        content: const Text('Are you sure you want to block this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(messagingRepositoryProvider);
      await repo.blockUser(userId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showMessageActions(
    BuildContext context,
    Message message,
    bool isOwnMessage,
    bool isAdmin,
  ) {
    final canDelete = (isOwnMessage || isAdmin) && !message.isDeleted;
    final canEdit = isOwnMessage && !message.isDeleted;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(message.id, message.body);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message.id);
                },
              ),
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final myId = ref.watch(currentUserIdProvider);
    final isAdmin =
        ref.watch(authStateProvider).user?.role == 'admin';
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));

    // For direct conversations: other participant is the first message author
    // that is not the current user.
    String? otherUserId(List<Message> messages) {
      for (final m in messages) {
        if (m.authorId != myId) return m.authorId;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text(
          widget.kind == 'direct' ? 'Direct Message' : (widget.kind == 'channel' ? 'Channel' : 'Group'),
          style: t.h2Style,
        ),
        actions: [
          if (widget.kind == 'direct')
            messagesAsync.maybeWhen(
              data: (messages) {
                final otherId = otherUserId(messages);
                if (otherId == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.block),
                  tooltip: 'Block user',
                  onPressed: () => _blockUser(otherId),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  "Couldn't load messages",
                  style: t.bodyStyle.copyWith(color: t.muted),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: t.bodyStyle.copyWith(color: t.muted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwn = message.authorId == myId;
                    return _MessageBubble(
                      message: message,
                      isOwn: isOwn,
                      t: t,
                      onLongPress: message.isDeleted
                          ? null
                          : () => _showMessageActions(
                                context,
                                message,
                                isOwn,
                                isAdmin,
                              ),
                    );
                  },
                );
              },
            ),
          ),
          _ComposerBar(
            controller: _composer,
            focusNode: _composerFocus,
            sending: _sending,
            t: t,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.t,
    this.onLongPress,
  });

  final Message message;
  final bool isOwn;
  final AppTokens t;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDeleted = message.isDeleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDeleted
                  ? t.surface
                  : isOwn
                      ? t.primary
                      : t.surface,
              borderRadius: BorderRadius.circular(t.cardRadius),
              border: Border.all(
                color: isDeleted ? t.border : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isDeleted && !isOwn) ...[
                  Text(
                    message.authorId,
                    style: t.miniStyle.copyWith(
                      color: t.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  isDeleted ? 'message removed' : message.body,
                  style: t.bodyStyle.copyWith(
                    color: isDeleted
                        ? t.muted
                        : isOwn
                            ? Colors.white
                            : t.text,
                    fontStyle:
                        isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (message.editedAt != null && !isDeleted) ...[
                  const SizedBox(height: 2),
                  Text(
                    'edited',
                    style: t.miniStyle.copyWith(
                      color: isOwn ? Colors.white70 : t.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Composer bar ──────────────────────────────────────────────────────────────

class _ComposerBar extends StatelessWidget {

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.t,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final AppTokens t;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: t.bodyStyle.copyWith(color: t.text),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: t.bodyStyle.copyWith(color: t.muted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: t.primary,
              onPressed: sending ? null : onSend,
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
