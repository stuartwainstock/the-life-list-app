import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/life_list_entry.dart';

/// Local-only storage for the user's personal life list.
///
/// ## Why local-only (for now)
/// eBird's public API is read-only. Writing checklists needs either their
/// spreadsheet import (Phase 2 — fields on [LifeListEntry] already align)
/// or a future partnership for write access. Until then we never upload.
///
/// Storage is a JSON blob in SharedPreferences — fine for personal list
/// sizes. Migrate to sqflite later if we add search/stats; keep this
/// class's public API stable so callers don't care.
class LifeListService {
  static const _prefKey = 'life_list_entries';

  Future<List<LifeListEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => LifeListEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return entries;
  }

  Future<bool> isLogged(String speciesCode) async {
    final all = await getAll();
    return all.any((e) => e.speciesCode == speciesCode);
  }

  Future<void> add(LifeListEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    // Avoid duplicate species entries — update in place if already logged.
    all.removeWhere((e) => e.speciesCode == entry.speciesCode);
    all.add(entry);
    await prefs.setString(
      _prefKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String speciesCode) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.removeWhere((e) => e.speciesCode == speciesCode);
    await prefs.setString(
      _prefKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }
}
