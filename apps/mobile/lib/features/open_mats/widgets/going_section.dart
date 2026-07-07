import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../data/rsvp_repository.dart';
import '../models/attendee.dart';
import '../models/open_mat.dart';

const int _kPageLimit = 12;

/// "Going" (RSVP) control + public attendee grid for one session date.
class GoingSection extends ConsumerStatefulWidget {
  final OpenMat mat;
  final AppTokens t;
  const GoingSection({super.key, required this.mat, required this.t});

  @override
  ConsumerState<GoingSection> createState() => _GoingSectionState();
}

class _GoingSectionState extends ConsumerState<GoingSection> {
  late final String _sessionDate = widget.mat.nextSessionDate();
  int _page = 1;
  bool _busy = false;

  GoingQuery get _query => GoingQuery(widget.mat.id, _sessionDate, _page);

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
    final page = async.asData?.value;
    final attendees = page?.items ?? const <Attendee>[];
    final total = page?.total ?? 0;
    final amGoing = myId != null && attendees.any((a) => a.userId == myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(LucideIcons.users, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Text('Going', style: t.h2Style.copyWith(fontSize: 14)),
          const Spacer(),
          Text('$total', style: t.numStyle.copyWith(fontSize: 16, color: t.primary)),
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
          _AttendeeGrid(t: t, attendees: attendees),
          _Pager(
            t: t,
            page: _page,
            total: total,
            onPrev: _page > 1 ? () => setState(() => _page -= 1) : null,
            onNext: _page < _pageCount(total) ? () => setState(() => _page += 1) : null,
          ),
        ],
      ],
    );
  }

  static int _pageCount(int total) => total <= 0 ? 1 : (total / _kPageLimit).ceil();
}

/// A responsive 3-column grid of belt icons + names for the current page.
class _AttendeeGrid extends StatelessWidget {
  final AppTokens t;
  final List<Attendee> attendees;
  const _AttendeeGrid({required this.t, required this.attendees});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
        children: [
          for (final a in attendees) _AttendeeCell(t: t, attendee: a),
        ],
      ),
    );
  }
}

class _AttendeeCell extends StatelessWidget {
  final AppTokens t;
  final Attendee attendee;
  const _AttendeeCell({required this.t, required this.attendee});

  @override
  Widget build(BuildContext context) {
    // Placeholder attendees (no resolvable user document) must not be linked —
    // /user/:id 404s for them. A null onTap leaves the cell inert.
    return InkWell(
      onTap: attendee.hasProfile ? () => context.push('/user/${attendee.userId}') : null,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeltIcon(rank: attendee.beltRank, stripes: attendee.beltStripes, size: 44),
          const SizedBox(height: 6),
          Text(
            attendee.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// "Page X of N" with prev/next chevrons, disabled at the bounds.
class _Pager extends StatelessWidget {
  final AppTokens t;
  final int page;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({
    required this.t,
    required this.page,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = math.max(1, (total / _kPageLimit).ceil());
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
            color: t.primary,
            disabledColor: t.faint,
          ),
          Text('Page $page of $pageCount', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          IconButton(
            onPressed: onNext,
            icon: const Icon(LucideIcons.chevronRight, size: 20),
            color: t.primary,
            disabledColor: t.faint,
          ),
        ],
      ),
    );
  }
}
