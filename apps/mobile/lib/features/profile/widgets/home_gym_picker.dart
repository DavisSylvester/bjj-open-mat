import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/models/gym.dart';

/// Modal searchable gym list. Returns the picked Gym, or null if dismissed.
Future<Gym?> showHomeGymPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Gym>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HomeGymPickerSheet(),
  );
}

class _HomeGymPickerSheet extends ConsumerStatefulWidget {
  const _HomeGymPickerSheet();

  @override
  ConsumerState<_HomeGymPickerSheet> createState() => _HomeGymPickerSheetState();
}

class _HomeGymPickerSheetState extends ConsumerState<_HomeGymPickerSheet> {
  List<Gym> _allGyms = const [];
  List<Gym> _results = const [];
  bool _loading = false;

  Future<void> _loadGyms() async {
    setState(() {
      _loading = true;
    });
    final gyms = await ref.read(gymRepositoryProvider).searchAll('');
    if (mounted) {
      setState(() {
        _allGyms = gyms;
        _results = gyms;
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String q) {
    setState(() {
      _results = q.isEmpty
          ? _allGyms
          : _allGyms.where((g) => g.name.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search gyms',
                  filled: true,
                  fillColor: t.surfaceHi,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_results[i].name, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context).pop(_results[i]),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
