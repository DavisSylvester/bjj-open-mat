import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/rating/app_rating_service.dart';
import '../../profile/data/profile_stats.dart';

class CheckinSuccessScreen extends ConsumerStatefulWidget {
  final String openMatId;
  final String? locationStatus;
  const CheckinSuccessScreen({super.key, required this.openMatId, this.locationStatus});

  @override
  ConsumerState<CheckinSuccessScreen> createState() => _CheckinSuccessScreenState();
}

class _CheckinSuccessScreenState extends ConsumerState<CheckinSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _controller = AnimationController(vsync: this, duration: StitchTokens.durationSlow);
    _scale = CurvedAnimation(parent: _controller, curve: StitchTokens.curveBounce);
    _controller.forward();

    // Fire after the frame so the success screen is on-screen first; a prompt
    // over a half-built screen reads as a glitch.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final stats = await ref.read(myStatsProvider.future);
        if (!mounted) return;
        await ref.read(appRatingServiceProvider).maybePrompt(stats.checkIns);
      } catch (_) {
        // Offline or otherwise unavailable — a missed prompt is cheaper than
        // surfacing an error over the success screen.
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _checkInId(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.queryParameters['checkInId'];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkInId = _checkInId(context);
    return Scaffold(
      backgroundColor: StitchTokens.accent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(StitchTokens.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: const Icon(Icons.check_circle, size: 120, color: Colors.white),
                ),
                const SizedBox(height: StitchTokens.lg),
                Text(
                  'You\'re checked in!',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: StitchTokens.sm),
                Text(
                  'Have a great roll. Leave a review after your session.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                if (widget.locationStatus != null) ...[
                  const SizedBox(height: StitchTokens.sm),
                  Text(
                    widget.locationStatus == 'verified'
                        ? '📍 Location verified'
                        : widget.locationStatus == 'far'
                            ? '📍 Far from the gym'
                            : '📍 Location off',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: StitchTokens.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: StitchTokens.accent),
                    onPressed: () => context.go('/'),
                    child: const Text('Back to Discover'),
                  ),
                ),
                const SizedBox(height: StitchTokens.md),
                TextButton(
                  onPressed: () => context.go(
                    checkInId != null
                        ? '/open-mat/${widget.openMatId}/review?checkInId=${Uri.encodeComponent(checkInId)}'
                        : '/open-mat/${widget.openMatId}/review',
                  ),
                  child: const Text('Leave a Review Now', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
