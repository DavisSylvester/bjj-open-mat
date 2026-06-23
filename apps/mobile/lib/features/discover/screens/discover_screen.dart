import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/ticker_strip.dart';

final _stubSessions = [
  SessionRowData(id: 'om-atos-fri', gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0, isLive: true),
  SessionRowData(id: 'om-renzo-fri', gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Mon', distance: '2.4 mi', fee: 15),
  SessionRowData(id: 'om-10p-sat', gymName: '10th Planet Rosemead', giType: 'both', expLevel: 'adv', time: '8:30 PM', day: 'Mon', distance: '3.1 mi', fee: 20),
  SessionRowData(id: 'om-gb-pas', gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Tue', distance: '4.5 mi', fee: 0),
  SessionRowData(id: 'om-ckm', gymName: 'CKM Jiu-Jitsu', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Tue', distance: '5.0 mi', fee: 10),
];

final _tickerItems = [
  TickerItem(time: '7:00 PM', gym: 'Atos HQ', giType: 'gi'),
  TickerItem(time: '8:00 PM', gym: 'Renzo Westwood', giType: 'nogi'),
  TickerItem(time: '8:30 PM', gym: '10P Rosemead', giType: 'both'),
];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
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
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red),
              const SizedBox(width: 8),
              Text('Open Mat', style: t.displayStyle.copyWith(fontSize: 22)),
              const SizedBox(width: 8),
              Text('LA / Mon Jun 2', style: t.miniStyle),
              const Spacer(),
              Icon(LucideIcons.bell, size: 18, color: t.muted),
              const SizedBox(width: 12),
              Icon(LucideIcons.search, size: 18, color: t.muted),
            ]),
          ),
          TickerStrip(items: _tickerItems),
          Container(
            color: const Color(0xFF080F26),
            child: Row(children: [
              _StatCell(label: 'Open Now', value: '3', color: t.green, t: t),
              _StatCell(label: 'Tonight', value: '12', color: t.amber, t: t),
              _StatCell(label: 'This Wk', value: '47', color: t.text, t: t),
              _StatCell(label: 'Nearest', value: '1.2mi', color: t.gi, t: t),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 10)),
              Text('Live Feed', style: t.h2Style.copyWith(fontSize: 15)),
              const Spacer(),
              Text('All Sessions', style: t.miniStyle),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _stubSessions.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(
                session: _stubSessions[i],
                onTap: () => context.go('/open-mat/${_stubSessions[i].id}'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Greeting header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good evening, Mateo', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Find your roll', style: t.h1Style.copyWith(fontSize: 26)),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.primary, t.both],
                      ),
                    ),
                    child: Center(child: Text('MR', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                  ),
                ],
              ),
            ),
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: t.panel,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(LucideIcons.search, size: 18, color: t.muted),
                      const SizedBox(width: 10),
                      Text('Search gyms or area', style: t.bodyStyle.copyWith(color: t.muted, fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: t.primary.withValues(alpha: 0.27), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(LucideIcons.sliders, size: 20, color: Colors.white),
                ),
              ]),
            ),
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TONIGHT & TOMORROW', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text('Open Mats', style: t.h2Style),
                      ],
                    ),
                  ),
                  Text('See all', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            // Vertical session cards
            ...List.generate(_stubSessions.length, (i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: SessionRow(
                  session: _stubSessions[i],
                  onTap: () => context.go('/open-mat/${_stubSessions[i].id}'),
                ),
              ),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppTokens t;
  const _StatCell({required this.label, required this.value, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: t.border, width: 1))),
      child: Column(children: [
        Text(value, style: t.numStyle.copyWith(fontSize: 20, color: color)),
        const SizedBox(height: 2),
        Text(label, style: t.miniStyle.copyWith(fontSize: 8)),
      ]),
    ));
  }
}
