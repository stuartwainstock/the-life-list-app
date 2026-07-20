import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/relative_time.dart';
import 'species_thumbnail.dart';

/// Shared sightings-list row used by the nearby list (flat + grouped).
///
/// Visual contract (keep in sync with species-detail sighting rows):
/// - Species name is the loudest element
/// - Location is pin-anchored and muted
/// - Time is relative (`formatRelativeTime`); count is further de-emphasized
/// - No trailing chevron — the whole row is the tap target
///
/// Ticket: `docs/tickets/sightings-list-redesign.md`
class SightingListRow extends StatelessWidget {
  final Observation observation;
  final VoidCallback? onTap;

  const SightingListRow({
    super.key,
    required this.observation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final obs = observation;
    final relative = formatRelativeTime(obs.obsDt);
    final count = obs.howMany;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpeciesThumbnail(
              key: ValueKey('thumb-${obs.speciesCode}'),
              comName: obs.comName,
              sciName: obs.sciName,
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          obs.locName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: relative,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (count != null)
                            TextSpan(
                              text: ' · $count seen',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
