import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';

class AppBottomNav extends StatelessWidget {
  final String active; // 'home', 'search', 'schedule', 'profile'
  final void Function(String tab) onTap;

  const AppBottomNav({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final tabs = [
      (id: 'home',     icon: LucideIcons.home,     label: t.isSport ? 'Feed'  : 'Discover'),
      (id: 'search',   icon: LucideIcons.search,   label: t.isSport ? 'Find'  : 'Search'),
      (id: 'schedule', icon: LucideIcons.calendar, label: t.isSport ? 'Sched' : 'Training'),
      (id: 'profile',  icon: LucideIcons.user,     label: t.isSport ? 'Me'    : 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border(top: BorderSide(color: t.borderHi, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: tabs.map((tab) {
            final on = tab.id == active;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(tab.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: on && t.isSport ? t.surface : Colors.transparent,
                    border: on && t.isSport
                        ? Border(top: BorderSide(color: t.amber, width: 3))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!t.isSport && on)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.red,
                            shape: BoxShape.circle,
                          ),
                          margin: const EdgeInsets.only(bottom: 2),
                        ),
                      Icon(
                        tab.icon,
                        size: 20,
                        color: on ? t.text : t.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: t.miniStyle.copyWith(
                          color: on ? t.text : t.muted,
                          fontSize: t.isSport ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
