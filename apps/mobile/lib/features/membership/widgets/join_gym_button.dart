import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/membership_repository.dart';

/// Injectable provider for the current authenticated user id.
/// Override in tests to avoid depending on the full AuthStateNotifier.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).user?.id;
});

/// Displays the current member count and a Join / Leave button for [gymId].
///
/// - Shows "N members" as a label above the action button.
/// - Shows **Join** when the signed-in user is not in the roster.
/// - Shows **Leave** when the signed-in user is already in the roster.
/// - Both the label and button are disabled while the roster is loading.
/// - The button is disabled (but visible) when no user is authenticated.
class JoinGymButton extends ConsumerStatefulWidget {
  final String gymId;

  const JoinGymButton({super.key, required this.gymId});

  @override
  ConsumerState<JoinGymButton> createState() => _JoinGymButtonState();
}

class _JoinGymButtonState extends ConsumerState<JoinGymButton> {
  bool _busy = false;

  Future<void> _toggle({required bool isMember}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(membershipRepositoryProvider);
    try {
      if (isMember) {
        await repo.leave(widget.gymId);
      } else {
        await repo.join(widget.gymId);
      }
      ref.invalidate(rosterProvider(widget.gymId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update membership")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final myId = ref.watch(currentUserIdProvider);
    final isAuthed = myId != null;

    final AppTokens? t = Theme.of(context).extension<AppTokens>();

    return rosterAsync.when(
      loading: () => _MembershipLayout(
        memberCount: 0,
        isMember: false,
        loading: true,
        disabled: true,
        onTap: null,
        t: t,
      ),
      error: (err, st) => _MembershipLayout(
        memberCount: 0,
        isMember: false,
        loading: false,
        disabled: true,
        onTap: null,
        t: t,
      ),
      data: (roster) {
        final count = roster.length;
        final isMember = isAuthed && roster.any((m) => m.userId == myId);

        return _MembershipLayout(
          memberCount: count,
          isMember: isMember,
          loading: _busy,
          disabled: !isAuthed || _busy,
          onTap: (!isAuthed || _busy) ? null : () => _toggle(isMember: isMember),
          t: t,
        );
      },
    );
  }
}

class _MembershipLayout extends StatelessWidget {
  final int memberCount;
  final bool isMember;
  final bool loading;
  final bool disabled;
  final VoidCallback? onTap;
  final AppTokens? t;

  const _MembershipLayout({
    required this.memberCount,
    required this.isMember,
    required this.loading,
    required this.disabled,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final label = memberCount == 1 ? '1 member' : '$memberCount members';
    final buttonLabel = isMember ? 'Leave' : 'Join';
    final icon = isMember ? LucideIcons.logOut : LucideIcons.userPlus;
    final primaryColor = t?.primary ?? Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.users, size: 14, color: t?.muted ?? Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: (t?.miniStyle ?? Theme.of(context).textTheme.bodySmall)
                  ?.copyWith(color: t?.muted ?? Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onTap,
          icon: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isMember ? primaryColor : Colors.white,
                  ),
                )
              : Icon(icon, size: 16),
          label: Text(buttonLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: isMember ? Colors.transparent : primaryColor,
            foregroundColor: isMember ? primaryColor : Colors.white,
            side: isMember ? BorderSide(color: primaryColor) : null,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: isMember ? 0 : 2,
          ),
        ),
      ],
    );
  }
}
