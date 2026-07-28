import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../../gyms/data/gym_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/class_repository.dart';
import '../models/class_attendee.dart';
import '../models/scheduled_class.dart';
import '../widgets/class_type_chip.dart';

/// Detail screen for a single class occurrence (classId + date).
///
/// Displays the occurrence header (title, type, time, instructor, cancelled
/// banner), an RSVP toggle, and an attendee grid with Member/Visitor badges.
///
/// Pass [scheduled] to show full header details. When null a minimal header
/// (just "Class" + date) is shown. The [scheduled] object is typically supplied
/// as GoRouter `extra`.
///
/// [gymId] is required to derive the manage-capability gate (used to show
/// per-occurrence manage actions for owners/coaches/admins).
class ClassOccurrenceScreen extends ConsumerStatefulWidget {
  final String classId;
  final String date;
  final ScheduledClass? scheduled;
  final String gymId;

  const ClassOccurrenceScreen({
    super.key,
    required this.classId,
    required this.date,
    this.scheduled,
    required this.gymId,
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

  // ── Manager gate ──────────────────────────────────────────────────────────

  bool _deriveCanManage(WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
    final gymOwnerId = ref
        .watch(gymByIdProvider(widget.gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);
    final isOwner = gymOwnerId != null && gymOwnerId == myId;
    // Derive from roster if available.
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final myGymRole = rosterAsync.maybeWhen(
      data: (members) => myId != null
          ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
          : null,
      orElse: () => null,
    );
    return isAdmin || isOwner || myGymRole == 'owner' || myGymRole == 'coach';
  }

  // ── Per-occurrence manage sheet ───────────────────────────────────────────

  void _showManageSheet(BuildContext context, AppTokens t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OccurrenceManageSheet(
        classId: widget.classId,
        date: widget.date,
        gymId: widget.gymId,
        t: t,
      ),
    );
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
    final canManage = _deriveCanManage(ref);

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
        actions: [
          if (canManage)
            IconButton(
              icon: Icon(LucideIcons.settings2, color: t.text),
              tooltip: 'Manage occurrence',
              onPressed: () => _showManageSheet(context, t),
            ),
        ],
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

// ── Per-occurrence manage bottom sheet ────────────────────────────────────────

class _OccurrenceManageSheet extends ConsumerStatefulWidget {
  final String classId;
  final String date;
  final String gymId;
  final AppTokens t;

  const _OccurrenceManageSheet({
    required this.classId,
    required this.date,
    required this.gymId,
    required this.t,
  });

  @override
  ConsumerState<_OccurrenceManageSheet> createState() => _OccurrenceManageSheetState();
}

class _OccurrenceManageSheetState extends ConsumerState<_OccurrenceManageSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(
        classAttendeesProvider((classId: widget.classId, date: widget.date)),
      );
      ref.invalidate(scheduleProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDate() => _run(() async {
        await ref.read(classRepositoryProvider).overrideOccurrence(
              widget.classId,
              widget.date,
              {'status': 'cancelled'},
            );
      });

  Future<void> _changeTime(BuildContext ctx) async {
    // Show a single dialog with two time pickers to avoid async context gaps.
    final result = await showDialog<({TimeOfDay start, TimeOfDay end})>(
      context: ctx,
      builder: (dialogCtx) => _TimeRangeDialog(
        initialStart: const TimeOfDay(hour: 6, minute: 0),
        initialEnd: const TimeOfDay(hour: 7, minute: 30),
        t: widget.t,
      ),
    );
    if (result == null) return;
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await _run(() async {
      await ref.read(classRepositoryProvider).overrideOccurrence(
            widget.classId,
            widget.date,
            {'startTime': fmt(result.start), 'endTime': fmt(result.end)},
          );
    });
  }

  Future<void> _changeInstructor(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: widget.t.surface,
        title: Text('Change Instructor', style: widget.t.h2Style),
        content: TextField(
          controller: ctrl,
          style: widget.t.bodyStyle.copyWith(color: widget.t.text),
          decoration: InputDecoration(
            hintText: 'Instructor name',
            hintStyle: widget.t.bodyStyle.copyWith(color: widget.t.muted),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(classRepositoryProvider).overrideOccurrence(
            widget.classId,
            widget.date,
            {'instructorName': ctrl.text.trim()},
          );
    });
  }

  Future<void> _addNote(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: widget.t.surface,
        title: Text('Add Note', style: widget.t.h2Style),
        content: TextField(
          controller: ctrl,
          style: widget.t.bodyStyle.copyWith(color: widget.t.text),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Note for this occurrence',
            hintStyle: widget.t.bodyStyle.copyWith(color: widget.t.muted),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(classRepositoryProvider).overrideOccurrence(
            widget.classId,
            widget.date,
            {'note': ctrl.text.trim()},
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Manage Occurrence', style: t.h2Style),
          const SizedBox(height: 4),
          Text(widget.date, style: t.miniStyle.copyWith(color: t.muted)),
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            _SheetAction(
              icon: LucideIcons.x,
              label: 'Cancel this date',
              color: t.red,
              onTap: _cancelDate,
              t: t,
            ),
            _SheetAction(
              icon: LucideIcons.clock,
              label: 'Change time',
              color: t.primary,
              onTap: () => _changeTime(context),
              t: t,
            ),
            _SheetAction(
              icon: LucideIcons.user,
              label: 'Change instructor',
              color: t.primary,
              onTap: () => _changeInstructor(context),
              t: t,
            ),
            _SheetAction(
              icon: LucideIcons.fileText,
              label: 'Add note',
              color: t.primary,
              onTap: () => _addNote(context),
              t: t,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Time range dialog ─────────────────────────────────────────────────────────

/// Single dialog that collects both start and end times so callers avoid
/// using BuildContext across async gaps.
class _TimeRangeDialog extends StatefulWidget {
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;
  final AppTokens t;

  const _TimeRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.t,
  });

  @override
  State<_TimeRangeDialog> createState() => _TimeRangeDialogState();
}

class _TimeRangeDialogState extends State<_TimeRangeDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start,
      helpText: 'Start time',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end,
      helpText: 'End time',
    );
    if (picked != null) setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return AlertDialog(
      backgroundColor: t.surface,
      title: Text('Change Time', style: t.h2Style),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Start', style: t.labelStyle.copyWith(color: t.muted)),
            trailing: Text(_fmt(_start), style: t.labelStyle.copyWith(color: t.text)),
            onTap: _pickStart,
          ),
          ListTile(
            title: Text('End', style: t.labelStyle.copyWith(color: t.muted)),
            trailing: Text(_fmt(_end), style: t.labelStyle.copyWith(color: t.text)),
            onTap: _pickEnd,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop((start: _start, end: _end)),
          child: const Text('Set'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AppTokens t;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(label, style: t.labelStyle.copyWith(color: t.text)),
          ],
        ),
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
