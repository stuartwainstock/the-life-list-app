import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/observation.dart';
import '../models/life_list_entry.dart';
import '../services/ebird_service.dart';
import '../services/wikipedia_service.dart';
import '../services/life_list_service.dart';
import '../utils/relative_time.dart';

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

  /// FAB.extended height (~56) + margin (~16) + a little breathing room.
  static const double _fabClearance = 88;

  bool get _hasPhoto {
    final url = _summary?.heroImageUrl;
    return url != null && url.isNotEmpty;
  }

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
              decoration:
                  const InputDecoration(labelText: 'Location (optional)'),
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
      // No photo (or still loading): standard app bar. Photo hero owns
      // the back button via SliverAppBar once content is ready.
      appBar: (_loading || !_hasPhoto)
          ? AppBar(title: Text(widget.comName))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                if (_hasPhoto) _HeroAppBar(imageUrl: _summary!.heroImageUrl!),
                SliverToBoxAdapter(child: _buildBody(context)),
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

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity block
          Text(
            widget.comName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (widget.sciName.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.sciName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Description block — distinct surface
          if (_summary != null && _summary!.extract.isNotEmpty) ...[
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _summary!.extract,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Sightings section
          _SightingsSection(sightings: _sightings),

          const SizedBox(height: _fabClearance),
        ],
      ),
    );
  }
}

class _HeroAppBar extends StatelessWidget {
  final String imageUrl;

  const _HeroAppBar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 280,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: scheme.outline,
                ),
              ),
            ),
            // Bottom gradient scrim for contrast on light photos.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x66000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SightingsSection extends StatelessWidget {
  final List<Observation> sightings;

  const _SightingsSection({required this.sightings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent sightings near you',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${sightings.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sightings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent nearby sightings of this species.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...sightings.map(
                (s) => _SightingRow(observation: s),
              ),
          ],
        ),
      ),
    );
  }
}

class _SightingRow extends StatelessWidget {
  final Observation observation;

  const _SightingRow({required this.observation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final relative = formatRelativeTime(observation.obsDt);
    final count = observation.howMany;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation.locName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
