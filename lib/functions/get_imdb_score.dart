import 'dart:convert';
import 'package:Mirarr/services/api_client.dart';

/// Gets the IMDb score for a given IMDb ID via the single-ID endpoint.
/// Returns the rating (averageRating) as a double, or `null` if not found/error.
Future<double?> getImdbScore(String imdbId) async {
  if (imdbId.isEmpty) return null;

  try {
    final response = await apiClient.get(
      Uri.parse('https://imdb-api.mahsaaghaali.ir/$imdbId'),
      timeout: const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data['averageRating'] != null) {
        return (data['averageRating'] as num).toDouble();
      }
    }
  } catch (_) {
    // Gracefully return null on network/parsing/timeout error
  }
  return null;
}

/// Gets IMDb scores for a list of IMDb IDs in a single batch request.
/// Returns a map mapping each IMDb ID to its averageRating.
Future<Map<String, double>> getImdbScoresBatch(List<String> imdbIds) async {
  if (imdbIds.isEmpty) return {};

  try {
    final response = await apiClient.post(
      Uri.parse('https://imdb-api.mahsaaghaali.ir/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ids': imdbIds}),
      timeout: const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final ratings = data['ratings'] as Map<String, dynamic>?;
      if (ratings != null) {
        final Map<String, double> result = {};
        for (var entry in ratings.entries) {
          final ratingInfo = entry.value;
          if (ratingInfo != null && ratingInfo['averageRating'] != null) {
            result[entry.key] = (ratingInfo['averageRating'] as num).toDouble();
          }
        }
        return result;
      }
    }
  } catch (_) {
    // Gracefully return empty map on network/parsing/timeout error
  }
  return {};
}
