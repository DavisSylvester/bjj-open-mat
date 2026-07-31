import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../data/membership_repository.dart';

/// Injectable provider for the current authenticated user id.
/// Override in tests to avoid depending on the full AuthStateNotifier.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).user?.id;
});

/// The mutually exclusive states the action button can be in. Modelled as an
/// enum rather than a `disabled` flag so "signed out" and "roster failed"
/// cannot collapse into the same silent grey button again.
enum JoinButtonState { signedOut, error, member, nonMember }

/// Displays the current member count and a Join / Leave button for [gymId].
///
/// - Shows "N members" as a label above the action button.
/// - Shows **Sign in to join** when no user is authenticated — tappable, and
///   routes to `/login`.
/// - Shows **Retry** when the roster request fails — tappable, and
///   invalidates the roster provider to retry.
/// - Shows **Join** when the signed-in user is not in the roster.
/// - Shows **Leave** when the signed-in user is already in the roster.
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
        state: JoinButtonState.nonMember,
        loading: true,
        onTap: null,
        t: t,
      ),
      error: (err, st) => _MembershipLayout(
        memberCount: 0,
        state: JoinButtonState.error,
        loading: false,
        onTap: () => ref.invalidate(rosterProvider(widget.gymId)),
        t: t,
      ),
      data: (roster) {
        final count = roster.length;
        if (!isAuthed) {
          return _MembershipLayout(
            memberCount: count,
            state: JoinButtonState.signedOut,
            loading: false,
            onTap: () => context.push('/login'),
            t: t,
          );
        }
        final isMember = roster.any((m) => m.userId == myId);
        return _MembershipLayout(
          memberCount: count,
          state: isMember ? JoinButtonState.member : JoinButtonState.nonMember,
          loading: _busy,
          onTap: _busy ? null : () => _toggle(isMember: isMember),
          t: t,
        );
      },
    );
  }
}

class _MembershipLayout extends StatelessWidget {
  final int memberCount;
  final JoinButtonState state;
  final bool loading;
  final VoidCallback? onTap;
  final AppTokens? t;

  const _MembershipLayout({
    required this.memberCount,
    required this.state,
    required this.loading,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final label = memberCount == 1 ? '1 member' : '$memberCount members';
    final isMember = state == JoinButtonState.member;
    final primaryColor = t?.primary ?? Theme.of(context).colorScheme.primary;

    final String buttonLabel;
    final IconData icon;
    switch (state) {
      case JoinButtonState.signedOut:
        buttonLabel = 'Sign in to join';
        icon = LucideIcons.logIn;
      case JoinButtonState.error:
        buttonLabel = 'Retry';
        icon = LucideIcons.refreshCw;
      case JoinButtonState.member:
        buttonLabel = 'Leave';
        icon = LucideIcons.logOut;
      case JoinButtonState.nonMember:
        buttonLabel = 'Join';
        icon = LucideIcons.userPlus;
    }

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
