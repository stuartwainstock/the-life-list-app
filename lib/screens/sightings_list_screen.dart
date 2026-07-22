import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:geolocator/geolocator.dart';
import '../models/observation.dart';
import '../services/ebird_list_cache.dart';
import '../services/ebird_service.dart';
import '../services/ebird_taxonomy_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/sighting_list_row.dart';
import '../widgets/skeleton_sighting_row.dart';
import 'species_detail_screen.dart';
import 'species_search_screen.dart';

/// Nearby sightings — the app's primary screen (GoBird's main loop).
///
/// ## UX shape (why it looks like this)
/// - **SegmentedButton** for All vs Notable — one control, two states
///   (design-principles: prefer Material 3 over twin ChoiceChips).
/// - **Rows** emphasize species name; location / relative time / count are
///   subordinate and icon-anchored (same language as species detail).
/// - **Family grouping** mirrors how birders and field guides think
///   (contacts-list sticky headers, not alphabetical A–Z). Sort uses
///   eBird `taxonOrder`, not name.
///
/// ## Sticky headers — important implementation note
/// Do **not** use multiple `SliverPersistentHeader(pinned: true)` siblings.
/// Each pins independently and they stack. We use `flutter_sticky_header`'s
/// [SliverStickyHeader] so the next family header *pushes* the previous
/// one off (contacts-list behavior). See
/// `docs/tickets/sticky-header-stacking-bugfix.md`.
///
/// ## Taxonomy loading
/// Observations and taxonomy load in parallel. Until taxonomy resolves,
/// we render the same restyled **flat** list so first launch / offline
/// never blocks on a huge taxonomy download. When the lookup arrives,
/// we regroup in place.
///
/// ## Search radius
/// Tune icon → bottom sheet slider (1–20 km). Label updates while dragging;
/// persist + refetch run on release (`Slider.onChangeEnd`) so we don't
/// hammer eBird mid-drag. Default 7 km via [SettingsService].
///
/// ## Offline / stale-while-revalidate
/// [EbirdListCache] paints the last matching disk payload immediately, then
/// refreshes in the background. Fetch failure with cache keeps the list and
/// shows a muted "couldn't refresh" line — see
/// `docs/tickets/offline-caching.md`.
///
/// ## Species search
/// Search icon opens [SpeciesSearchScreen] over the full taxonomy cache
/// (`docs/tickets/species-search.md`).
///
/// Ticket: `docs/tickets/sightings-list-redesign.md`,
/// `docs/tickets/sightings-radius-toggle.md`
class SightingsListScreen extends StatefulWidget {
  final String apiKey;
  const SightingsListScreen({super.key, required this.apiKey});

  @override
  State<SightingsListScreen> createState() => _SightingsListScreenState();
}

class _SightingsListScreenState extends State<SightingsListScreen> {
  final _locationService = LocationService();
  final _taxonomy = EbirdTaxonomyService();
  final _settings = SettingsService();
  final _listCache = EbirdListCache();
  late final EbirdService _ebird = EbirdService(widget.apiKey);

  bool _loading = true;
  String? _error;
  /// True when we're showing disk cache because the network refresh failed.
  bool _showingStale = false;
  DateTime? _cacheFetchedAt;
  Position? _position;
  double? _lat;
  double? _lng;
  List<Observation> _all = [];
  List<Observation> _notable = [];
  bool _showNotableOnly = false;
  int _distKm = SettingsService.defaultSightingsRadiusKm;
  int _backDays = SettingsService.defaultSightingsBackDays;

  /// Null while taxonomy is loading/unavailable — triggers flat-list fallback.
  Map<String, TaxonomyEntry>? _taxonomyLookup;

  bool get _hasListContent => _all.isNotEmpty || _notable.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      _settings.getSightingsRadiusKm(),
      _settings.getSightingsBackDays(),
    ]);
    if (!mounted) return;
    setState(() {
      _distKm = results[0];
      _backDays = results[1];
    });
    await Future.wait([_load(), _loadTaxonomy()]);
  }

  void _applySightingsCache({
    required List<Observation> all,
    required List<Observation> notable,
    required double lat,
    required double lng,
    required DateTime fetchedAt,
    Position? position,
  }) {
    _all = all;
    _notable = _mostRecentPerSpecies(notable);
    _lat = lat;
    _lng = lng;
    if (position != null) _position = position;
    _cacheFetchedAt = fetchedAt;
    _loading = false;
    _error = null;
  }

  Future<void> _load({bool keepContent = false}) async {
    // Skeleton for initial load / filter change when nothing to show yet;
    // pull-to-refresh keeps rows (loading-states-polish).
    setState(() {
      if (!keepContent && !_hasListContent) _loading = true;
      _error = null;
      _showingStale = false;
    });

    // Instant paint from last success when radius + lookback still match
    // (before GPS). If either filter changed, drop previous rows so we
    // never flash the wrong cache key (offline-caching acceptance).
    if (!keepContent) {
      final last = await _listCache.readLastSightings();
      if (!mounted) return;
      if (last != null &&
          last.distKm == _distKm &&
          last.backDays == _backDays) {
        setState(() {
          _applySightingsCache(
            all: last.all,
            notable: last.notable,
            lat: last.lat,
            lng: last.lng,
            fetchedAt: last.fetchedAt,
          );
        });
      } else if (_hasListContent) {
        setState(() {
          _all = [];
          _notable = [];
          _loading = true;
          _showingStale = false;
          _cacheFetchedAt = null;
        });
      }
    }

    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;

      // Param-keyed cache for this GPS + radius + lookback.
      final cachedAll = await _listCache.readObservations(
        notable: false,
        lat: pos.latitude,
        lng: pos.longitude,
        distKm: _distKm,
        backDays: _backDays,
      );
      final cachedNotable = await _listCache.readObservations(
        notable: true,
        lat: pos.latitude,
        lng: pos.longitude,
        distKm: _distKm,
        backDays: _backDays,
      );
      if (!mounted) return;
      if (cachedAll != null) {
        setState(() {
          _applySightingsCache(
            all: cachedAll.items,
            notable: cachedNotable?.items ?? const [],
            lat: pos.latitude,
            lng: pos.longitude,
            fetchedAt: cachedAll.fetchedAt,
            position: pos,
          );
        });
      } else {
        setState(() {
          _position = pos;
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }

      final results = await Future.wait([
        _ebird.nearbyObservations(
          lat: pos.latitude,
          lng: pos.longitude,
          distKm: _distKm,
          back: _backDays,
        ),
        _ebird.nearbyNotableObservations(
          lat: pos.latitude,
          lng: pos.longitude,
          distKm: _distKm,
          back: _backDays,
        ),
      ]);
      if (!mounted) return;

      final all = results[0];
      final notableRaw = results[1];
      final fetchedAt = DateTime.now().toUtc();

      await Future.wait([
        _listCache.writeObservations(
          notable: false,
          lat: pos.latitude,
          lng: pos.longitude,
          distKm: _distKm,
          backDays: _backDays,
          items: all,
          fetchedAt: fetchedAt,
        ),
        _listCache.writeObservations(
          notable: true,
          lat: pos.latitude,
          lng: pos.longitude,
          distKm: _distKm,
          backDays: _backDays,
          items: notableRaw,
          fetchedAt: fetchedAt,
        ),
        _listCache.writeLastSightings(
          CachedSightingsBundle(
            fetchedAt: fetchedAt,
            lat: pos.latitude,
            lng: pos.longitude,
            distKm: _distKm,
            backDays: _backDays,
            all: all,
            notable: notableRaw,
          ),
        ),
      ]);
      if (!mounted) return;

      setState(() {
        _applySightingsCache(
          all: all,
          notable: notableRaw,
          lat: pos.latitude,
          lng: pos.longitude,
          fetchedAt: fetchedAt,
          position: pos,
        );
        _showingStale = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_hasListContent) {
        setState(() {
          _showingStale = true;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final sliderTheme = SliderTheme.of(sheetContext).copyWith(
          activeTrackColor: scheme.primary,
          thumbColor: scheme.primary,
          overlayColor: scheme.primary.withValues(alpha: 0.12),
          inactiveTrackColor: scheme.primary.withValues(alpha: 0.24),
          valueIndicatorColor: scheme.primary,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Search within $_distKm km',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: _distKm.toDouble(),
                        min: SettingsService.minSightingsRadiusKm.toDouble(),
                        max: SettingsService.maxSightingsRadiusKm.toDouble(),
                        divisions: SettingsService.maxSightingsRadiusKm -
                            SettingsService.minSightingsRadiusKm,
                        label: '$_distKm km',
                        onChanged: (value) {
                          final km = value.round();
                          setSheetState(() {});
                          setState(() => _distKm = km);
                        },
                        onChangeEnd: (value) async {
                          final km = value.round();
                          await _settings.setSightingsRadiusKm(km);
                          if (!mounted) return;
                          _load();
                        },
                      ),
                    ),
                    Text(
                      '1–${SettingsService.maxSightingsRadiusKm} km',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      _backDays == 1
                          ? 'Showing sightings from the last 1 day'
                          : 'Showing sightings from the last $_backDays days',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: _backDays.toDouble(),
                        min: SettingsService.minSightingsBackDays.toDouble(),
                        max: SettingsService.maxSightingsBackDays.toDouble(),
                        divisions: SettingsService.maxSightingsBackDays -
                            SettingsService.minSightingsBackDays,
                        label: '$_backDays days',
                        onChanged: (value) {
                          final days = value.round();
                          setSheetState(() {});
                          setState(() => _backDays = days);
                        },
                        onChangeEnd: (value) async {
                          final days = value.round();
                          await _settings.setSightingsBackDays(days);
                          if (!mounted) return;
                          _load();
                        },
                      ),
                    ),
                    Text(
                      '1–${SettingsService.maxSightingsBackDays} days',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Keeps the newest observation for each speciesCode.
  List<Observation> _mostRecentPerSpecies(List<Observation> list) {
    final best = <String, Observation>{};
    for (final obs in list) {
      final prev = best[obs.speciesCode];
      if (prev == null || obs.obsDt.isAfter(prev.obsDt)) {
        best[obs.speciesCode] = obs;
      }
    }
    return best.values.toList();
  }

  Future<void> _loadTaxonomy() async {
    // Fire-and-forget relative to sightings: never gate the UI on this.
    final lookup = await _taxonomy.getLookup(widget.apiKey);
    if (!mounted || lookup == null || lookup.isEmpty) return;
    setState(() => _taxonomyLookup = lookup);
  }

  void _openDetail(Observation obs) {
    final lat = _lat ?? _position?.latitude;
    final lng = _lng ?? _position?.longitude;
    if (lat == null || lng == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SpeciesDetailScreen(
        apiKey: widget.apiKey,
        speciesCode: obs.speciesCode,
        comName: obs.comName,
        sciName: obs.sciName,
        lat: lat,
        lng: lng,
      ),
    ));
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeciesSearchScreen(
          apiKey: widget.apiKey,
          lat: _lat ?? _position?.latitude,
          lng: _lng ?? _position?.longitude,
          initialLookup: _taxonomyLookup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _showNotableOnly ? _notable : _all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Sightings'),
        toolbarHeight: AppTheme.toolbarHeightOf(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search species',
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: _openFiltersSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh sightings',
            onPressed: _loading ? null : () => _load(keepContent: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              // Material 3 segmented control — replaces two independent chips
              // so the filter reads as one mutually exclusive choice.
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      'All species',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      'Notable / rare',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {_showNotableOnly},
                onSelectionChanged: (selected) {
                  setState(() => _showNotableOnly = selected.first);
                },
                // Checkmark + fill — selection is not color-only (WCAG 1.4.1).
              ),
            ),
          ),
          if (_showingStale && _cacheFetchedAt != null)
            _StaleCacheBanner(fetchedAt: _cacheFetchedAt!),
          Expanded(child: _buildBody(list)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Observation> list) {
    if (_loading) {
      return const SightingsListSkeleton();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(child: Text('No sightings reported nearby recently.'));
    }

    final lookup = _taxonomyLookup;
    // Fallback: taxonomy not ready yet (or fetch failed with no cache).
    // Same row widget as the grouped path — only structure differs.
    if (lookup == null) {
      return RefreshIndicator(
        onRefresh: () => _load(keepContent: true),
        child: ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final obs = list[i];
            return SightingListRow(
              // Keys include species so filter toggles don't reuse the wrong
              // thumbnail State (ListView recycling bug we hit early on).
              key: ValueKey('${obs.speciesCode}-${obs.locId}-${obs.obsDt}'),
              observation: obs,
              onTap: () => _openDetail(obs),
            );
          },
        ),
      );
    }

    final groups = _groupByFamily(list, lookup);
    return RefreshIndicator(
      onRefresh: () => _load(keepContent: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // One SliverStickyHeader per family: header is pushed away by the
          // next section (not independently pinned — that stacks headers).
          for (final group in groups)
            SliverStickyHeader(
              header: _FamilyHeader(
                familyName: group.familyName,
                count: group.items.length,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final obs = group.items[i];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SightingListRow(
                          key: ValueKey(
                            '${obs.speciesCode}-${obs.locId}-${obs.obsDt}',
                          ),
                          observation: obs,
                          onTap: () => _openDetail(obs),
                        ),
                        if (i < group.items.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  },
                  childCount: group.items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bucket by familyComName; order families and members by taxonOrder.
  /// Unmatched speciesCodes land in "Other" (stale cache / new taxa).
  List<_FamilyGroup> _groupByFamily(
    List<Observation> list,
    Map<String, TaxonomyEntry> lookup,
  ) {
    final buckets = <String, List<Observation>>{};
    final familyOrder = <String, int>{};

    for (final obs in list) {
      final entry = lookup[obs.speciesCode];
      final family = entry?.familyComName ?? 'Other';
      buckets.putIfAbsent(family, () => []).add(obs);
      final order = entry?.taxonOrder ?? 999999;
      final prev = familyOrder[family];
      if (prev == null || order < prev) {
        familyOrder[family] = order;
      }
    }

    // Sort species within each family by taxonOrder, then name.
    for (final items in buckets.values) {
      items.sort((a, b) {
        final oa = lookup[a.speciesCode]?.taxonOrder ?? 999999;
        final ob = lookup[b.speciesCode]?.taxonOrder ?? 999999;
        final byOrder = oa.compareTo(ob);
        if (byOrder != 0) return byOrder;
        return a.comName.compareTo(b.comName);
      });
    }

    final families = buckets.keys.toList()
      ..sort((a, b) {
        // Keep "Other" last.
        if (a == 'Other' && b != 'Other') return 1;
        if (b == 'Other' && a != 'Other') return -1;
        final oa = familyOrder[a] ?? 999999;
        final ob = familyOrder[b] ?? 999999;
        final byOrder = oa.compareTo(ob);
        if (byOrder != 0) return byOrder;
        return a.compareTo(b);
      });

    return [
      for (final family in families)
        _FamilyGroup(familyName: family, items: buckets[family]!),
    ];
  }
}

class _FamilyGroup {
  final String familyName;
  final List<Observation> items;

  _FamilyGroup({required this.familyName, required this.items});
}

class _StaleCacheBanner extends StatelessWidget {
  final DateTime fetchedAt;

  const _StaleCacheBanner({required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = formatRelativeTime(fetchedAt);

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          'Showing results from $when — couldn’t refresh',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Sticky family section header.
///
/// Visual language matches species-detail section eyebrows: brand green
/// label + count pill. Behavior comes from [SliverStickyHeader] parent —
/// this widget itself is just a fixed-height bar.
class _FamilyHeader extends StatelessWidget {
  final String familyName;
  final int count;

  const _FamilyHeader({
    required this.familyName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  familyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
