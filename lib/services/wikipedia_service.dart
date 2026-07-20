import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches a free species photo + short summary from Wikipedia's public
/// REST API. No key required. Used as a stand-in for eBird's photo
/// library (Macaulay Library media isn't available via a public API).
class WikipediaService {
  Future<WikiSummary?> fetchSummary(String query) async {
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    return WikiSummary(
      extract: json['extract'] ?? '',
      imageUrl: thumbnail != null ? thumbnail['source'] as String? : null,
    );
  }
}

class WikiSummary {
  final String extract;
  final String? imageUrl;
  WikiSummary({required this.extract, this.imageUrl});
}
