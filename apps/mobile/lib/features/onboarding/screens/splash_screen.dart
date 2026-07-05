import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/belt_pin.dart';

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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
    final t = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // Soft brand glow so the flat-white launch has a touch of life.
          Align(
            alignment: const Alignment(0, -0.18),
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [t.primary.withValues(alpha: 0.10), t.primary.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.primary, t.both],
                      ),
                      boxShadow: [
                        BoxShadow(color: t.primary.withValues(alpha: 0.28), blurRadius: 26, offset: const Offset(0, 12)),
                      ],
                    ),
                    child: const Center(child: BeltPin.onColor(size: 66)),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'BJJ Open Mat',
                    style: t.displayStyle.copyWith(fontSize: 40, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find your next roll',
                    style: t.bodyStyle.copyWith(color: t.muted, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
