import 'package:flutter/material.dart';

import '../models/hotspot.dart';
import '../theme/app_spacing.dart';

/// Persistent (non-modal) peek sheet for a selected map hotspot.
///
/// Anchored to the bottom of the map [Stack] so it sits above the shell
/// [NavigationBar] and never covers tab labels. Only as tall as its
/// content, so pan/zoom on the rest of the map stays free. Swipe down to
/// dismiss; tapping another marker swaps [hotspot] in place.
///
/// Ticket: `docs/tickets/hotspot-marker-bottom-sheet.md`
class HotspotDetailSheet extends StatefulWidget {
  final Hotspot hotspot;
  final VoidCallback onDismiss;

  const HotspotDetailSheet({
    super.key,
    required this.hotspot,
    required this.onDismiss,
  });

  @override
  State<HotspotDetailSheet> createState() => _HotspotDetailSheetState();
}

class _HotspotDetailSheetState extends State<HotspotDetailSheet> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 120);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final shouldDismiss =
        _dragOffset > 48 || (details.primaryVelocity ?? 0) > 400;
    if (shouldDismiss) {
      widget.onDismiss();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: GestureDetector(
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            elevation: 3,
            shadowColor: scheme.shadow.withValues(alpha: 0.25),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  Text(
                    widget.hotspot.locName,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (widget.hotspot.numSpeciesAllTime != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${widget.hotspot.numSpeciesAllTime} species recorded all-time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
