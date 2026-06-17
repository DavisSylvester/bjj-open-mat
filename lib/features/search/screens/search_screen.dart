import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';

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
    );
  }

  Widget _buildGlass(AppTokens t) {
    final filters = [
      (id: 'gi', label: 'Gi', color: t.gi),
      (id: 'nogi', label: 'No-Gi', color: t.noGi),
      (id: 'both', label: 'Gi · No-Gi', color: t.both),
      (id: 'free', label: 'Free', color: t.green),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Find a Mat', style: t.h1Style),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                    child: Icon(LucideIcons.mapPin, size: 18, color: t.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 18, color: t.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: t.h2Style.copyWith(fontSize: 15, color: t.text),
                      decoration: InputDecoration(
                        hintText: 'Los Angeles, CA',
                        hintStyle: t.h2Style.copyWith(fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.locateFixed, size: 13, color: t.primary),
                      const SizedBox(width: 4),
                      Text('GPS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 10)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final f = filters[i];
                final on = _giFilter == f.id;
                return GestureDetector(
                  onTap: () => setState(() => _giFilter = f.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? f.color.withValues(alpha: 0.09) : t.bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: on ? f.color.withValues(alpha: 0.33) : t.borderHi,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      if (on) ...[
                        Icon(LucideIcons.check, size: 13, color: f.color),
                        const SizedBox(width: 5),
                      ],
                      Text(f.label, style: t.miniStyle.copyWith(
                        color: on ? f.color : t.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WHEN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(LucideIcons.calendar, size: 15, color: t.primary),
                    const SizedBox(width: 6),
                    Text('This Weekend', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('WITHIN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                    const Spacer(),
                    Text('${_distance.toStringAsFixed(0)} mi', style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
                  ]),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: t.primary,
                      inactiveTrackColor: t.panel,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 6,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: SizedBox(
                      height: 20,
                      child: Slider(
                        value: _distance,
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _distance = v),
                      ),
                    ),
                  ),
                ]),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${_filtered.length}', style: t.h2Style.copyWith(color: t.primary)),
                  TextSpan(text: ' Sessions', style: t.h2Style),
                ])),
                const Spacer(),
                Text('Map view', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
    );
  }
}
