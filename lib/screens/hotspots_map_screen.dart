import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/hotspot.dart';
import '../services/ebird_list_cache.dart';
import '../services/ebird_service.dart';
import '../services/location_service.dart';
import '../theme/app_spacing.dart';
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
/// shell nav and the map remains interactive.
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

  /// Matches [EbirdService.nearbyHotspots] default.
  static const _distKm = 25;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
              const Icon(Icons.error_outline, size: 40),
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
          options: MapOptions(
            initialCenter: _center!,
            initialZoom: 11,
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
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _center!,
                  width: 30,
                  height: 30,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                ..._hotspots.map(
                  (h) => Marker(
                    point: LatLng(h.lat, h.lng),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = h),
                      child: Icon(
                        Icons.location_on,
                        color: _selected?.locId == h.locId
                            ? Theme.of(context).colorScheme.primary
                            : Colors.redAccent,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
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
      ],
    );
  }
}
