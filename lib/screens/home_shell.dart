import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'sightings_list_screen.dart';
import 'hotspots_map_screen.dart';
import 'life_list_screen.dart';
import 'settings_screen.dart';

/// Top-level shell: shows a "set up your API key" prompt until one is
/// saved, then hosts the bottom-nav'd Sightings / Hotspots / Life List /
/// Settings tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Welcome to GoBirder')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flutter_dash, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'GoBirder needs a free eBird API key to fetch real sighting data.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          SettingsScreen(onApiKeySaved: _refreshKey),
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
      SettingsScreen(onApiKeySaved: _refreshKey),
    ];

    return Scaffold(
      body: pages[_tab],
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
