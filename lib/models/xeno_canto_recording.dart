/// One playable Xeno-canto recording (Song or Call) for species detail.
///
/// Fields map to the Xeno-canto API v3 recording object — only what the
/// lightweight Songs & Calls UI needs
/// (`docs/tickets/xeno-canto-audio.md`).
class XenoCantoRecording {
  final String fileUrl;
  final String recordistName;
  final String licenseUrl;
  final String qualityRating;
  final String soundType;
  final String lengthLabel;

  const XenoCantoRecording({
    required this.fileUrl,
    required this.recordistName,
    required this.licenseUrl,
    required this.qualityRating,
    required this.soundType,
    required this.lengthLabel,
  });

  /// Returns null when [file] is missing/redacted (sensitive species) or
  /// the payload is otherwise unusable for playback.
  static XenoCantoRecording? tryParse(Map<String, dynamic> json) {
    final rawFile = json['file']?.toString().trim() ?? '';
    if (rawFile.isEmpty) return null;

    final fileUrl = rawFile.startsWith('//')
        ? 'https:$rawFile'
        : rawFile.startsWith('http')
            ? rawFile
            : 'https://xeno-canto.org$rawFile';

    final lic = json['lic']?.toString().trim() ?? '';
    if (lic.isEmpty) return null;

    return XenoCantoRecording(
      fileUrl: fileUrl,
      recordistName: (json['rec']?.toString().trim().isNotEmpty ?? false)
          ? json['rec'].toString().trim()
          : 'Unknown recordist',
      licenseUrl: lic,
      qualityRating: json['q']?.toString().trim() ?? '',
      soundType: json['type']?.toString().trim() ?? '',
      lengthLabel: json['length']?.toString().trim() ?? '',
    );
  }

  /// Attribution line matching the photo-credit pattern (recordist · license).
  String get attributionText {
    final len = lengthLabel.isNotEmpty ? ' · $lengthLabel' : '';
    return '$recordistName$len';
  }
}
