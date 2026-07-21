import 'package:flutter/material.dart';

import '../services/ebird_taxonomy_service.dart';
import '../services/location_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/skeleton.dart';
import 'species_detail_screen.dart';

/// Local taxonomy search — common-name substring match.
///
/// Filters the on-device [EbirdTaxonomyService] cache (not nearby sightings).
/// Empty query shows a short prompt rather than the full species list.
/// Match is common name only (scientific name stays as subtitle display) —
/// see `docs/tickets/species-search-common-name-only.md`.
class SpeciesSearchScreen extends StatefulWidget {
  final String apiKey;
  final double? lat;
  final double? lng;

  /// Optional preloaded lookup from [SightingsListScreen] to skip a wait.
  final Map<String, TaxonomyEntry>? initialLookup;

  const SpeciesSearchScreen({
    super.key,
    required this.apiKey,
    this.lat,
    this.lng,
    this.initialLookup,
  });

  @override
  State<SpeciesSearchScreen> createState() => _SpeciesSearchScreenState();
}

class _SpeciesSearchScreenState extends State<SpeciesSearchScreen> {
  final _taxonomy = EbirdTaxonomyService();
  final _location = LocationService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Map<String, TaxonomyEntry>? _lookup;
  List<TaxonomyEntry> _results = const [];
  bool _loadingTaxonomy = true;
  String? _taxonomyError;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.lat;
    _lng = widget.lng;
    _controller.addListener(_onQueryChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.initialLookup != null && widget.initialLookup!.isNotEmpty) {
      setState(() {
        _lookup = widget.initialLookup;
        _loadingTaxonomy = false;
      });
    } else {
      final lookup = await _taxonomy.getLookup(widget.apiKey);
      if (!mounted) return;
      if (lookup == null || lookup.isEmpty) {
        setState(() {
          _loadingTaxonomy = false;
          _taxonomyError =
              'Couldn’t load the species list. Check your connection and try again.';
        });
      } else {
        setState(() {
          _lookup = lookup;
          _loadingTaxonomy = false;
        });
      }
    }

    if (_lat == null || _lng == null) {
      try {
        final pos = await _location.getCurrentPosition();
        if (!mounted) return;
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      } catch (_) {
        // Detail still opens; nearby sightings on that screen may fail.
      }
    }

    // Autofocus after first frame so the keyboard is ready to type.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onQueryChanged() {
    final lookup = _lookup;
    if (lookup == null) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _results = EbirdTaxonomyService.search(lookup, _controller.text);
    });
  }

  Future<void> _openDetail(TaxonomyEntry entry) async {
    var lat = _lat;
    var lng = _lng;
    if (lat == null || lng == null) {
      try {
        final pos = await _location.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
        if (mounted) {
          setState(() {
            _lat = lat;
            _lng = lng;
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Need location to open species detail: $e')),
        );
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeciesDetailScreen(
          apiKey: widget.apiKey,
          speciesCode: entry.speciesCode,
          comName: entry.comName,
          sciName: entry.sciName,
          lat: lat!,
          lng: lng!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Search species',
            border: InputBorder.none,
            hintStyle: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
              },
            ),
        ],
      ),
      body: _buildBody(theme, scheme, query),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme scheme, String query) {
    if (_loadingTaxonomy) {
      return const Center(child: BrandProgressIndicator());
    }
    if (_taxonomyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            _taxonomyError!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Search by common name',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No species match “$query”',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final entry = _results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          title: Text(
            entry.comName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          subtitle: entry.sciName.trim().isEmpty
              ? null
              : Text(
                  entry.sciName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
          onTap: () => _openDetail(entry),
        );
      },
    );
  }
}
