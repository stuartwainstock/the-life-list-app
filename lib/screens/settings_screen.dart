import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../theme/app_spacing.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onApiKeySaved;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.onApiKeySaved,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _controller = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _settings.getApiKey().then((key) {
      if (key != null) setState(() => _controller.text = key);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Appearance', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          // Material 3 segmented control — same pattern as All / Notable.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                ),
              ],
              selected: {widget.themeMode},
              onSelectionChanged: (selected) {
                widget.onThemeModeChanged(selected.first);
              },
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'System follows your device light/dark setting.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('eBird API', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The Life List uses the free eBird API to fetch real sighting data. '
            'Grab a personal API key (takes about a minute) and paste it below.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://ebird.org/api/keygen'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Get a free eBird API key'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'eBird API key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () async {
              await _settings.setApiKey(_controller.text);
              widget.onApiKeySaved();
              setState(() => _saved = true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
          if (_saved) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Saved. Go back to load your local sightings.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
