import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _giFilter = 'all';
  double _distance = 10.0;
  final _searchCtrl = TextEditingController();

  final _sessions = [
    SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0),
    SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Mon', distance: '2.4 mi', fee: 15),
    SessionRowData(gymName: '10th Planet Rosemead', giType: 'both', expLevel: 'adv', time: '8:30 PM', day: 'Mon', distance: '3.1 mi', fee: 20),
    SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Tue', distance: '4.5 mi', fee: 0),
    SessionRowData(gymName: 'CKM Jiu-Jitsu', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Tue', distance: '5.0 mi', fee: 10),
    SessionRowData(gymName: 'Alliance Atlanta', giType: 'gi', expLevel: 'int', time: '6:00 PM', day: 'Wed', distance: '6.2 mi', fee: 0),
    SessionRowData(gymName: 'B-Team Jiu-Jitsu', giType: 'both', expLevel: 'adv', time: '9:00 PM', day: 'Wed', distance: '7.1 mi', fee: 25),
    SessionRowData(gymName: 'Marcelo Garcia NY', giType: 'both', expLevel: 'all', time: '7:00 PM', day: 'Thu', distance: '8.0 mi', fee: 30),
  ];

  List<SessionRowData> get _filtered {
    return _sessions.where((s) {
      if (_giFilter != 'all' && s.giType != _giFilter) return false;
      final dist = double.tryParse(s.distance.split(' ').first) ?? 0;
      if (dist > _distance) return false;
      if (_searchCtrl.text.isNotEmpty &&
          !s.gymName.toLowerCase().contains(_searchCtrl.text.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _buildSport(t) : _buildGlass(t);
  }

  Widget _buildSport(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 22, color: t.red),
                const SizedBox(width: 8),
                Text('Find Sessions', style: t.h1Style.copyWith(fontSize: 20)),
              ]),
              const SizedBox(height: 10),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.border),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  Icon(LucideIcons.search, size: 16, color: t.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: t.bodyStyle,
                      decoration: InputDecoration(
                        hintText: 'Gym, location…',
                        hintStyle: t.miniStyle.copyWith(fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: ['All', 'Gi', 'No-Gi', 'Both'].map((label) {
                final id = label == 'All' ? 'all' : label == 'No-Gi' ? 'nogi' : label.toLowerCase();
                final active = _giFilter == id;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _giFilter = id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? t.surfaceHi : Colors.transparent,
                      border: active ? Border(top: BorderSide(color: t.amber, width: 3)) : null,
                    ),
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: t.miniStyle.copyWith(color: active ? t.text : t.muted, fontSize: 11),
                    ),
                  ),
                ));
              }).toList()),
            ]),
          ),
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              Text('Distance', style: t.miniStyle.copyWith(fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: t.red,
                    inactiveTrackColor: t.border,
                    thumbColor: t.red,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _distance,
                    min: 1,
                    max: 50,
                    onChanged: (v) => setState(() => _distance = v),
                  ),
                ),
              ),
              Text('${_distance.toStringAsFixed(0)} mi',
                  style: t.numStyle.copyWith(fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              Container(width: 4, height: 16, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Text('Results', style: t.h2Style.copyWith(fontSize: 13)),
              const Spacer(),
              Text('${_filtered.length} sessions', style: t.miniStyle),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'search', onTap: (_) {}),
    );
  }

  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(children: [
              Text('Search', style: t.h1Style),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: t.surfaceHi,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 16, color: t.muted),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search gyms, neighborhoods…',
                      hintStyle: t.miniStyle.copyWith(fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )),
                ]),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: ['All', 'Gi', 'No-Gi', 'Both', 'Free', 'Nearby'].map((label) {
                  final id = label == 'All' ? 'all' : label == 'No-Gi' ? 'nogi' : label.toLowerCase();
                  final active = _giFilter == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _giFilter = id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? t.red : t.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? t.red : t.border),
                        ),
                        child: Text(label, style: t.miniStyle.copyWith(color: active ? Colors.white : t.text, fontSize: 12)),
                      ),
                    ),
                  );
                }).toList()),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'search', onTap: (_) {}),
    );
  }
}
