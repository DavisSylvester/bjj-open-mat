import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/om_widgets.dart';

const _mySessions = [
  SessionData(id: '1', gym: 'Atos HQ',           time: '7:00 – 9:00 PM',   day: 'Today', dist: '1.2 mi', gi: GiType.gi,   exp: ExpLevel.all,          fee: 0),
  SessionData(id: '2', gym: 'Gracie Barra DTLA', time: '10:00 – 12:00 PM', day: 'Sat',   dist: '2.4 mi', gi: GiType.nogi, exp: ExpLevel.intermediate, fee: 15),
];

const _favGyms = [
  _FavGym('Atos HQ',               'San Diego · 1.2 mi'),
  _FavGym('Gracie Barra DTLA',     'Los Angeles · 2.4 mi'),
  _FavGym('10th Planet Rosemead',  'Rosemead · 4.1 mi'),
];

class _FavGym {
  final String name;
  final String sub;
  const _FavGym(this.name, this.sub);
}

const _settings = [
  _SettingRow(icon: Icons.dark_mode_rounded,       label: 'Dark theme',    trail: 'On',       danger: false),
  _SettingRow(icon: Icons.notifications_rounded,   label: 'Notifications', trail: '3 active', danger: false),
  _SettingRow(icon: Icons.settings_rounded,        label: 'Account',       trail: '',         danger: false),
  _SettingRow(icon: Icons.logout_rounded,          label: 'Sign out',      trail: '',         danger: true),
];

class _SettingRow {
  final IconData icon;
  final String label;
  final String trail;
  final bool danger;
  const _SettingRow({required this.icon, required this.label, required this.trail, required this.danger});
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: OMColors.bg,
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPad + 8)),

            // Top bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    Text('Profile', style: omH1()),
                    const Spacer(),
                    _IconBtn(
                      icon: Icons.notifications_rounded,
                      badge: true,
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: Icons.settings_rounded,
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),

            // Avatar card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        OMColors.crimson.withValues(alpha: 0.157),
                        OMColors.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: OMColors.borderHi),
                  ),
                  child: Stack(
                    children: [
                      // Decorative glow
                      Positioned(
                        top: -30, right: -30,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [OMColors.crimson.withValues(alpha: 0.2), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [OMColors.crimson, OMColors.both],
                              ),
                              boxShadow: [
                                BoxShadow(color: OMColors.bg, blurRadius: 0, spreadRadius: 3),
                                BoxShadow(color: OMColors.crimson.withValues(alpha: 0.533), blurRadius: 0, spreadRadius: 5),
                              ],
                            ),
                            child: const Center(
                              child: Text('MR', style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 28, color: Colors.white, height: 1)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mateo Reyes', style: omH1(size: 22)),
                                const SizedBox(height: 6),
                                const BeltBadge(belt: 'purple', stripes: 2, small: true),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    RichText(text: TextSpan(children: [
                                      TextSpan(text: '27', style: omNum(size: 16)),
                                      TextSpan(text: '  mats', style: omBody(color: OMColors.muted, size: 11)),
                                    ])),
                                    const SizedBox(width: 12),
                                    RichText(text: TextSpan(children: [
                                      TextSpan(text: '8', style: omNum(size: 16)),
                                      TextSpan(text: '  reviews', style: omBody(color: OMColors.muted, size: 11)),
                                    ])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // My Sessions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('My Sessions', style: omH2(size: 17)),
                    const Spacer(),
                    Text('See all', style: omEyebrow(color: OMColors.crimson)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: OMSessionCard(session: _mySessions[i], compact: true),
                ),
                childCount: _mySessions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Favorite Gyms
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('Favorite Gyms', style: omH2(size: 17)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 18,
                  child: Column(
                    children: List.generate(_favGyms.length, (i) {
                      final f = _favGyms[i];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: OMColors.faint,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.favorite_rounded, size: 16, color: OMColors.crimson),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.name, style: const TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w600, color: OMColors.text)),
                                      const SizedBox(height: 2),
                                      Text(f.sub, style: const TextStyle(fontFamily: 'Barlow', fontSize: 11, color: OMColors.muted)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 14, color: OMColors.muted),
                              ],
                            ),
                          ),
                          if (i < _favGyms.length - 1)
                            const Divider(height: 1, color: OMColors.borderDark, indent: 14, endIndent: 14),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

            // Settings
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('Settings', style: omH2(size: 17)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 18,
                  child: Column(
                    children: List.generate(_settings.length, (i) {
                      final s = _settings[i];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Row(
                              children: [
                                Icon(s.icon, size: 18, color: s.danger ? OMColors.crimson : OMColors.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w500, color: s.danger ? OMColors.crimson : OMColors.text),
                                  ),
                                ),
                                if (s.trail.isNotEmpty) ...[
                                  Text(s.trail, style: const TextStyle(fontFamily: 'Barlow', fontSize: 12, color: OMColors.muted)),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(Icons.chevron_right_rounded, size: 14, color: OMColors.muted),
                              ],
                            ),
                          ),
                          if (i < _settings.length - 1)
                            const Divider(height: 1, color: OMColors.borderDark, indent: 14, endIndent: 14),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, this.badge = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 16, color: OMColors.text),
            if (badge)
              Positioned(
                top: -1, right: -1,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: OMColors.crimson,
                    shape: BoxShape.circle,
                    border: Border.all(color: OMColors.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
