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
      (id: 'home',     icon: LucideIcons.home,     label: t.isSport ? 'Feed'  : 'Home'),
      (id: 'search',   icon: LucideIcons.search,   label: t.isSport ? 'Find'  : 'Find'),
      (id: 'schedule', icon: LucideIcons.calendar, label: t.isSport ? 'Sched' : 'Schedule'),
      (id: 'profile',  icon: LucideIcons.user,     label: t.isSport ? 'Me'    : 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Row(
            children: tabs.map((tab) {
              final on = tab.id == active;
              if (t.isSport) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(tab.id),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: on ? t.surface : Colors.transparent,
                        border: on ? Border(top: BorderSide(color: t.amber, width: 3)) : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 20, color: on ? t.text : t.muted),
                          const SizedBox(height: 3),
                          Text(tab.label, style: t.miniStyle.copyWith(color: on ? t.text : t.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              // Glass / Minimal Vibrant pill style
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(tab.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                    decoration: BoxDecoration(
                      color: on ? t.primary.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon, size: 22, color: on ? t.primary : t.faint),
                        const SizedBox(height: 3),
                        Text(tab.label, style: t.miniStyle.copyWith(color: on ? t.primary : t.faint, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
