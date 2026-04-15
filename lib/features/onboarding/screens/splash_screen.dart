import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: StitchTokens.durationSlow);
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final auth = ref.read(authStateProvider);
      if (auth.status == AuthStatus.authenticated) {
        final isOwner = auth.user?.isGymOwner ?? false;
        context.go(isOwner ? '/owner/dashboard' : '/');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTokens.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_martial_arts, size: 80, color: StitchTokens.secondary),
              const SizedBox(height: StitchTokens.lg),
              Text(
                'BJJ Open Mat',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: StitchTokens.sm),
              Text(
                'Find your next roll',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: StitchTokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
