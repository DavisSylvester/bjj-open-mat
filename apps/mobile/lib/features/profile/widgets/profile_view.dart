import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../../gyms/data/gym_repository.dart';
import '../data/profile_stats.dart';

const _kMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

String _memberSince(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${_kMonths[d.month - 1]} ${d.year}';
}

String? _formatBirthday(String? iso) {
  final d = (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  return '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}';

/// The gradient identity card: avatar + displayName + email + belt pill.
/// Shared between the main Profile screen and the public attendee profile.
Widget profileGlassHero(BuildContext context, AppTokens t, UserProfile user) {
  final displayName = user.displayName;
  final email = user.email;
  final beltRank = user.beltRank ?? 'white';
  final beltStripes = user.beltStripes ?? 0;
  final avatarUrl = user.avatarUrl;
  final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  final beltBg = t.beltBg[beltRank] ?? t.beltBg['white']!;
  final beltFg = t.beltFg[beltRank] ?? t.beltFg['white']!;
  final beltLabel = beltRank.isNotEmpty ? '${beltRank[0].toUpperCase()}${beltRank.substring(1)}' : 'White';
  final stripeLabel = beltStripes == 1 ? 'stripe' : 'stripes';

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.primary, t.both],
        ),
        boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.20), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            avatarUrl: avatarUrl,
            initial: initial,
            beltBg: beltBg,
            beltFg: beltFg,
            style: t.h1Style.copyWith(fontSize: 26),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: t.h1Style.copyWith(color: Colors.white, fontSize: 23)),
                const SizedBox(height: 3),
                Text(email, style: t.bodyStyle.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const SizedBox(height: 9),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      BeltIcon(rank: beltRank, stripes: beltStripes, size: 22),
                      const SizedBox(width: 6),
                      Text('$beltLabel · $beltStripes $stripeLabel', style: t.miniStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The white rounded metadata card: birthday/age, home gym, location, weight,
/// division, gender, member-since. Shared between the main Profile screen
/// and the public attendee profile.
Widget profileMetaCard(BuildContext context, WidgetRef ref, AppTokens t, UserProfile user) {
  final birthday = user.birthday;
  final age = (birthday != null && birthday.isNotEmpty) ? ageFromBirthday(birthday) : null;

  final homeGymId = user.homeGymId;
  final homeGymValue = (homeGymId != null && homeGymId.isNotEmpty)
      ? ref.watch(gymByIdProvider(homeGymId)).maybeWhen(data: (g) => g.name, orElse: () => '—')
      : 'Set home gym';

  // Build the metadata rows dynamically so optional fields only appear when set.
  final birthdayLabel = _formatBirthday(birthday);
  final location = [user.city, user.state].where((s) => s != null && s.trim().isNotEmpty).join(', ');
  final weightStr = user.weightValue != null ? '${user.weightValue!.round()} ${user.weightUnit ?? 'lb'}' : null;
  final metaRows = <Widget>[];
  void meta(IconData icon, String label, String value) {
    if (metaRows.isNotEmpty) metaRows.add(Divider(height: 1, color: t.border));
    metaRows.add(ProfileMetaRow(t: t, icon: icon, label: label, value: value));
  }
  void metaOpt(IconData icon, String label, String? value) {
    if (value != null && value.trim().isNotEmpty) meta(icon, label, value.trim());
  }
  if (birthdayLabel != null) {
    meta(LucideIcons.cake, 'Birthday', birthdayLabel);
    if (age != null) meta(LucideIcons.gift, 'Age', '$age yrs');
  } else {
    meta(LucideIcons.cake, 'Age', 'Add birthday');
  }
  meta(LucideIcons.mapPin, 'Home gym', homeGymValue);
  metaOpt(LucideIcons.navigation, 'Location', location);
  metaOpt(LucideIcons.dumbbell, 'Weight', weightStr);
  metaOpt(LucideIcons.award, 'Division', user.weightDivision != null ? _cap(user.weightDivision!) : null);
  metaOpt(LucideIcons.user, 'Gender', user.gender != null ? _cap(user.gender!) : null);
  meta(LucideIcons.calendarDays, 'Member since', _memberSince(user.createdAt));

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: metaRows),
    ),
  );
}

class _ProfileAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String initial;
  final Color beltBg;
  final Color beltFg;
  final TextStyle style;
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.beltBg,
    required this.beltFg,
    required this.style,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && !_failed;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: hasImage ? Colors.white.withValues(alpha: 0.20) : widget.beltBg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.60), width: 2.5),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(widget.avatarUrl!),
                fit: BoxFit.cover,
                onError: (_, _) {
                  if (mounted) setState(() => _failed = true);
                },
              )
            : null,
      ),
      child: hasImage
          ? null
          : Center(child: Text(widget.initial, style: widget.style.copyWith(color: widget.beltFg))),
    );
  }
}

class ProfileMetaRow extends StatelessWidget {
  final AppTokens t;
  final IconData icon;
  final String label;
  final String value;
  const ProfileMetaRow({super.key, required this.t, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: t.muted),
      title: Text(label, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
      trailing: Text(value, style: t.bodyStyle.copyWith(color: t.muted)),
    );
  }
}
