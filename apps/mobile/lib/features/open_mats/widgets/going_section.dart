import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/rsvp_repository.dart';
import '../models/attendee.dart';
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
          _AttendeeCard(t: t, attendees: attendees),
        ],
      ],
    );
  }
}

/// Card listing everyone going to the session, each with their name and belt.
class _AttendeeCard extends StatelessWidget {
  final AppTokens t;
  final List<Attendee> attendees;
  const _AttendeeCard({required this.t, required this.attendees});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < attendees.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.border),
            _AttendeeRow(t: t, attendee: attendees[i]),
          ],
        ],
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  final AppTokens t;
  final Attendee attendee;
  const _AttendeeRow({required this.t, required this.attendee});

  String get _beltLabel {
    final r = attendee.beltRank;
    if (r.isEmpty) return 'White Belt';
    return '${r[0].toUpperCase()}${r.substring(1)} Belt';
  }

  @override
  Widget build(BuildContext context) {
    final beltBg = t.beltBg[attendee.beltRank] ?? t.muted;
    final beltFg = t.beltFg[attendee.beltRank] ?? Colors.white;
    return InkWell(
      onTap: () => context.go('/user/${attendee.userId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: beltBg,
            backgroundImage: (attendee.avatarUrl != null && attendee.avatarUrl!.isNotEmpty)
                ? NetworkImage(attendee.avatarUrl!)
                : null,
            child: (attendee.avatarUrl == null || attendee.avatarUrl!.isEmpty)
                ? Text(
                    attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : '?',
                    style: TextStyle(color: beltFg, fontSize: 14, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attendee.name,
              style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: beltBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _beltLabel,
              style: t.miniStyle.copyWith(color: beltFg, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }
}
