import 'dart:convert';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/services/api_client.dart';

final apiKey = dotenv.env['TMDB_API_KEY'];

List<Serie> _parseSeries(String responseBody) {
  final List<Serie> series = [];
  final List<dynamic> results = json.decode(responseBody)['results'];

  for (var result in results) {
    final serie = Serie(
      name: result['name'] ?? '',
      posterPath: result['poster_path'] ?? '',
      overView: result['overview'] ?? '',
      id: result['id'],
      score: (result['vote_average'] as num?)?.toDouble(),
    );
    series.add(serie);
  }

  return series;
}

Future<List<Serie>> fetchPopularSeries(String region) async {
  final baseUrl = getBaseUrl(region);
  final response = await apiClient.get(
    Uri.parse('${baseUrl}tv/popular?api_key=$apiKey'),
  );

  if (response.statusCode == 200) {
    return _parseSeries(response.body);
  } else {
    throw Exception('Failed to load popular series data');
  }
}
