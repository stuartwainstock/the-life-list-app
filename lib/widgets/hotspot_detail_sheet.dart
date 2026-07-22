import 'package:flutter/material.dart';

import '../models/hotspot.dart';
import '../models/observation.dart';
import '../screens/species_detail_screen.dart';
import '../services/ebird_service.dart';
import '../services/settings_service.dart';
import '../theme/app_spacing.dart';
import 'skeleton.dart';
import 'species_thumbnail.dart';

/// Persistent (non-modal) hotspot sheet — peek header, drag up for species.
///
/// Anchored in the map [Stack] above the shell [NavigationBar]. Collapsed
/// state shows name + recent species count (shared sightings lookback) with
/// all-time as secondary context. Expanded checklist comes from
/// `GET /data/obs/{locId}/recent`, sorted A–Z by common name (checklist
/// scan, not live-feed taxonomic order).
///
/// Tickets: `docs/tickets/hotspot-marker-bottom-sheet.md`,
/// `docs/tickets/hotspot-species-list.md`,
/// `docs/tickets/hotspot-checklist-date-range.md`
class HotspotDetailSheet extends StatefulWidget {
  final Hotspot hotspot;
  final String apiKey;
  final double lat;
  final double lng;
  final VoidCallback onDismiss;

  static const double peekSize = 0.2;
  static const double expandedSize = 0.62;

  const HotspotDetailSheet({
    super.key,
    required this.hotspot,
    required this.apiKey,
    required this.lat,
    required this.lng,
    required this.onDismiss,
  });

  @override
  State<HotspotDetailSheet> createState() => _HotspotDetailSheetState();
}

class _HotspotDetailSheetState extends State<HotspotDetailSheet> {
  late final EbirdService _ebird = EbirdService(widget.apiKey);
  final _settings = SettingsService();

  bool _loadingSpecies = true;
  String? _speciesError;
  List<Observation> _species = const [];
  int _backDays = SettingsService.defaultSightingsBackDays;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  @override
  void didUpdateWidget(covariant HotspotDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotspot.locId != widget.hotspot.locId) {
      _loadSpecies();
    }
  }

  Future<void> _loadSpecies() async {
    setState(() {
      _loadingSpecies = true;
      _speciesError = null;
      _species = const [];
    });
    try {
      final backDays = await _settings.getSightingsBackDays();
      if (!mounted) return;
      setState(() => _backDays = backDays);

      final observations = await _ebird.recentObservationsAtLocation(
        locId: widget.hotspot.locId,
        back: backDays,
      );
      if (!mounted) return;

      // One row per species — keep the most recent observation if dupes.
      final best = <String, Observation>{};
      for (final obs in observations) {
        if (obs.speciesCode.isEmpty || obs.comName.trim().isEmpty) continue;
        final prev = best[obs.speciesCode];
        if (prev == null || obs.obsDt.isAfter(prev.obsDt)) {
          best[obs.speciesCode] = obs;
        }
      }
      final resolved = best.values.toList()
        ..sort((a, b) => a.comName.compareTo(b.comName));

      setState(() {
        _species = resolved;
        _loadingSpecies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speciesError = e.toString();
        _loadingSpecies = false;
      });
    }
  }

  void _openSpecies(Observation obs) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeciesDetailScreen(
          apiKey: widget.apiKey,
          speciesCode: obs.speciesCode,
          comName: obs.comName,
          sciName: obs.sciName,
          lat: widget.lat,
          lng: widget.lng,
        ),
      ),
    );
  }

  String get _recentCountLabel {
    final n = _species.length;
    final days = _backDays;
    if (days == 1) {
      return n == 1
          ? '1 species seen in the last 1 day'
          : '$n species seen in the last 1 day';
    }
    return n == 1
        ? '1 species seen in the last $days days'
        : '$n species seen in the last $days days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allTime = widget.hotspot.numSpeciesAllTime;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.02) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onDismiss();
          });
          return true;
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: HotspotDetailSheet.peekSize,
        minChildSize: 0,
        maxChildSize: HotspotDetailSheet.expandedSize,
        snap: true,
        snapSizes: const [
          0,
          HotspotDetailSheet.peekSize,
          HotspotDetailSheet.expandedSize,
        ],
        builder: (context, scrollController) {
          return Material(
            color: theme.scaffoldBackgroundColor,
            elevation: 3,
            shadowColor: scheme.shadow.withValues(alpha: 0.25),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              children: [
                Center(
                  child: Semantics(
                    label: 'Drag handle',
                    hint: 'Drag up for full checklist',
                    child: SizedBox(
                      width: 48,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.hotspot.locName,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_loadingSpecies)
                  Text(
                    _backDays == 1
                        ? 'Loading species from the last 1 day…'
                        : 'Loading species from the last $_backDays days…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else if (_speciesError == null)
                  Text(
                    _recentCountLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  )
                else
                  Text(
                    _backDays == 1
                        ? 'Species from the last 1 day'
                        : 'Species from the last $_backDays days',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (allTime != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$allTime recorded all-time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Drag up for full checklist',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loadingSpecies)
                  ...List.generate(
                    6,
                    (_) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(
                            width: 56,
                            height: 56,
                            borderRadius: AppRadius.md,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 160, height: 16),
                                SizedBox(height: AppSpacing.sm),
                                SkeletonBox(width: 120, height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_speciesError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Couldn’t load species list',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _loadSpecies,
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_species.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      _backDays == 1
                          ? 'No species seen here in the last 1 day.'
                          : 'No species seen here in the last $_backDays days.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._species.map(
                    (obs) => _HotspotSpeciesRow(
                      observation: obs,
                      onTap: () => _openSpecies(obs),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Matches [SightingListRow] visual language: thumb + Newsreader name + muted sci.
class _HotspotSpeciesRow extends StatelessWidget {
  final Observation observation;
  final VoidCallback onTap;

  const _HotspotSpeciesRow({
    required this.observation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final obs = observation;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpeciesThumbnail(
              key: ValueKey('hotspot-thumb-${obs.speciesCode}'),
              comName: obs.comName,
              sciName: obs.sciName,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obs.comName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (obs.sciName.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      obs.sciName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
