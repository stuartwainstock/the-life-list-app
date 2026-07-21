import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/hotspot.dart';
import '../services/ebird_service.dart';
import '../services/location_service.dart';
import '../widgets/skeleton.dart';

/// Map of nearby eBird hotspots, using OpenStreetMap tiles via flutter_map
/// so no Google Maps API key / billing setup is required.
class HotspotsMapScreen extends StatefulWidget {
  final String apiKey;
  const HotspotsMapScreen({super.key, required this.apiKey});

  @override
  State<HotspotsMapScreen> createState() => _HotspotsMapScreenState();
}

class _HotspotsMapScreenState extends State<HotspotsMapScreen> {
  final _locationService = LocationService();
  late final EbirdService _ebird = EbirdService(widget.apiKey);

  bool _loading = true;
  String? _error;
  List<Hotspot> _hotspots = [];
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      // Show the map + user pin as soon as we have a fix; hotspots load
      // under a lightweight overlay (loading-states-polish).
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
      });
      final hotspots = await _ebird.nearbyHotspots(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _hotspots = hotspots;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
    // Location failed before we could place the map.
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
          options: MapOptions(initialCenter: _center!, initialZoom: 11),
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
                      onTap: () => _showHotspotSheet(h),
                      child: const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 32),
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
        if (_error != null && !_loading)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
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
      ],
    );
  }

  void _showHotspotSheet(Hotspot h) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.locName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (h.numSpeciesAllTime != null)
              Text('${h.numSpeciesAllTime} species recorded all-time'),
          ],
        ),
      ),
    );
  }
}
