import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'skeleton.dart';

/// Placeholder shaped like [SightingListRow] — 56px thumb + two text lines.
///
/// Ticket: `docs/tickets/loading-states-polish.md`
class SkeletonSightingRow extends StatelessWidget {
  const SkeletonSightingRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: 56,
            height: 56,
            borderRadius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 160, height: 16),
                const SizedBox(height: AppSpacing.sm),
                const SkeletonBox(width: double.infinity, height: 12),
                const SizedBox(height: AppSpacing.xs),
                SkeletonBox(
                  width: MediaQuery.sizeOf(context).width * 0.35,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enough skeleton rows to fill a typical phone viewport.
class SightingsListSkeleton extends StatelessWidget {
  final int rowCount;

  const SightingsListSkeleton({super.key, this.rowCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rowCount,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const SkeletonSightingRow(),
    );
  }
}
