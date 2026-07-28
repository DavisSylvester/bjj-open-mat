import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/class_repository.dart';
import '../models/scheduled_class.dart';
import '../widgets/class_type_chip.dart';

/// Weekly timetable screen for a single gym's scheduled classes.
///
/// Accepts an optional [initialWeek] for deterministic testing; defaults to
/// [DateTime.now()]. The visible window is always Monday–Sunday.
class ClassScheduleScreen extends ConsumerStatefulWidget {
  final String gymId;
  final DateTime? initialWeek;

  const ClassScheduleScreen({
    super.key,
    required this.gymId,
    this.initialWeek,
  });

  @override
  ConsumerState<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends ConsumerState<ClassScheduleScreen> {
  late DateTime _weekAnchor;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialWeek ?? DateTime.now();
    _weekAnchor = _monday(seed);
  }

  // Returns the Monday of the week containing [date].
  DateTime _monday(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final diff = (utc.weekday - DateTime.monday) % 7;
    return utc.subtract(Duration(days: diff));
  }

  DateTime get _sunday => _weekAnchor.add(const Duration(days: 6));

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _prevWeek() => setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7)));

  bool _deriveCanManage(WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
    final gymOwnerId = ref
        .watch(gymByIdProvider(widget.gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);
    final isOwner = gymOwnerId != null && gymOwnerId == myId;
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final myGymRole = rosterAsync.maybeWhen(
      data: (members) => myId != null
          ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
          : null,
      orElse: () => null,
    );
    return isAdmin || isOwner || myGymRole == 'owner' || myGymRole == 'coach';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final from = _isoDate(_weekAnchor);
    final to = _isoDate(_sunday);
    final schedAsync = ref.watch(
      scheduleProvider((gymId: widget.gymId, from: from, to: to)),
    );
    final canManage = _deriveCanManage(ref);

    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => context.push(
                '/gym/${widget.gymId}/class-edit',
              ),
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add class',
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('Class Schedule', style: t.h2Style),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _WeekPager(
            monday: _weekAnchor,
            sunday: _sunday,
            onPrev: _prevWeek,
            onNext: _nextWeek,
            t: t,
          ),
        ),
      ),
      body: schedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't load schedule", style: t.bodyStyle.copyWith(color: t.muted)),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Text('No classes this week.', style: t.bodyStyle.copyWith(color: t.muted)),
            );
          }
          final grouped = _groupByDate(classes);
          final days = grouped.keys.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              return _DaySection(
                date: day,
                classes: grouped[day]!,
                gymId: widget.gymId,
                t: t,
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<ScheduledClass>> _groupByDate(List<ScheduledClass> classes) {
    final Map<String, List<ScheduledClass>> map = {};
    for (final c in classes) {
      map.putIfAbsent(c.date, () => []).add(c);
    }
    return map;
  }
}

// ── Week pager header ─────────────────────────────────────────────────────────

class _WeekPager extends StatelessWidget {
  final DateTime monday;
  final DateTime sunday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final AppTokens t;

  const _WeekPager({
    required this.monday,
    required this.sunday,
    required this.onPrev,
    required this.onNext,
    required this.t,
  });

  String _fmt(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft, color: t.text),
            onPressed: onPrev,
          ),
          Text(
            '${_fmt(monday)} – ${_fmt(sunday)}',
            style: t.labelStyle.copyWith(color: t.text, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: Icon(LucideIcons.chevronRight, color: t.text),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Day section ───────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final String date;
  final List<ScheduledClass> classes;
  final String gymId;
  final AppTokens t;

  const _DaySection({
    required this.date,
    required this.classes,
    required this.gymId,
    required this.t,
  });

  String _dayLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final d = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(_dayLabel(date), style: t.labelStyle.copyWith(color: t.muted, fontSize: 12)),
        ),
        for (final cls in classes)
          _ClassRow(cls: cls, gymId: gymId, t: t),
      ],
    );
  }
}

// ── Class row ─────────────────────────────────────────────────────────────────

class _ClassRow extends StatelessWidget {
  final ScheduledClass cls;
  final String gymId;
  final AppTokens t;

  const _ClassRow({required this.cls, required this.gymId, required this.t});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/gym/$gymId/schedule/occurrence?classId=${cls.classId}&date=${cls.date}',
        extra: cls,
      ),
      borderRadius: BorderRadius.circular(t.cardRadius),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cls.isCancelled ? t.surface.withValues(alpha: 0.5) : t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(
          color: cls.isCancelled ? t.border.withValues(alpha: 0.5) : t.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cls.title,
                  style: t.labelStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: cls.isCancelled ? TextDecoration.lineThrough : null,
                    color: cls.isCancelled ? t.muted : t.text,
                  ),
                ),
              ),
              if (cls.isCancelled)
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
          Row(
            children: [
              ClassTypeChip(classType: cls.classType, label: cls.classTypeLabel),
              const SizedBox(width: 8),
              Text(
                '${cls.startTime}–${cls.endTime}',
                style: t.miniStyle.copyWith(color: t.muted),
              ),
            ],
          ),
          if (cls.instructorName != null || cls.goingCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (cls.instructorName != null) ...[
                  Icon(LucideIcons.user, size: 13, color: t.muted),
                  const SizedBox(width: 4),
                  Text(
                    cls.instructorName!,
                    style: t.miniStyle.copyWith(color: t.muted),
                  ),
                  const SizedBox(width: 12),
                ],
                if (cls.goingCount > 0) ...[
                  Icon(LucideIcons.users, size: 13, color: t.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${cls.goingCount} going',
                    style: t.miniStyle.copyWith(color: t.muted),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}
