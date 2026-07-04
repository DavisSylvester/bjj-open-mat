import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen(authStateProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        if (next.user?.role == null || (next.user?.role?.isEmpty ?? true)) {
          context.go('/role-select');
        } else {
          context.go((next.user?.isGymOwner ?? false) ? '/owner/dashboard' : '/');
        }
      }
    });

    return Scaffold(
      backgroundColor: StitchTokens.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StitchTokens.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(Icons.sports_martial_arts, size: 72, color: StitchTokens.secondary),
              const SizedBox(height: StitchTokens.lg),
              Text(
                'BJJ Open Mat',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: StitchTokens.sm),
              Text(
                'Discover open mats near you',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: StitchTokens.textSecondary),
              ),
              const Spacer(flex: 3),

              // Google login
              _SocialLoginButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                backgroundColor: Colors.white,
                foregroundColor: StitchTokens.primary,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithGoogle();
                },
              ),
              const SizedBox(height: StitchTokens.md),

              // Apple login
              _SocialLoginButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithApple();
                },
              ),
              const SizedBox(height: StitchTokens.md),

              // Email / password (Auth0 Universal Login)
              _SocialLoginButton(
                label: 'Continue with email',
                icon: Icons.mail_outline,
                backgroundColor: StitchTokens.secondary,
                foregroundColor: Colors.white,
                isLoading: isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authStateProvider.notifier).loginWithEmail();
                },
              ),

              if (authState.error != null) ...[
                const SizedBox(height: StitchTokens.md),
                Text(
                  authState.error!,
                  style: TextStyle(color: StitchTokens.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),
              Text(
                'No passwords. Just tap and train.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: StitchTokens.textSecondary),
              ),
              const SizedBox(height: StitchTokens.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor))
            : Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StitchTokens.radiusMd)),
        ),
      ),
    );
  }
}
