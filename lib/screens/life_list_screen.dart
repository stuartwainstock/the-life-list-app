import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/life_list_entry.dart';
import '../services/life_list_service.dart';
import '../widgets/species_thumbnail.dart';
import '../widgets/branded_app_bar.dart';

/// The user's personal life list — every species they've marked as seen,
/// stored locally on-device (see LifeListService for why, and for the
/// future eBird-export plan).
class LifeListScreen extends StatefulWidget {
  const LifeListScreen({super.key});

  @override
  State<LifeListScreen> createState() => _LifeListScreenState();
}

class _LifeListScreenState extends State<LifeListScreen> {
  final _service = LifeListService();
  List<LifeListEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.getAll();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _confirmRemove(LifeListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from life list?'),
        content: Text('This removes ${entry.comName} from your list on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.remove(entry.speciesCode);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(
        context: context,
        title: 'My Life List',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh life list',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.checklist, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "No species logged yet. Tap 'Add to life list' on any "
                          'species page when you spot one.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return ListTile(
                        key: ValueKey(e.speciesCode),
                        leading: SpeciesThumbnail(
                          key: ValueKey('thumb-${e.speciesCode}'),
                          comName: e.comName,
                          sciName: e.sciName,
                        ),
                        title: Text(e.comName),
                        subtitle: Text(
                          '${e.locName}\n${DateFormat.yMMMd().format(e.dateSeen)}'
                          '${e.count > 1 ? ' · ${e.count} seen' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove ${e.comName}',
                          onPressed: () => _confirmRemove(e),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${_entries.length} species · logged on this device only',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
    );
  }
}
