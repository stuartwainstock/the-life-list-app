import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/observation.dart';
import '../models/life_list_entry.dart';
import '../services/ebird_service.dart';
import '../services/wikipedia_service.dart';
import '../services/life_list_service.dart';
import '../utils/relative_time.dart';
import '../widgets/skeleton.dart';
import '../widgets/species_detail_skeleton.dart';

/// Species detail — identity, Wikipedia context, nearby sightings feed.
///
/// ## Hierarchy (intentional)
/// Photo → common name (loud) → scientific name (quiet label) → description
/// card → sightings feed card. Earlier versions flattened all of that into
/// same-weight text; see `docs/tickets/species-detail-redesign.md`.
///
/// ## Hero photo
/// Collapsing [SliverAppBar] (Play Store / Spotify album pattern). If
/// Wikipedia has no image we fall back to a normal [AppBar] — never leave
/// a blank hero slab. Image uses `BoxFit.cover` in the flexible space;
/// list thumbnails stay separate (contain/crop is a list concern).
///
/// ## Life list FAB
/// Extended FAB can cover the last sighting row; [_fabClearance] pads the
/// scroll content so the feed can scroll clear of it.
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
      // Loading uses a skeleton hero with its own back control. Once loaded,
      // photo → SliverAppBar; no photo → standard AppBar with serif title.
      appBar: (_loading || _hasPhoto)
          ? null
          : AppBar(
              title: Text(
                widget.comName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
      body: _loading
          ? SpeciesDetailSkeleton(
              comName: widget.comName,
              sciName: widget.sciName,
            )
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

          // Sightings feed — most "GoBird-like" part of this screen; gets
          // its own tinted surface so it doesn't blend into the wiki blurb.
          _SightingsSection(sightings: _sightings),

          // Keep last rows above the extended FAB.
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
      // Custom leading — default back icon is ink-colored and disappears on
      // dark plumage / foliage in the hero (full-bleed photo pattern).
      automaticallyImplyLeading: false,
      leading: const _HeroBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            CachedNetworkImage(
              imageUrl: imageUrl,
              // cover is correct for a collapsing hero; the earlier
              // fixed-height + cover combo cropped awkwardly — flexible
              // space + scrim is the intended treatment now.
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (_, __) => const Center(
                child: BrandProgressIndicator(),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: scheme.outline,
                ),
              ),
            ),
            // Top scrim helps status-bar / leading area; bottom scrim keeps
            // future overlays readable on light plumage.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x66000000),
                  ],
                  stops: [0.0, 0.22, 0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular scrim + light icon so back stays visible on any hero photo
/// (Airbnb / Play Store style — don't rely on photo luminance).
class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
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
