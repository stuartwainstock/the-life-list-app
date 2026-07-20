import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/observation.dart';
import '../services/ebird_service.dart';
import '../services/location_service.dart';
import '../widgets/species_thumbnail.dart';
import 'species_detail_screen.dart';

/// Shows a list of recently-reported species near the user's current
/// location, mirroring GoBird's main "nearby sightings" view.
class SightingsListScreen extends StatefulWidget {
  final String apiKey;
  const SightingsListScreen({super.key, required this.apiKey});

  @override
  State<SightingsListScreen> createState() => _SightingsListScreenState();
}

class _SightingsListScreenState extends State<SightingsListScreen>
    with SingleTickerProviderStateMixin {
  final _locationService = LocationService();
  late final EbirdService _ebird = EbirdService(widget.apiKey);

  bool _loading = true;
  String? _error;
  Position? _position;
  List<Observation> _all = [];
  List<Observation> _notable = [];
  bool _showNotableOnly = false;

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
      final results = await Future.wait([
        _ebird.nearbyObservations(lat: pos.latitude, lng: pos.longitude),
        _ebird.nearbyNotableObservations(lat: pos.latitude, lng: pos.longitude),
      ]);
      setState(() {
        _position = pos;
        _all = results[0];
        _notable = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _showNotableOnly ? _notable : _all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Sightings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Show:'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('All species'),
                  selected: !_showNotableOnly,
                  onSelected: (_) => setState(() => _showNotableOnly = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Notable / rare'),
                  selected: _showNotableOnly,
                  onSelected: (_) => setState(() => _showNotableOnly = true),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(list)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Observation> list) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
    if (list.isEmpty) {
      return const Center(child: Text('No sightings reported nearby recently.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final obs = list[i];
          return ListTile(
            key: ValueKey('${obs.speciesCode}-${obs.locId}-${obs.obsDt}'),
            leading: SpeciesThumbnail(
              key: ValueKey('thumb-${obs.speciesCode}'),
              comName: obs.comName,
              sciName: obs.sciName,
            ),
            title: Text(obs.comName),
            subtitle: Text(
              '${obs.locName}\n${DateFormat.yMMMd().add_jm().format(obs.obsDt)}'
              '${obs.howMany != null ? ' · ${obs.howMany} seen' : ''}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (_position == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SpeciesDetailScreen(
                  apiKey: widget.apiKey,
                  speciesCode: obs.speciesCode,
                  comName: obs.comName,
                  sciName: obs.sciName,
                  lat: _position!.latitude,
                  lng: _position!.longitude,
                ),
              ));
            },
          );
        },
      ),
    );
  }
}
