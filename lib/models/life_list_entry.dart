/// A single species entry in the user's personal life list.
///
/// Field choices are deliberately close to eBird's "Checklist Format"
/// spreadsheet import columns (see https://support.ebird.org/en/support/solutions/articles/48000907878-upload-spreadsheet-data-to-ebird)
/// so that a future export-to-eBird feature (Phase 2) is mostly a
/// formatting exercise rather than a data-model rework. We are NOT
/// calling eBird's API to submit anything yet — this is local-only.
class LifeListEntry {
  final String speciesCode;
  final String comName;
  final String sciName;
  final int count;
  final String locName;
  final double lat;
  final double lng;
  final DateTime dateSeen;
  final String notes;
  final DateTime dateAdded;

  LifeListEntry({
    required this.speciesCode,
    required this.comName,
    required this.sciName,
    required this.count,
    required this.locName,
    required this.lat,
    required this.lng,
    required this.dateSeen,
    this.notes = '',
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'speciesCode': speciesCode,
        'comName': comName,
        'sciName': sciName,
        'count': count,
        'locName': locName,
        'lat': lat,
        'lng': lng,
        'dateSeen': dateSeen.toIso8601String(),
        'notes': notes,
        'dateAdded': dateAdded.toIso8601String(),
      };

  factory LifeListEntry.fromJson(Map<String, dynamic> json) {
    return LifeListEntry(
      speciesCode: json['speciesCode'] ?? '',
      comName: json['comName'] ?? 'Unknown species',
      sciName: json['sciName'] ?? '',
      count: json['count'] ?? 1,
      locName: json['locName'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      dateSeen: DateTime.tryParse(json['dateSeen'] ?? '') ?? DateTime.now(),
      notes: json['notes'] ?? '',
      dateAdded: DateTime.tryParse(json['dateAdded'] ?? '') ?? DateTime.now(),
    );
  }
}
