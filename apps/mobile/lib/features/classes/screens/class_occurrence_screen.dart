import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../data/class_repository.dart';
import '../models/class_attendee.dart';
import '../models/scheduled_class.dart';
import '../widgets/class_type_chip.dart';
import '../../membership/widgets/join_gym_button.dart';

/// Detail screen for a single class occurrence (classId + date).
///
/// Displays the occurrence header (title, type, time, instructor, cancelled
/// banner), an RSVP toggle, and an attendee grid with Member/Visitor badges.
///
/// Pass [scheduled] to show full header details. When null a minimal header
/// (just "Class" + date) is shown. The [scheduled] object is typically supplied
/// as GoRouter `extra`.
class ClassOccurrenceScreen extends ConsumerStatefulWidget {
  final String classId;
  final String date;
  final ScheduledClass? scheduled;

  const ClassOccurrenceScreen({
    super.key,
    required this.classId,
    required this.date,
    this.scheduled,
  });

  @override
  ConsumerState<ClassOccurrenceScreen> createState() => _ClassOccurrenceScreenState();
}

class _ClassOccurrenceScreenState extends ConsumerState<ClassOccurrenceScreen> {
  bool _rsvpBusy = false;

  bool _isAttending(List<ClassAttendee> attendees, String? userId) {
    if (userId == null) return false;
    return attendees.any((a) => a.userId == userId);
  }

  Future<void> _toggleRsvp({
    required bool currentlyAttending,
  }) async {
    if (_rsvpBusy) return;
    setState(() => _rsvpBusy = true);
    final repo = ref.read(classRepositoryProvider);
    try {
      if (currentlyAttending) {
        await repo.unrsvp(widget.classId, widget.date);
      } else {
        await repo.rsvp(widget.classId, widget.date);
      }
      ref.invalidate(classAttendeesProvider((classId: widget.classId, date: widget.date)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update RSVP: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _rsvpBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final attendeesAsync = ref.watch(
      classAttendeesProvider((classId: widget.classId, date: widget.date)),
    );
    final currentUserId = ref.watch(currentUserIdProvider);
    final scheduled = widget.scheduled;
    final isCancelled = scheduled?.isCancelled ?? false;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
        title: Text(
          scheduled?.title ?? 'Class',
          style: t.h2Style,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header card ──────────────────────────────────────────────────
          _OccurrenceHeader(scheduled: scheduled, date: widget.date, t: t),

          // ── RSVP toggle ──────────────────────────────────────────────────
          if (!isCancelled && currentUserId != null)
            attendeesAsync.when(
              loading: () => const SizedBox.shrink(),
              // ignore errors silently — attendees unavailable
              error: (err, st) => const SizedBox.shrink(),
              data: (attendees) {
                final attending = _isAttending(attendees, currentUserId);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _RsvpButton(
                    attending: attending,
                    busy: _rsvpBusy,
                    onTap: () => _toggleRsvp(currentlyAttending: attending),
                    t: t,
                  ),
                );
              },
            ),

          // ── Attendee grid ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Attendees', style: t.labelStyle.copyWith(color: t.muted, fontSize: 12)),
          ),
          Expanded(
            child: attendeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  "Couldn't load attendees",
                  style: t.bodyStyle.copyWith(color: t.muted),
                ),
              ),
              data: (attendees) {
                if (attendees.isEmpty) {
                  return Center(
                    child: Text(
                      'No one has RSVPed yet.',
                      style: t.bodyStyle.copyWith(color: t.muted),
                    ),
                  );
                }
                return GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                  children: [
                    for (final a in attendees)
                      _AttendeeCell(attendee: a, t: t),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _OccurrenceHeader extends StatelessWidget {
  final ScheduledClass? scheduled;
  final String date;
  final AppTokens t;

  const _OccurrenceHeader({
    required this.scheduled,
    required this.date,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final s = scheduled;
    if (s == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(date, style: t.miniStyle.copyWith(color: t.muted)),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.isCancelled ? t.surface.withValues(alpha: 0.5) : t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(
          color: s.isCancelled ? t.border.withValues(alpha: 0.5) : t.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + cancelled badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  s.title,
                  style: t.labelStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: s.isCancelled ? TextDecoration.lineThrough : null,
                    color: s.isCancelled ? t.muted : t.text,
                  ),
                ),
              ),
              if (s.isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.red.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'Cancelled',
                    style: t.miniStyle.copyWith(
                      color: t.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Type chip + time.
          Row(
            children: [
              ClassTypeChip(classType: s.classType, label: s.classTypeLabel),
              const SizedBox(width: 8),
              Text(
                '${s.startTime}–${s.endTime}',
                style: t.miniStyle.copyWith(color: t.muted),
              ),
            ],
          ),
          // Instructor.
          if (s.instructorName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(LucideIcons.user, size: 13, color: t.muted),
                const SizedBox(width: 4),
                Text(
                  s.instructorName!,
                  style: t.miniStyle.copyWith(color: t.muted),
                ),
              ],
            ),
          ],
          // Date.
          const SizedBox(height: 4),
          Text(date, style: t.miniStyle.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

// ── RSVP button ───────────────────────────────────────────────────────────────

class _RsvpButton extends StatelessWidget {
  final bool attending;
  final bool busy;
  final VoidCallback onTap;
  final AppTokens t;

  const _RsvpButton({
    required this.attending,
    required this.busy,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: attending ? t.primary : Colors.white,
              ),
            )
          : Icon(
              attending ? LucideIcons.x : LucideIcons.calendarCheck,
              size: 16,
            ),
      label: Text(attending ? 'Not going' : "I'm going"),
      style: ElevatedButton.styleFrom(
        backgroundColor: attending ? Colors.transparent : t.primary,
        foregroundColor: attending ? t.primary : Colors.white,
        side: attending ? BorderSide(color: t.primary) : null,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: attending ? 0 : 2,
      ),
    );
  }
}

// ── Attendee cell ─────────────────────────────────────────────────────────────

class _AttendeeCell extends StatelessWidget {
  final ClassAttendee attendee;
  final AppTokens t;

  const _AttendeeCell({required this.attendee, required this.t});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: attendee.hasProfile
          ? () => context.push('/user/${attendee.userId}')
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeltIcon(
            rank: attendee.beltRank ?? 'white',
            size: 44,
          ),
          const SizedBox(height: 6),
          Text(
            attendee.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // Member / Visitor badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: attendee.isMember
                  ? t.primary.withValues(alpha: 0.12)
                  : t.muted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: attendee.isMember
                    ? t.primary.withValues(alpha: 0.30)
                    : t.muted.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              attendee.isMember ? 'Member' : 'Visitor',
              style: t.miniStyle.copyWith(
                fontSize: 9,
                color: attendee.isMember ? t.primary : t.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
