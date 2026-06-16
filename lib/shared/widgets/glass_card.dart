import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Glassmorphism card — frosted glass with inset highlight approximation.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurAmount;
  final VoidCallback? onTap;
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blurAmount = 20,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = elevated ? OMColors.surfaceHi : OMColors.surface;

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding ?? const EdgeInsets.all(OMSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xE5FFFFFF), // inset top-left highlight approx
                surfaceColor,
              ],
              stops: const [0.0, 0.35],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: OMColors.borderDark),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D141428),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x0F141428),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}

/// Gradient background for all screens — colorful radial blobs over warm cream.
class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm cream linear base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F5EF), Color(0xFFEFEBE3)],
            ),
          ),
        ),
        // Crimson blob — top-left (18% 8%, 0.22 opacity)
        Positioned(
          left: -80,
          top: -120,
          child: _RadialBlob(size: 420, color: const Color(0x38E94560)),
        ),
        // Purple blob — bottom-right (88% 78%, 0.20 opacity)
        Positioned(
          right: -80,
          bottom: -80,
          child: _RadialBlob(size: 380, color: const Color(0x339C27B0)),
        ),
        // Teal blob — center-right (72% 26%, 0.16 opacity)
        Positioned(
          right: 10,
          top: 160,
          child: _RadialBlob(size: 320, color: const Color(0x2916C79A)),
        ),
        // Blue blob — bottom-left (8% 92%, 0.18 opacity)
        Positioned(
          left: -60,
          bottom: -60,
          child: _RadialBlob(size: 360, color: const Color(0x2E2196F3)),
        ),
        child,
      ],
    );
  }
}

class _RadialBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _RadialBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
