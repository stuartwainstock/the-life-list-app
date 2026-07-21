import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/wikipedia_service.dart';

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
class SpeciesThumbnail extends StatefulWidget {
  final String comName;
  final String sciName;
  final double size;

  const SpeciesThumbnail({
    super.key,
    required this.comName,
    required this.sciName,
    this.size = 56,
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
          return ClipRRect(
            borderRadius: radius,
            child: CachedNetworkImage(
              imageUrl: url,
              httpHeaders: WikipediaService.imageRequestHeaders,
              width: size,
              height: size,
              fit: BoxFit.cover,
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
