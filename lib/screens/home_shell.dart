import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'sightings_list_screen.dart';
import 'hotspots_map_screen.dart';
import 'life_list_screen.dart';
import 'settings_screen.dart';

/// Root navigation shell.
///
/// Gates the whole app behind an eBird API key on first launch. We keep
/// keys **personal and on-device** (see [SettingsService]) rather than
/// shipping a shared key in the binary — that would be extractable and
/// would couple every user's quota to one credential.
///
/// Once a key exists, this hosts the four primary tabs. Sightings is the
/// core loop (GoBird parity); Life List is local-only for now (export to
/// eBird is a later phase — see [LifeListEntry] / README roadmap).
///
/// [themeMode] / [onThemeModeChanged] are owned by [TheLifeListApp] so
/// [MaterialApp] can rebuild; Settings only edits the preference.
///
/// First-run gate polish: `docs/tickets/first-run-onboarding.md`.
class HomeShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const HomeShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static final _keygenUri = Uri.parse('https://ebird.org/api/keygen');

  final _settings = SettingsService();
  String? _apiKey;
  bool _checked = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _refreshKey();
  }

  Future<void> _refreshKey() async {
    final key = await _settings.getApiKey();
    setState(() {
      _apiKey = key;
      _checked = true;
    });
  }

  Future<void> _openKeygen() async {
    await launchUrl(_keygenUri, mode: LaunchMode.externalApplication);
  }

  SettingsScreen _settingsPage() => SettingsScreen(
        onApiKeySaved: _refreshKey,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      );

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // First-run: force key setup before any eBird calls. Avoids a cascade
    // of 401s on every tab.
    if (_apiKey == null || _apiKey!.isEmpty) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to The Life List'),
          toolbarHeight: AppTheme.toolbarHeightOf(context),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App loon mark — not Flutter's dash placeholder.
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Image.asset(
                    'assets/icon/loon_icon_flat.png',
                    width: 88,
                    height: 88,
                    semanticLabel: 'The Life List',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'The Life List',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Needs a free eBird API key to fetch real sighting data.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton.icon(
                  onPressed: _openKeygen,
                  icon: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: scheme.primary,
                  ),
                  label: Text(
                    "Don't have a key yet? Get one free from eBird",
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _settingsPage(),
                    ));
                    _refreshKey();
                  },
                  child: const Text('Set up API key'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      SightingsListScreen(apiKey: _apiKey!),
      HotspotsMapScreen(apiKey: _apiKey!),
      const LifeListScreen(),
      _settingsPage(),
    ];

    return Scaffold(
      body: pages[_tab],
      // Material 3 NavigationBar — preferred over a custom bottom bar
      // (docs/design-principles.md).
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'Sightings'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Hotspots'),
          NavigationDestination(
              icon: Icon(Icons.checklist), label: 'Life List'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
