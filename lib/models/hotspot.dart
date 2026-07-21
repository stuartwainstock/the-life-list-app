/// A birding hotspot as returned by the eBird API
/// (https://api.ebird.org/v2/ref/hotspot/geo).
class Hotspot {
  final String locId;
  final String locName;
  final double lat;
  final double lng;
  final String countryCode;
  final String subnational1Code;
  final int? latestObsDt;
  final int? numSpeciesAllTime;

  Hotspot({
    required this.locId,
    required this.locName,
    required this.lat,
    required this.lng,
    required this.countryCode,
    required this.subnational1Code,
    this.latestObsDt,
    this.numSpeciesAllTime,
  });

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      locId: json['locId'] ?? '',
      locName: json['locName'] ?? 'Unnamed hotspot',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      countryCode: json['countryCode'] ?? '',
      subnational1Code: json['subnational1Code'] ?? '',
      numSpeciesAllTime: json['numSpeciesAllTime'],
    );
  }

  Map<String, dynamic> toJson() => {
        'locId': locId,
        'locName': locName,
        'lat': lat,
        'lng': lng,
        'countryCode': countryCode,
        'subnational1Code': subnational1Code,
        'numSpeciesAllTime': numSpeciesAllTime,
      };
}
