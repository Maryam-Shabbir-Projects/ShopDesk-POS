import 'dart:convert';
import 'package:http/http.dart' as http;

/// Looks up a product photo on Open Food Facts (mostly food and drink).
/// Returns null when offline or nothing is found, so callers fall back to
/// the emoji icon. For a production build, do this lookup on your server
/// and store the image so photos also work offline.
class ProductImageService {
  static const _host = 'world.openfoodfacts.org';
  static const _timeout = Duration(seconds: 6);

  Future<String?> find({String? barcode, String? name}) async {
    try {
      if (barcode != null && barcode.isNotEmpty) {
        final uri = Uri.https(_host, '/api/v2/product/$barcode.json', {'fields': 'image_front_small_url'});
        final json = await _get(uri);
        final url = (json?['product'] as Map<String, dynamic>?)?['image_front_small_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      if (name != null && name.isNotEmpty) {
        final uri = Uri.https(_host, '/cgi/search.pl', {
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'page_size': '8',
          'fields': 'image_front_small_url',
          'search_terms': name,
        });
        final json = await _get(uri);
        for (final p in (json?['products'] as List<dynamic>? ?? const [])) {
          final url = (p as Map<String, dynamic>)['image_front_small_url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
