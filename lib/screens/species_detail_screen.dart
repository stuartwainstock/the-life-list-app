import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/observation.dart';
import '../models/life_list_entry.dart';
import '../services/ebird_service.dart';
import '../services/wikipedia_service.dart';
import '../services/life_list_service.dart';
import '../services/species_image_cache.dart';
import '../services/xeno_canto_service.dart';
import '../models/xeno_canto_recording.dart';
import '../utils/relative_time.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_hairline.dart';
import '../widgets/skeleton.dart';
import '../widgets/species_detail_skeleton.dart';
import '../widgets/songs_and_calls_section.dart';

/// Species detail — identity, Wikipedia context, nearby sightings feed.
///
/// ## Hierarchy (intentional)
/// Photo → common name (loud) → scientific name (quiet label) →
/// description → Songs & Calls → sightings feed. See
/// `docs/tickets/species-detail-redesign.md` and
/// `docs/tickets/xeno-canto-audio.md`.
///
/// ## Hero photo
/// Collapsing [SliverAppBar] with optional Commons gallery (swipe + dots)
/// and attribution caption — see
/// `docs/tickets/species-photo-attribution-and-gallery.md`.
/// List → detail shared-element flight:
/// `docs/tickets/species-photo-hero-transition.md`.
///
/// ## Songs & Calls
/// Best-quality Song and Call from Xeno-canto when available — hidden
/// entirely when none resolve.
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
/// Confirming "Add to life list" plays a brief on-brand celebration
/// (`docs/tickets/life-list-celebration-animation.md`).
class SpeciesDetailScreen extends StatefulWidget {
  final String apiKey;
  final String speciesCode;
  final String comName;
  final String sciName;
  final double lat;
  final double lng;

  /// Shared-element tag matching the list [SpeciesThumbnail], when a real
  /// photo was already on screen (`docs/tickets/species-photo-hero-transition.md`).
  final Object? photoHeroTag;

  /// Exact Wikipedia thumb URL the list was showing — Hero flies these bytes,
  /// then the Commons gallery fades in underneath.
  final String? heroThumbnailUrl;

  const SpeciesDetailScreen({
    super.key,
    required this.apiKey,
    required this.speciesCode,
    required this.comName,
    required this.sciName,
    required this.lat,
    required this.lng,
    this.photoHeroTag,
    this.heroThumbnailUrl,
  });

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  late final EbirdService _ebird = EbirdService(widget.apiKey);
  final _wiki = WikipediaService();
  final _lifeList = LifeListService();
  final _xenoCanto = XenoCantoService();

  bool _loading = true;
  List<Observation> _sightings = [];
  WikiSummary? _summary;
  bool _isLogged = false;
  XenoCantoRecording? _song;
  XenoCantoRecording? _call;

  /// Bumped only when the user confirms an add — drives the one-shot FAB
  /// celebration without firing when we hydrate an already-logged species.
  int _lifeListCelebration = 0;

  /// Extended FAB (~56) + default float margin (~16) + extra breathing room.
  /// Bottom inset is added at build time for home-indicator devices.
  static const double _fabClearanceBase = 96;

  bool get _hasPhoto => _summary?.photos.isNotEmpty ?? false;

  bool get _hasIncomingHero =>
      widget.photoHeroTag != null &&
      widget.heroThumbnailUrl != null &&
      widget.heroThumbnailUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAudio();
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

  /// Independent of the main skeleton — missing audio just hides the section.
  Future<void> _loadAudio() async {
    if (widget.sciName.trim().isEmpty) return;
    try {
      final pair = await _xenoCanto.bestSongAndCall(sciName: widget.sciName);
      if (!mounted) return;
      setState(() {
        _song = pair.song;
        _call = pair.call;
      });
    } catch (_) {
      // Leave song/call null — section stays hidden.
    }
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
    setState(() {
      _isLogged = true;
      _lifeListCelebration++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.comName} added to your life list')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Photo chrome whenever we have a gallery *or* an incoming list Hero —
    // the latter needs a destination Hero in the tree for the flight.
    final usePhotoChrome = _loading
        ? _hasIncomingHero
        : (_hasPhoto || _hasIncomingHero);

    return Scaffold(
      // Loading without a Hero uses the full skeleton (pulsing hero slab).
      // With an incoming Hero, keep a real SliverAppBar so the shared
      // element stays mounted through load → gallery fade-in.
      appBar: usePhotoChrome
          ? null
          : AppBar(
              title: Text(
                widget.comName,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              toolbarHeight: AppTheme.toolbarHeightOf(context),
            ),
      body: _loading && !_hasIncomingHero
          ? SpeciesDetailSkeleton(
              comName: widget.comName,
              sciName: widget.sciName,
            )
          : CustomScrollView(
              physics: _loading
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (usePhotoChrome)
                  _HeroAppBar(
                    photos: _loading
                        ? const []
                        : (_summary?.photos ?? const []),
                    comName: widget.comName,
                    photoHeroTag: widget.photoHeroTag,
                    heroThumbnailUrl: widget.heroThumbnailUrl,
                  ),
                SliverToBoxAdapter(
                  child: _loading
                      ? SpeciesDetailSkeleton.bodyBelowHero(
                          context: context,
                          comName: widget.comName,
                          sciName: widget.sciName,
                        )
                      : _buildBody(context),
                ),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : _LifeListFab(
              isLogged: _isLogged,
              celebrationToken: _lifeListCelebration,
              onAdd: _addToLifeList,
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

          // Songs & Calls — after the description, still above the sightings
          // feed (`docs/tickets/species-detail-reorder-songs-description.md`).
          if (_song != null || _call != null) ...[
            const SizedBox(height: AppSpacing.xl),
            const AppHairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: SongsAndCallsSection(song: _song, call: _call),
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

/// Milestone FAB — brief scale + icon/label crossfade when a species is logged.
///
/// Celebration is gated by [celebrationToken] (bumped only on explicit add),
/// so hydrating an already-logged species stays instant. Reduced motion skips
/// the bounce and switcher duration (`docs/tickets/life-list-celebration-animation.md`).
class _LifeListFab extends StatefulWidget {
  final bool isLogged;
  final int celebrationToken;
  final VoidCallback onAdd;

  const _LifeListFab({
    required this.isLogged,
    required this.celebrationToken,
    required this.onAdd,
  });

  @override
  State<_LifeListFab> createState() => _LifeListFabState();
}

class _LifeListFabState extends State<_LifeListFab>
    with SingleTickerProviderStateMixin {
  static const _switchDuration = Duration(milliseconds: 280);
  static const _bounceDuration = Duration(milliseconds: 420);

  late final AnimationController _bounce;
  late final Animation<double> _scale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _ringScale;

  /// True only for the explicit-add celebration frame(s).
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: _bounceDuration);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_bounce);
    _ringOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_bounce);
    _ringScale = Tween<double>(begin: 1.0, end: 1.22)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_bounce);
  }

  @override
  void didUpdateWidget(covariant _LifeListFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrationToken <= oldWidget.celebrationToken) return;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _celebrating = false;
      return;
    }

    _celebrating = true;
    _bounce.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _celebrating = false);
    });
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final switchDuration =
        (_celebrating && !reduceMotion) ? _switchDuration : Duration.zero;

    final fab = FloatingActionButton.extended(
      onPressed: widget.isLogged ? null : widget.onAdd,
      icon: AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          widget.isLogged ? Icons.check : Icons.add,
          key: ValueKey<bool>(widget.isLogged),
        ),
      ),
      label: AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: Text(
          widget.isLogged ? 'On your life list' : 'Add to life list',
          key: ValueKey<bool>(widget.isLogged),
        ),
      ),
    );

    if (reduceMotion) return fab;

    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft brand-accent ring — one pulse, then gone.
            if (_bounce.isAnimating || _bounce.value > 0)
              IgnorePointer(
                child: Opacity(
                  opacity: _ringOpacity.value,
                  child: Transform.scale(
                    scale: _ringScale.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: scheme.primary,
                          width: 2,
                        ),
                      ),
                      child: const SizedBox(width: 200, height: 56),
                    ),
                  ),
                ),
              ),
            Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ],
        );
      },
      child: fab,
    );
  }
}

class _HeroAppBar extends StatefulWidget {
  final List<SpeciesPhoto> photos;
  final String comName;
  final Object? photoHeroTag;
  final String? heroThumbnailUrl;

  const _HeroAppBar({
    required this.photos,
    required this.comName,
    this.photoHeroTag,
    this.heroThumbnailUrl,
  });

  @override
  State<_HeroAppBar> createState() => _HeroAppBarState();
}

class _HeroAppBarState extends State<_HeroAppBar>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController = PageController();
  int _index = 0;

  /// List thumb overlay (same bytes as the flight) until the gallery fades in.
  bool _showThumbOverlay = false;
  late final AnimationController _overlayFade;
  late final Animation<double> _overlayOpacity;

  bool get _hasIncomingHero =>
      widget.photoHeroTag != null &&
      widget.heroThumbnailUrl != null &&
      widget.heroThumbnailUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _showThumbOverlay = _hasIncomingHero;
    _overlayFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _overlayOpacity = CurvedAnimation(
      parent: _overlayFade,
      curve: Curves.easeOut,
    );
    if (_showThumbOverlay && widget.photos.isNotEmpty) {
      _scheduleOverlayFade();
    }
  }

  @override
  void didUpdateWidget(covariant _HeroAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_showThumbOverlay &&
        oldWidget.photos.isEmpty &&
        widget.photos.isNotEmpty) {
      _scheduleOverlayFade();
    }
  }

  void _scheduleOverlayFade() {
    // Let the first gallery frame paint under the thumb, then crossfade.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showThumbOverlay) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _showThumbOverlay = false);
        return;
      }
      _overlayFade.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _showThumbOverlay = false);
      });
    });
  }

  @override
  void dispose() {
    _overlayFade.dispose();
    _pageController.dispose();
    super.dispose();
  }

  SpeciesPhoto? get _current {
    if (widget.photos.isEmpty) return null;
    return widget.photos[_index.clamp(0, widget.photos.length - 1)];
  }

  Future<void> _openSource() async {
    final raw = _current?.sourcePageUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _thumbImage({required bool forHero}) {
    final image = CachedNetworkImage(
      imageUrl: widget.heroThumbnailUrl!,
      httpHeaders: WikipediaService.imageRequestHeaders,
      cacheManager: SpeciesImageCache.instance,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const ColoredBox(color: Colors.transparent),
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.transparent),
    );
    if (!forHero) return image;
    return Hero(
      tag: widget.photoHeroTag!,
      child: Material(
        type: MaterialType.transparency,
        child: image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final photos = widget.photos;
    final multi = photos.length > 1;
    final attribution = _current?.attributionText;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

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
            if (photos.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final photo = photos[i];
                  final attr = photo.attributionText;
                  final indexLabel = multi
                      ? 'Photo ${i + 1} of ${photos.length} of a ${widget.comName}'
                      : 'Photo of a ${widget.comName}';
                  final label = (attr != null && attr.isNotEmpty)
                      ? '$indexLabel. $attr'
                      : indexLabel;
                  final sourceUrl = photo.sourcePageUrl;
                  return Semantics(
                    image: true,
                    label: label,
                    button: sourceUrl != null && sourceUrl.isNotEmpty,
                    hint: sourceUrl != null && sourceUrl.isNotEmpty
                        ? 'Double-tap to open photo source'
                        : null,
                    onTap: sourceUrl != null && sourceUrl.isNotEmpty
                        ? () async {
                            final uri = Uri.tryParse(sourceUrl);
                            if (uri == null) return;
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        : null,
                    child: CachedNetworkImage(
                      imageUrl: photo.imageUrl,
                      httpHeaders: WikipediaService.imageRequestHeaders,
                      cacheManager: SpeciesImageCache.instance,
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
                  );
                },
              )
            else if (_hasIncomingHero && !_showThumbOverlay)
              // Gallery empty but we still have the list thumb — keep it.
              _thumbImage(forHero: false),
            // Same bytes the list showed — Hero flies this, then fades out
            // once the Commons gallery is underneath.
            if (_showThumbOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  child: reduceMotion
                      ? _thumbImage(forHero: true)
                      : FadeTransition(
                          opacity: Tween<double>(begin: 1, end: 0)
                              .animate(_overlayOpacity),
                          child: _thumbImage(forHero: true),
                        ),
                ),
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
                // Attribution is already in each photo's Semantics label —
                // keep the visible caption but don't double-announce it.
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: _current?.sourcePageUrl != null ? _openSource : null,
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
                      // Active page is larger — not opacity/color alone.
                      Container(
                        width: i == _index ? 8 : 6,
                        height: i == _index ? 8 : 6,
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
