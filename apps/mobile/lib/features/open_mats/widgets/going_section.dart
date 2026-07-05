import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/rsvp_repository.dart';
import '../models/open_mat.dart';

/// "Going" (RSVP) control + public attendee list for one session date.
class GoingSection extends ConsumerStatefulWidget {
  final OpenMat mat;
  final AppTokens t;
  const GoingSection({super.key, required this.mat, required this.t});

  @override
  ConsumerState<GoingSection> createState() => _GoingSectionState();
}

class _GoingSectionState extends ConsumerState<GoingSection> {
  late final String _sessionDate = widget.mat.nextSessionDate();
  bool _busy = false;

  GoingQuery get _query => GoingQuery(widget.mat.id, _sessionDate);

  Future<void> _toggle(bool currentlyGoing) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(rsvpRepositoryProvider);
    try {
      if (currentlyGoing) {
        await repo.cancel(widget.mat.id, _sessionDate);
      } else {
        HapticFeedback.mediumImpact();
        await repo.rsvp(widget.mat.id, _sessionDate);
      }
      ref.invalidate(attendeesProvider(_query));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update RSVP")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final myId = ref.watch(authStateProvider).user?.id;
    final async = ref.watch(attendeesProvider(_query));
    final attendees = async.asData?.value ?? const [];
    final amGoing = myId != null && attendees.any((a) => a.userId == myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(LucideIcons.users, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Text('Going', style: t.h2Style.copyWith(fontSize: 14)),
          const Spacer(),
          Text('${attendees.length}', style: t.numStyle.copyWith(fontSize: 16, color: t.primary)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _toggle(amGoing),
            icon: Icon(amGoing ? LucideIcons.check : LucideIcons.plus, size: 18),
            label: Text(amGoing ? "You're going" : "I'm going"),
            style: OutlinedButton.styleFrom(
              foregroundColor: amGoing ? Colors.white : t.primary,
              backgroundColor: amGoing ? t.primary : Colors.transparent,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: t.primary),
            ),
          ),
        ),
        if (attendees.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attendees
                .map((a) => GestureDetector(
                      onTap: () => context.go('/user/${a.userId}'),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundColor: t.beltBg[a.beltRank] ?? t.muted,
                          child: Text(
                            a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        label: Text(a.name, style: t.miniStyle),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
