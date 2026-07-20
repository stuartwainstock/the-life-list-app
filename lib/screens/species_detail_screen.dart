import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/observation.dart';
import '../models/life_list_entry.dart';
import '../services/ebird_service.dart';
import '../services/wikipedia_service.dart';
import '../services/life_list_service.dart';

class SpeciesDetailScreen extends StatefulWidget {
  final String apiKey;
  final String speciesCode;
  final String comName;
  final String sciName;
  final double lat;
  final double lng;

  const SpeciesDetailScreen({
    super.key,
    required this.apiKey,
    required this.speciesCode,
    required this.comName,
    required this.sciName,
    required this.lat,
    required this.lng,
  });

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  late final EbirdService _ebird = EbirdService(widget.apiKey);
  final _wiki = WikipediaService();
  final _lifeList = LifeListService();

  bool _loading = true;
  List<Observation> _sightings = [];
  WikiSummary? _summary;
  bool _isLogged = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkLogged();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _ebird.nearbyObservationsForSpecies(
        speciesCode: widget.speciesCode,
        lat: widget.lat,
        lng: widget.lng,
      ),
      _wiki.fetchForSpecies(
        comName: widget.comName,
        sciName: widget.sciName,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _sightings = results[0] as List<Observation>;
      _summary = results[1] as WikiSummary?;
      _loading = false;
    });
  }

  Future<void> _checkLogged() async {
    final logged = await _lifeList.isLogged(widget.speciesCode);
    if (!mounted) return;
    setState(() => _isLogged = logged);
  }

  Future<void> _addToLifeList() async {
    final countController = TextEditingController(text: '1');
    final locController = TextEditingController(
      text: _sightings.isNotEmpty ? _sightings.first.locName : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add ${widget.comName} to your life list'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'How many seen'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _lifeList.add(LifeListEntry(
      speciesCode: widget.speciesCode,
      comName: widget.comName,
      sciName: widget.sciName,
      count: int.tryParse(countController.text) ?? 1,
      locName: locController.text.trim().isEmpty
          ? 'Unspecified location'
          : locController.text.trim(),
      lat: widget.lat,
      lng: widget.lng,
      dateSeen: DateTime.now(),
    ));

    if (!mounted) return;
    setState(() => _isLogged = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.comName} added to your life list')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.comName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_summary?.heroImageUrl != null)
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: CachedNetworkImage(
                        imageUrl: _summary!.heroImageUrl!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        placeholder: (_, __) => const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox(
                          height: 120,
                          child: Center(child: Icon(Icons.image_not_supported_outlined)),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sciName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                      if (_summary != null && _summary!.extract.isNotEmpty)
                        Text(_summary!.extract),
                      const SizedBox(height: 20),
                      Text('Recent sightings near you',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                if (_sightings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No recent nearby sightings of this species.'),
                  )
                else
                  ..._sightings.map(
                    (s) => ListTile(
                      title: Text(s.locName),
                      subtitle: Text(
                        '${DateFormat.yMMMd().add_jm().format(s.obsDt)}'
                        '${s.howMany != null ? ' · ${s.howMany} seen' : ''}',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLogged ? null : _addToLifeList,
              icon: Icon(_isLogged ? Icons.check : Icons.add),
              label: Text(_isLogged ? 'On your life list' : 'Add to life list'),
            ),
    );
  }
}
