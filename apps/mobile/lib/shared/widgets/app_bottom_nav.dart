import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';

/// Practitioner bottom-nav tab ids, in branch/index order.
const List<String> kPracTabs = ['home', 'search', 'profile', 'report', 'messages'];

class AppBottomNav extends StatelessWidget {
  final String active; // 'home', 'search', 'profile', 'report', 'messages'
  final void Function(String tab) onTap;
  final VoidCallback? onAdd;

  /// Aggregate unread message count for the Messages tab badge.
  /// When > 0 a small badge is rendered over the Messages icon.
  /// Capped at 99+ in display. 0 means no badge.
  final int messagesUnreadCount;

  const AppBottomNav({
    super.key,
    required this.active,
    required this.onTap,
    this.onAdd,
    this.messagesUnreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final tabs = [
      (id: 'home',     icon: LucideIcons.home,        label: 'Home'),
      (id: 'search',   icon: LucideIcons.search,      label: 'Find'),
      (id: 'profile',  icon: LucideIcons.user,        label: 'Profile'),
      (id: 'report',   icon: LucideIcons.flag,        label: 'Report'),
      (id: 'messages', icon: LucideIcons.messageCircle, label: 'Messages'),
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
              // Right three tabs (profile, report, messages)
              ...tabs.sublist(2).map((tab) {
                final on = tab.id == active;
                final showBadge = tab.id == 'messages' && messagesUnreadCount > 0;
                final badgeLabel = messagesUnreadCount > 99 ? '99+' : messagesUnreadCount.toString();
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
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(tab.icon, size: 22, color: on ? t.primary : t.faint),
                              if (showBadge)
                                Positioned(
                                  right: -8,
                                  top: -6,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: t.primary,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: t.bg, width: 1.5),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: t.miniStyle.copyWith(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
