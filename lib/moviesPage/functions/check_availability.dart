import 'dart:convert';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/services/api_client.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Region-keyed cache of in-flight/completed availability Futures so concurrent
/// callers (and rebuilds) share one HTTP request per movie+region.
final Map<String, Future<bool>> _availabilityFutures = {};

String _cacheKey(int movieId, String region) => '$region:$movieId';

void clearAvailabilityCache() {
  _availabilityFutures.clear();
}

/// Seed the shared cache from an already-fetched `watch/providers` payload.
void seedAvailabilityCache(int movieId, String region, bool available) {
  if (movieId < 0) return;
  _availabilityFutures[_cacheKey(movieId, region)] = Future.value(available);
}

bool availabilityFromProvidersPayload(Map<String, dynamic>? providers) {
  final results = providers?['results'];
  return results is Map && results.isNotEmpty;
}

Future<bool> checkAvailability(int movieId, String region) {
  if (movieId < 0) return Future.value(false);
  return _availabilityFutures.putIfAbsent(
    _cacheKey(movieId, region),
    () => _fetchAvailability(movieId, region),
  );
}

Future<bool> _fetchAvailability(int movieId, String region) async {
  final baseUrl = getBaseUrl(region);
  final apiKey = dotenv.env['TMDB_API_KEY'];
  final response = await apiClient.get(
    Uri.parse('${baseUrl}movie/$movieId/watch/providers?api_key=$apiKey'),
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    final Map<String, dynamic> results = data['results'];
    return results.isNotEmpty;
  }
  return false;
}
