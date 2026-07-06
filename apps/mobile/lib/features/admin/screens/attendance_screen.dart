import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../checkins/data/attendance_repository.dart';
import '../../checkins/models/checkin.dart';
import '../../open_mats/data/rsvp_repository.dart';

final attendanceProvider = FutureProvider.family<List<CheckIn>, AttendanceQuery>((ref, query) async {
  return ref.read(attendanceRepositoryProvider).forSession(query.sessionId, date: query.date);
});

class AttendanceQuery {
  final String sessionId;
  final String date;
  const AttendanceQuery({required this.sessionId, required this.date});

  @override
  bool operator ==(Object other) => identical(this, other) || other is AttendanceQuery && sessionId == other.sessionId && date == other.date;

  @override
  int get hashCode => Object.hash(sessionId, date);
}

class AttendanceScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const AttendanceScreen({super.key, required this.sessionId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().toIso8601String().split('T').first;
  }

  AttendanceQuery get _query => AttendanceQuery(sessionId: widget.sessionId, date: _selectedDate);

  @override
  Widget build(BuildContext context) {
    final checkinsAsync = ref.watch(attendanceProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance'), actions: [
        IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.parse(_selectedDate), firstDate: DateTime(2024), lastDate: DateTime.now());
          if (picked != null) setState(() => _selectedDate = picked.toIso8601String().split('T').first);
        }),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(StitchTokens.md),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 18, color: StitchTokens.textSecondary),
              const SizedBox(width: 8),
              Text(_selectedDate, style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
          Consumer(builder: (context, watchRef, _) {
            final expected = watchRef.watch(attendeesProvider(GoingQuery(widget.sessionId, _selectedDate)));
            final page = expected.asData?.value;
            final list = page?.items ?? const [];
            final total = page?.total ?? list.length;
            if (list.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(StitchTokens.md),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expected · $total going', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list
                      .map((a) => Chip(
                            avatar: CircleAvatar(
                              backgroundColor: BeltColors.fromRank(a.beltRank),
                              child: Text(
                                a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            label: Text(a.name),
                          ))
                      .toList(),
                ),
              ]),
            );
          }),
          Expanded(
            child: checkinsAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(attendanceProvider(_query))),
              data: (checkins) {
                if (checkins.isEmpty) return const EmptyState(title: 'No check-ins', subtitle: 'Nobody checked in on this date', icon: Icons.people_outline);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: StitchTokens.md),
                  itemCount: checkins.length,
                  itemBuilder: (context, i) {
                    final c = checkins[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: BeltColors.fromRank(c.beltRank ?? 'white'),
                        child: Text(c.userName?.isNotEmpty == true ? c.userName![0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(c.userName ?? 'Unknown'),
                      subtitle: Text('${c.beltRank ?? "white"} belt • ${c.checkedInAt.split("T").last.substring(0, 5)}'),
                      trailing: c.rating != null
                          ? Row(mainAxisSize: MainAxisSize.min, children: [Text('${c.rating}'), const Icon(Icons.star, size: 16, color: StitchTokens.warning)])
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          // Summary footer
          if (checkinsAsync.hasValue)
            Container(
              padding: const EdgeInsets.all(StitchTokens.md),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text('${checkinsAsync.value!.length} check-in(s)', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
