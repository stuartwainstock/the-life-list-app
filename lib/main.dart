import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'services/map_tile_cache.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

/// The Life List — a personal birding app (GoBird-inspired).
///
/// ## What this app is
/// Nearby eBird sightings + hotspots, species detail (Wikipedia photo/
/// summary), and a personal life list. Built for field use: scannable
/// lists, low cognitive load, Material 3 patterns.
///
/// ## Architecture at a glance
/// - **Data:** Cornell eBird API 2.0 (read-only). Each user supplies their
///   own free API key (stored on-device). App Store distribution will later
///   need a backend proxy so keys aren't per-user in the client.
/// - **Photos:** Wikipedia REST summary API — Macaulay Library isn't on a
///   public API. Scientific name preferred over common name for lookups.
/// - **Taxonomy:** Separate eBird taxonomy dump, disk-cached 30 days, used
///   to group the sightings list by family in taxonomic order.
/// - **UI language:** See `docs/design-principles.md` and `docs/brand.md`.
///   Tokens live under `lib/theme/`. Tickets under `docs/tickets/`.
///
/// ## Local web testing
/// eBird may block browser CORS. Run `node tools/cors_proxy.js` and
/// `flutter run -d chrome --dart-define=EBIRD_BASE_URL=http://localhost:3000/v2`.
///
/// ## Launch splash
/// Native splash is configured via `flutter_native_splash.yaml` (Android
/// SplashScreen API + web). It dismisses on first Flutter frame — do not
/// add artificial delays here. See `docs/tickets/splash-screen-skeleton.md`.
void main() {
  // Cap flutter_map's built-in tile disk cache before any TileLayer can
  // create the 1 GB default instance.
  MapTileCache.ensureConfigured();
  runApp(const TheLifeListApp());
}

class TheLifeListApp extends StatefulWidget {
  const TheLifeListApp({super.key});

  @override
  State<TheLifeListApp> createState() => _TheLifeListAppState();
}

class _TheLifeListAppState extends State<TheLifeListApp> {
  final _settings = SettingsService();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _settings.getThemeMode();
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _settings.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Life List',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: HomeShell(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
