import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onApiKeySaved;
  const SettingsScreen({super.key, required this.onApiKeySaved});

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GoBirder uses the free eBird API to fetch real sighting data. '
              'Grab a personal API key (takes about a minute) and paste it below.',
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://ebird.org/api/keygen'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Get a free eBird API key'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'eBird API key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 8),
              const Text('Saved. Go back to load your local sightings.'),
            ],
          ],
        ),
      ),
    );
  }
}
