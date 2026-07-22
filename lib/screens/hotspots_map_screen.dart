import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/hotspot.dart';
import '../services/ebird_list_cache.dart';
import '../services/ebird_service.dart';
import '../services/location_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/hotspot_detail_sheet.dart';
import '../widgets/skeleton.dart';

/// Map of nearby eBird hotspots, using OpenStreetMap tiles via flutter_map
/// so no Google Maps API key / billing setup is required.
///
/// Hotspots use the same stale-while-revalidate disk cache as sightings
/// (`docs/tickets/offline-caching.md`). Default search radius matches
/// [EbirdService.nearbyHotspots] (25 km) — sightings radius toggle is
/// intentionally separate.
///
/// Marker detail uses a persistent peek sheet ([HotspotDetailSheet]) inside
/// this screen's body — never `showModalBottomSheet`, so it stays above the
/// shell nav and the map remains interactive. Dense hotspot pins cluster via
/// [MarkerClusterLayerWidget] (`docs/tickets/hotspot-marker-clustering.md`).
class HotspotsMapScreen extends StatefulWidget {
  final String apiKey;
  const HotspotsMapScreen({super.key, required this.apiKey});

  @override
  State<HotspotsMapScreen> createState() => _HotspotsMapScreenState();
}

class _HotspotsMapScreenState extends State<HotspotsMapScreen> {
  final _locationService = LocationService();
  final _listCache = EbirdListCache();
  late final EbirdService _ebird = EbirdService(widget.apiKey);
  final _mapController = MapController();

  /// Matches [EbirdService.nearbyHotspots] default.
  static const _distKm = 25;
  static const _defaultZoom = 11.0;

  bool _loading = true;
  String? _error;
  bool _showingStale = false;
  DateTime? _cacheFetchedAt;
  List<Hotspot> _hotspots = [];
  LatLng? _center;
  Hotspot? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    final center = _center;
    if (center == null) return;
    _mapController.move(center, _defaultZoom);
  }

  void _onHotspotMarkerTap(Marker marker) {
    final key = marker.key;
    if (key is! ValueKey<String>) return;
    Hotspot? match;
    for (final h in _hotspots) {
      if (h.locId == key.value) {
        match = h;
        break;
      }
    }
    if (match == null) return;
    setState(() => _selected = match);
  }

  List<Marker> _hotspotMarkers(ColorScheme scheme) {
    return [
      for (final h in _hotspots)
        Marker(
          key: ValueKey(h.locId),
          point: LatLng(h.lat, h.lng),
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              _selected?.locId == h.locId
                  ? Icons.location_on
                  : Icons.location_on_outlined,
              color: _selected?.locId == h.locId
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
              size: _selected?.locId == h.locId ? 36 : 28,
              semanticLabel: _selected?.locId == h.locId
                  ? 'Selected hotspot ${h.locName}'
                  : 'Hotspot ${h.locName}',
            ),
          ),
        ),
    ];
  }

  Future<void> _load() async {
    setState(() {
      if (_hotspots.isEmpty) _loading = true;
      _error = null;
      _showingStale = false;
    });

    // Paint last hotspots immediately (map center from cached lat/lng).
    final last = await _listCache.readLastHotspots();
    if (!mounted) return;
    if (last != null) {
      setState(() {
        _center = LatLng(last.lat, last.lng);
        _hotspots = last.items;
        _cacheFetchedAt = last.fetchedAt;
        _loading = false;
      });
    }

    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
      });

      final keyed = await _listCache.readHotspots(
        lat: pos.latitude,
        lng: pos.longitude,
        distKm: _distKm,
      );
      if (!mounted) return;
      if (keyed != null) {
        setState(() {
          _hotspots = keyed.items;
          _cacheFetchedAt = keyed.fetchedAt;
          _loading = false;
        });
      }

      final hotspots = await _ebird.nearbyHotspots(
        lat: pos.latitude,
        lng: pos.longitude,
        distKm: _distKm,
      );
      if (!mounted) return;

      final fetchedAt = DateTime.now().toUtc();
      final bundle = CachedHotspots(
        fetchedAt: fetchedAt,
        lat: pos.latitude,
        lng: pos.longitude,
        distKm: _distKm,
        items: hotspots,
      );
      await Future.wait([
        _listCache.writeHotspots(
          lat: pos.latitude,
          lng: pos.longitude,
          distKm: _distKm,
          items: hotspots,
          fetchedAt: fetchedAt,
        ),
        _listCache.writeLastHotspots(bundle),
      ]);
      if (!mounted) return;

      setState(() {
        _hotspots = hotspots;
        _cacheFetchedAt = fetchedAt;
        _loading = false;
        _showingStale = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_hotspots.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hotspots'),
        toolbarHeight: AppTheme.toolbarHeightOf(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh hotspots',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Location failed before we could place the map, and no cache center.
    if (_error != null && _center == null) {
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

    // Still resolving location — nothing to pin yet.
    if (_center == null) {
      return const Center(child: BrandProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center!,
            initialZoom: _defaultZoom,
            // Empty-map tap dismisses the persistent sheet (not modal).
            onTap: (_, __) {
              if (_selected != null) {
                setState(() => _selected = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.thelifelist.app',
              // Explicit provider so the bounded BuiltInMapCachingProvider
              // from [MapTileCache.ensureConfigured] is the one in use.
              tileProvider: NetworkTileProvider(
                cachingProvider:
                    BuiltInMapCachingProvider.getOrCreateInstance(),
              ),
            ),
            MarkerLayer(
              markers: [
                // Keep "you are here" outside clustering so it never
                // collapses into a hotspot badge.
                Marker(
                  point: _center!,
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: const _UserLocationDot(),
                ),
              ],
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                size: const Size(40, 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(50),
                maxZoom: 17,
                zoomToBoundsOnClick: true,
                // Don't recenter the camera when opening a hotspot sheet —
                // the peek sheet already anchors attention.
                centerMarkerOnClick: false,
                showPolygon: false,
                markers: _hotspotMarkers(Theme.of(context).colorScheme),
                onMarkerTap: _onHotspotMarkerTap,
                builder: (context, markers) {
                  final scheme = Theme.of(context).colorScheme;
                  final theme = Theme.of(context);
                  return Semantics(
                    button: true,
                    label: '${markers.length} hotspots',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                      child: Center(
                        child: Text(
                          '${markers.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: BrandProgressIndicator()),
            ),
          ),
        if (_showingStale && _cacheFetchedAt != null)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            child: Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Showing results from ${formatRelativeTime(_cacheFetchedAt!)} — couldn’t refresh',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (_error != null && !_loading)
          Positioned(
            left: 16,
            right: 16,
            bottom: _selected == null ? 24 : 140,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, maxLines: 2)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          ),
        // Persistent peek sheet — above nav (this Stack is the tab body),
        // map stays pannable; marker taps swap content in place.
        if (_selected != null)
          HotspotDetailSheet(
            key: ValueKey(_selected!.locId),
            hotspot: _selected!,
            apiKey: widget.apiKey,
            lat: _center!.latitude,
            lng: _center!.longitude,
            onDismiss: () => setState(() => _selected = null),
          ),
        // Recenter sits above the sheet in z-order so it stays tappable,
        // and lifts vertically when the peek sheet is open.
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg +
              (_selected == null
                  ? 0
                  : MediaQuery.sizeOf(context).height *
                      HotspotDetailSheet.peekSize),
          child: FloatingActionButton.small(
            heroTag: 'hotspots_recenter',
            tooltip: 'Recenter map on my location',
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _recenter,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

/// "You are here" — filled dot + ring, not a pin (distinct from hotspots).
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Your location',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary.withValues(alpha: 0.22),
          border: Border.all(color: primary, width: 2),
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
            ),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      ),
    );
  }
}
