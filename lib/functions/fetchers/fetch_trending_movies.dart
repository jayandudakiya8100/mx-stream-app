import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:Mirarr/functions/get_base_url.dart';

final apiKey = dotenv.env['TMDB_API_KEY'];

List<Movie> _parseMovies(String responseBody) {
  final List<Movie> movies = [];
  final List<dynamic> results = json.decode(responseBody)['results'] ?? [];

  for (var result in results) {
    final movie = Movie(
      title: result['title'] ?? '',
      releaseDate: result['release_date'] ?? '',
      posterPath: result['poster_path'] ?? '',
      overView: result['overview'] ?? '',
      id: (result['id'] as num?)?.toInt() ?? 0,
      score: (result['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
    movies.add(movie);
  }
  return movies;
}

Future<List<Movie>> fetchTrendingMovies(String region) async {
  final baseUrl = getBaseUrl(region);

  final response = await apiClient.get(
    Uri.parse(
      '${baseUrl}trending/movie/week?api_key=$apiKey',
    ),
  );

  if (response.statusCode == 200) {
    return _parseMovies(response.body);
  } else {
    throw Exception('Failed to load trending movie data');
  }
}

