import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_hairline.dart';
import 'skeleton.dart';

/// Species-detail loading layout: hero slab + identity + description + feed.
///
/// Common/scientific names are already known from navigation, so they render
/// as real text to avoid a jump when load finishes. Wiki extract and
/// sightings use skeletons sized to the loaded layout.
///
/// Ticket: `docs/tickets/loading-states-polish.md`
class SpeciesDetailSkeleton extends StatelessWidget {
  final String comName;
  final String sciName;

  /// Matches [_HeroAppBar] expandedHeight.
  static const double heroHeight = 280;

  const SpeciesDetailSkeleton({
    super.key,
    required this.comName,
    required this.sciName,
  });

  /// Identity + skeleton description/feed — used under a real photo [Hero]
  /// while the Commons gallery loads
  /// (`docs/tickets/species-photo-hero-transition.md`).
  static Widget bodyBelowHero({
    required BuildContext context,
    required String comName,
    required String sciName,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        20,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (sciName.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              sciName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const AppHairline(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 220, height: 14),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppHairline(),
          const SizedBox(height: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 180, height: 14),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < 3; i++) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: 20,
                        height: 20,
                        borderRadius: AppRadius.sm,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                              width: double.infinity,
                              height: 14,
                            ),
                            SizedBox(height: AppSpacing.xs),
                            SkeletonBox(width: 100, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: SkeletonBox(
                    height: heroHeight,
                    borderRadius: 0,
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: AppSpacing.sm,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: bodyBelowHero(
            context: context,
            comName: comName,
            sciName: sciName,
          ),
        ),
      ],
    );
  }
}
