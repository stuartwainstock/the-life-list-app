import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/observation.dart';
import '../models/life_list_entry.dart';
import '../services/ebird_service.dart';
import '../services/wikipedia_service.dart';
import '../services/life_list_service.dart';
import '../utils/relative_time.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_hairline.dart';
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
/// Collapsing [SliverAppBar] with optional Commons gallery (swipe + dots)
/// and attribution caption — see
/// `docs/tickets/species-photo-attribution-and-gallery.md`.
///
/// ## Recent sightings
/// Capped to [_SightingsSection.initialCap] with in-place "View all N"
/// expand (simpler than a second route). Long lists also get Today /
/// Yesterday / This week / Earlier bands for scannability.
/// See `docs/tickets/species-detail-sightings-list-polish.md`.
///
/// ## Life list FAB
/// Extended FAB clearance uses FAB height + margin + system bottom inset
/// so the last sighting row can scroll clear of the button.
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

  /// Extended FAB (~56) + default float margin (~16) + extra breathing room.
  /// Bottom inset is added at build time for home-indicator devices.
  static const double _fabClearanceBase = 96;

  bool get _hasPhoto => _summary?.photos.isNotEmpty ?? false;

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
      final list = List<Observation>.from(results[0] as List<Observation>)
        ..sort((a, b) => b.obsDt.compareTo(a.obsDt));
      _sightings = list;
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
                if (_hasPhoto) _HeroAppBar(photos: _summary!.photos),
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
    final fabClearance =
        _fabClearanceBase + MediaQuery.paddingOf(context).bottom;

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

          // Description — hairline separation, not a tinted card
          // (`docs/brand.md` surface philosophy / hairline-vs-card-pass).
          if (_summary != null && _summary!.extract.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const AppHairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                _summary!.extract,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          const AppHairline(),
          const SizedBox(height: AppSpacing.lg),

          // Sightings feed — section eyebrow + list; no outer card fill.
          _SightingsSection(sightings: _sightings),

          // Keep last rows above the extended FAB (+ home indicator).
          SizedBox(height: fabClearance),
        ],
      ),
    );
  }
}

class _HeroAppBar extends StatefulWidget {
  final List<SpeciesPhoto> photos;

  const _HeroAppBar({required this.photos});

  @override
  State<_HeroAppBar> createState() => _HeroAppBarState();
}

class _HeroAppBarState extends State<_HeroAppBar> {
  late final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  SpeciesPhoto get _current => widget.photos[_index.clamp(0, widget.photos.length - 1)];

  Future<void> _openSource() async {
    final raw = _current.sourcePageUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final photos = widget.photos;
    final multi = photos.length > 1;
    final attribution = _current.attributionText;

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
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return CachedNetworkImage(
                  imageUrl: photos[i].imageUrl,
                  httpHeaders: WikipediaService.imageRequestHeaders,
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
                );
              },
            ),
            // Must IgnorePointer — a full-bleed DecoratedBox above the
            // PageView otherwise steals horizontal swipes.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                    stops: [0.0, 0.22, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            if (attribution != null && attribution.isNotEmpty)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: multi ? 28 : AppSpacing.md,
                child: GestureDetector(
                  onTap: _current.sourcePageUrl != null ? _openSource : null,
                  child: Text(
                    attribution,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.25,
                      shadows: const [
                        Shadow(
                          blurRadius: 6,
                          color: Color(0x88000000),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (multi)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
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

class _SightingsSection extends StatefulWidget {
  /// Most-recent entries shown before "View all N sightings".
  static const int initialCap = 10;

  final List<Observation> sightings;

  const _SightingsSection({required this.sightings});

  @override
  State<_SightingsSection> createState() => _SightingsSectionState();
}

class _SightingsSectionState extends State<_SightingsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;
    final sightings = widget.sightings;
    final total = sightings.length;
    final capped = !_expanded && total > _SightingsSection.initialCap;
    final visible = capped
        ? sightings.take(_SightingsSection.initialCap).toList()
        : sightings;
    final bands = _groupByRecency(visible);

    return Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$total',
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
        else ...[
          for (final band in bands) ...[
            if (bands.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  band.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...band.items.map((s) => _SightingRow(observation: s)),
          ],
          if (capped)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View all $total sightings'),
              ),
            ),
          if (_expanded && total > _SightingsSection.initialCap)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  textStyle: theme.textTheme.labelLarge,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Show less'),
              ),
            ),
        ],
      ],
    );
  }

  /// Groups already-sorted (newest-first) rows into recency bands.
  List<_RecencyBand> _groupByRecency(List<Observation> list) {
    final bands = <_RecencyBand>[];
    String? currentLabel;
    var bucket = <Observation>[];

    for (final obs in list) {
      final label = formatRecencyBand(obs.obsDt);
      if (currentLabel == null) {
        currentLabel = label;
        bucket = [obs];
      } else if (label == currentLabel) {
        bucket.add(obs);
      } else {
        bands.add(_RecencyBand(label: currentLabel, items: bucket));
        currentLabel = label;
        bucket = [obs];
      }
    }
    if (currentLabel != null && bucket.isNotEmpty) {
      bands.add(_RecencyBand(label: currentLabel, items: bucket));
    }
    return bands;
  }
}

class _RecencyBand {
  final String label;
  final List<Observation> items;

  _RecencyBand({required this.label, required this.items});
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
