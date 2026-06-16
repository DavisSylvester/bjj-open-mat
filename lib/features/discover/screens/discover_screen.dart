import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/ticker_strip.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

final _stubSessions = [
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0, isLive: true),
  SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Mon', distance: '2.4 mi', fee: 15),
  SessionRowData(gymName: '10th Planet Rosemead', giType: 'both', expLevel: 'adv', time: '8:30 PM', day: 'Mon', distance: '3.1 mi', fee: 20),
  SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Tue', distance: '4.5 mi', fee: 0),
  SessionRowData(gymName: 'CKM Jiu-Jitsu', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Tue', distance: '5.0 mi', fee: 10),
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
  String _filter = 'today';

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
          Container(
            height: 200,
            color: const Color(0xFF080F26),
            child: Stack(children: [
              CustomPaint(painter: _GridPainter(t), size: Size.infinite),
              ...[
                (x: 0.24, y: 0.36, gi: 'gi',   label: 'ATOS'),
                (x: 0.56, y: 0.28, gi: 'both', label: '10P'),
                (x: 0.78, y: 0.52, gi: 'nogi', label: 'RNZ'),
                (x: 0.38, y: 0.70, gi: 'gi',   label: 'GB'),
              ].map((p) => Positioned(
                left: MediaQuery.of(context).size.width * p.x - 20,
                top: 200 * p.y - 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  color: t.giColor(p.gi),
                  child: Text(p.label, style: t.miniStyle.copyWith(color: Colors.white, fontSize: 11)),
                ),
              )),
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
              itemBuilder: (_, i) => SessionRow(session: _stubSessions[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'home', onTap: (_) {}),
    );
  }

  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.64, -0.84),
              radius: 1.0,
              colors: [Color(0x38E94560), Colors.transparent],
            ),
          ),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Container(
            color: const Color(0xFFDDE8F0),
            child: CustomPaint(painter: _LightMapPainter(), size: Size.infinite),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Text('Open Mat', style: t.h1Style.copyWith(fontSize: 26)),
                const Spacer(),
                Icon(LucideIcons.bell, size: 20, color: t.muted),
                const SizedBox(width: 12),
                Icon(LucideIcons.search, size: 20, color: t.muted),
              ]),
            ),
            Expanded(
              child: DraggableScrollableSheet(
                initialChildSize: 0.56,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                snap: true,
                builder: (context, ctrl) => Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(color: t.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24)],
                  ),
                  child: Column(children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: t.muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(children: [
                        _FilterChip(label: 'Today', active: _filter == 'today', onTap: () => setState(() => _filter = 'today'), t: t),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'This Week', active: _filter == 'week', onTap: () => setState(() => _filter = 'week'), t: t),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Gi', active: false, onTap: () {}, t: t),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'No-Gi', active: false, onTap: () {}, t: t),
                      ]),
                    ),
                    Expanded(
                      child: ListView.separated(
                        controller: ctrl,
                        itemCount: _stubSessions.length,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => SessionRow(session: _stubSessions[i]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: AppBottomNav(active: 'home', onTap: (_) {}),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppTokens t;
  const _FilterChip({required this.label, required this.active, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? t.red : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.red : t.border),
        ),
        child: Text(label, style: t.miniStyle.copyWith(color: active ? Colors.white : t.text, fontSize: 12)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final AppTokens t;
  _GridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = t.border..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint); }
    for (double y = 0; y < size.height; y += 40) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); }
    final road = Paint()..color = t.border..strokeWidth = 8;
    canvas.drawLine(const Offset(-20, 70), Offset(size.width + 20, 110), road);
    canvas.drawLine(const Offset(-20, 200), Offset(size.width + 20, 170), road);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LightMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8EFF5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final road = Paint()..color = Colors.white..strokeWidth = 8;
    canvas.drawLine(Offset(-20, size.height * 0.3), Offset(size.width + 20, size.height * 0.45), road);
    canvas.drawLine(Offset(-20, size.height * 0.7), Offset(size.width + 20, size.height * 0.6), road);
    canvas.drawLine(Offset(size.width * 0.3, -20), Offset(size.width * 0.28, size.height + 20), road);
    canvas.drawLine(Offset(size.width * 0.65, -20), Offset(size.width * 0.75, size.height + 20), road);
  }

  @override
  bool shouldRepaint(_) => false;
}
