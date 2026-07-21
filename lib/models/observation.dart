/// A single bird observation as returned by eBird
/// (`/v2/data/obs/geo/recent` and related endpoints).
///
/// Note: family / taxonomic order are **not** on this payload — join those
/// via [TaxonomyEntry] / [EbirdTaxonomyService] when grouping the list.
class Observation {
  final String speciesCode;
  final String comName;
  final String sciName;
  final String locId;
  final String locName;
  final DateTime obsDt;
  final int? howMany;
  final double lat;
  final double lng;
  final bool obsValid;
  final bool locationPrivate;

  Observation({
    required this.speciesCode,
    required this.comName,
    required this.sciName,
    required this.locId,
    required this.locName,
    required this.obsDt,
    required this.howMany,
    required this.lat,
    required this.lng,
    required this.obsValid,
    required this.locationPrivate,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      speciesCode: json['speciesCode'] ?? '',
      comName: json['comName'] ?? 'Unknown species',
      sciName: json['sciName'] ?? '',
      locId: json['locId'] ?? '',
      locName: json['locName'] ?? 'Unknown location',
      obsDt: DateTime.tryParse(json['obsDt'] ?? '') ?? DateTime.now(),
      howMany: json['howMany'],
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      obsValid: json['obsValid'] ?? true,
      locationPrivate: json['locationPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'speciesCode': speciesCode,
        'comName': comName,
        'sciName': sciName,
        'locId': locId,
        'locName': locName,
        'obsDt': obsDt.toIso8601String(),
        'howMany': howMany,
        'lat': lat,
        'lng': lng,
        'obsValid': obsValid,
        'locationPrivate': locationPrivate,
      };
}
