import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';

/// Practitioner bottom-nav tab ids, in branch/index order.
const List<String> kPracTabs = ['home', 'search', 'profile', 'report'];

class AppBottomNav extends StatelessWidget {
  final String active; // 'home', 'search', 'profile', 'report'
  final void Function(String tab) onTap;
  final VoidCallback? onAdd;

  const AppBottomNav({super.key, required this.active, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final tabs = [
      (id: 'home',    icon: LucideIcons.home,   label: 'Home'),
      (id: 'search',  icon: LucideIcons.search, label: 'Find'),
      (id: 'profile', icon: LucideIcons.user,   label: 'Profile'),
      (id: 'report',  icon: LucideIcons.flag,   label: 'Report'),
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
            children: [
              // Left two tabs
              ...tabs.sublist(0, 2).map((tab) {
                final on = tab.id == active;
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
              }),
              // Center "+" action button — not a selectable tab
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: t.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: t.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
              // Right two tabs
              ...tabs.sublist(2).map((tab) {
                final on = tab.id == active;
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
              }),
            ],
          ),
        ),
      ),
    );
  }
}
