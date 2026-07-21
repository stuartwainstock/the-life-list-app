import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Soft pulse used by skeleton placeholders.
///
/// Uses [ColorScheme] surface/outlineVariant (hairline) — never raw grey —
/// so light/dark brand surfaces stay consistent.
class SkeletonPulse extends StatefulWidget {
  final Widget child;

  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Filled rounded rect that pulses — building block for row/hero skeletons.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Mix surfaceContainerHighest with outlineVariant (hairline) so the
    // block reads as brand paper, not Material grey.
    final fill = Color.alphaBlend(
      scheme.outlineVariant.withValues(alpha: 0.55),
      scheme.surfaceContainerHighest,
    );

    return SkeletonPulse(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Brand-accent progress indicator for overlay / non-skeleton loads.
class BrandProgressIndicator extends StatelessWidget {
  final double? strokeWidth;

  const BrandProgressIndicator({super.key, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: Theme.of(context).colorScheme.primary,
      strokeWidth: strokeWidth ?? 4,
    );
  }
}
