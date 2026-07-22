import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../services/species_image_cache.dart';
import '../services/wikipedia_service.dart';

/// Stable [Hero] tag for a sighting-row photo → detail flight.
///
/// Includes loc + time so the same species twice in one list doesn't collide
/// (`docs/tickets/species-photo-hero-transition.md`).
String speciesPhotoHeroTag(Observation observation) =>
    'species-photo-${observation.speciesCode}-'
    '${observation.locId}-${observation.obsDt.millisecondsSinceEpoch}';

/// Lazy-loaded Wikipedia thumbnail for a species.
///
/// Uses the lightweight Wikipedia lead-image path (not the Commons gallery).
/// Attribution is shown on the detail hero only — thumbs are too small for
/// credit text (`docs/tickets/species-photo-attribution-and-gallery.md`).
///
/// Shared [WikipediaService] session cache means scrolling / revisiting
/// the same bird doesn't re-hit the network.
///
/// ## Keys matter
/// ListView reuses State by slot. When the All ↔ Notable filter swaps
/// different species into the same index, an unkeyed thumbnail kept showing
/// the previous bird. Always pass a species-based [Key] from the parent
/// (and we also refresh in [didUpdateWidget] as belt-and-suspenders).
///
/// ## Hero
/// Optional [heroTag] wraps the loaded image only — never the placeholder —
/// so a list tap can expand into the detail hero. See
/// `docs/tickets/species-photo-hero-transition.md`.
class SpeciesThumbnail extends StatefulWidget {
  final String comName;
  final String sciName;
  final double size;

  /// When non-null and the image loads, wraps the photo in a [Hero].
  final Object? heroTag;

  const SpeciesThumbnail({
    super.key,
    required this.comName,
    required this.sciName,
    this.size = 56,
    this.heroTag,
  });

  @override
  State<SpeciesThumbnail> createState() => _SpeciesThumbnailState();
}

class _SpeciesThumbnailState extends State<SpeciesThumbnail> {
  static final _wiki = WikipediaService();
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SpeciesThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comName != widget.comName ||
        oldWidget.sciName != widget.sciName) {
      _future = _load();
    }
  }

  Future<String?> _load() => _wiki.fetchThumbnailUrl(
        comName: widget.comName,
        sciName: widget.sciName,
      );

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Match detail-page card radius (species-detail / sightings redesign).
    final radius = BorderRadius.circular(12);

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<String?>(
        // Identity in the key forces FutureBuilder to reset when species changes.
        key: ValueKey('${widget.sciName}|${widget.comName}'),
        future: _future,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return _Placeholder(size: size, radius: radius, loading: true);
          }
          if (url == null || url.isEmpty) {
            return _Placeholder(size: size, radius: radius, loading: false);
          }
          return Semantics(
            image: true,
            label: 'Photo of a ${widget.comName}',
            child: CachedNetworkImage(
              imageUrl: url,
              httpHeaders: WikipediaService.imageRequestHeaders,
              cacheManager: SpeciesImageCache.instance,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Hero only around the decoded bitmap — never the loading /
              // error placeholder icons.
              imageBuilder: (context, imageProvider) {
                final image = ClipRRect(
                  borderRadius: radius,
                  child: Image(
                    image: imageProvider,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                );
                final tag = widget.heroTag;
                if (tag == null) return image;
                return Hero(
                  tag: tag,
                  child: Material(
                    type: MaterialType.transparency,
                    child: image,
                  ),
                );
              },
              placeholder: (_, __) =>
                  _Placeholder(size: size, radius: radius, loading: true),
              errorWidget: (_, __, ___) =>
                  _Placeholder(size: size, radius: radius, loading: false),
            ),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final BorderRadius radius;
  final bool loading;

  const _Placeholder({
    required this.size,
    required this.radius,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: color,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            loading ? Icons.image_outlined : Icons.image_not_supported_outlined,
            size: size * 0.4,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
