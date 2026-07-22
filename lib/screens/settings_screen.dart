import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/branded_app_bar.dart';

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
  DistanceUnit _distanceUnit = DistanceUnit.kilometers;

  @override
  void initState() {
    super.initState();
    _settings.getApiKey().then((key) {
      if (key != null && mounted) setState(() => _controller.text = key);
    });
    _settings.getDistanceUnit().then((unit) {
      if (mounted) setState(() => _distanceUnit = unit);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: BrandedAppBar(
        context: context,
        title: 'Settings',
      ),
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
              // Checkmark + fill/icon — selection is not color-only.
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'System follows your device light/dark setting.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Units', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DistanceUnit>(
              segments: const [
                ButtonSegment(
                  value: DistanceUnit.miles,
                  label: Text('Miles'),
                ),
                ButtonSegment(
                  value: DistanceUnit.kilometers,
                  label: Text('Kilometers'),
                ),
              ],
              selected: {_distanceUnit},
              onSelectionChanged: (selected) async {
                final unit = selected.first;
                setState(() => _distanceUnit = unit);
                await _settings.setDistanceUnit(unit);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Affects how search radius is shown. Distances sent to eBird '
            'stay in kilometers.',
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
            onPressed: () => _openUrl('https://ebird.org/api/keygen'),
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
          const SizedBox(height: AppSpacing.xl),
          Text('About', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The Life List is a birding app for the walk, not just the '
            'spreadsheet — nearby sightings, hotspots, and a personal life '
            'list built on Flutter and the free public eBird API.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Sources & Credits', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sightings, hotspots, and taxonomy data come from eBird '
            '(Cornell Lab of Ornithology). Species summaries and photos '
            'come from Wikipedia / Wikimedia Commons. Songs and calls come '
            'from Xeno-canto. Map tiles come from OpenStreetMap.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => _openUrl('https://ebird.org'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('eBird'),
          ),
          TextButton.icon(
            onPressed: () => _openUrl('https://www.wikimedia.org'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Wikimedia'),
          ),
          TextButton.icon(
            onPressed: () => _openUrl('https://xeno-canto.org'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Xeno-canto'),
          ),
          TextButton.icon(
            onPressed: () =>
                _openUrl('https://www.openstreetmap.org/copyright'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('OpenStreetMap'),
          ),
        ],
      ),
    );
  }
}
