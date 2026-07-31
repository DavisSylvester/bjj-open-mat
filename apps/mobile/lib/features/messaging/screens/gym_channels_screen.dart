import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../data/messaging_repository.dart';
import '../models/conversation.dart';

/// A simple list of gym channels, each tapping to its conversation thread.
class GymChannelsScreen extends ConsumerWidget {
  final String gymId;

  const GymChannelsScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final channelsAsync = ref.watch(gymChannelsProvider(gymId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Channels', style: t.h2Style),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/messages/new?gymId=$gymId'),
        child: const Icon(Icons.add),
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load channels",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (channels) => channels.isEmpty
            ? Center(
                child: Text(
                  'No channels yet.',
                  style: t.bodyStyle.copyWith(color: t.muted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: channels.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return _ChannelTile(channel: channel, t: t, gymId: gymId);
                },
              ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Conversation channel;
  final AppTokens t;
  final String gymId;

  const _ChannelTile({
    required this.channel,
    required this.t,
    required this.gymId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/messages/${channel.id}',
        extra: <String, dynamic>{
          'gymId': gymId,
          'kind': 'channel',
        },
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Icon(Icons.tag, size: 18, color: t.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channel.title ?? channel.id,
                style: t.bodyStyle.copyWith(
                  color: t.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: t.muted),
          ],
        ),
      ),
    );
  }
}
