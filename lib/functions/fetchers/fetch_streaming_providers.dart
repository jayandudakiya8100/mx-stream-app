import 'dart:convert';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String? _tmdbApiKey = dotenv.env['TMDB_API_KEY'];

List<Movie> _parseMoviesFromTmdb(String responseBody) {
  final List<Movie> movies = [];
  final Map<String, dynamic> data = json.decode(responseBody);
  final List<dynamic> results = data['results'] ?? [];

  for (var result in results) {
    final title = result['title'] ?? result['name'] ?? '';
    final releaseDate =
        result['release_date'] ?? result['first_air_date'] ?? '';
    final posterPath = result['poster_path'] ?? '';
    final backdropPath = result['backdrop_path'] as String?;
    final overview = result['overview'] ?? '';
    final id = (result['id'] as num?)?.toInt() ?? 0;
    final score = (result['vote_average'] as num?)?.toDouble() ?? 0.0;

    if (title.isNotEmpty && posterPath.isNotEmpty) {
      movies.add(
        Movie(
          title: title,
          releaseDate: releaseDate,
          posterPath: posterPath,
          backdropPath: backdropPath,
          overView: overview,
          id: id,
          score: score,
        ),
      );
    }
  }
  return movies;
}

/// Fetches movies and series available on Netflix (Provider ID: 8).
Future<List<Movie>> fetchNetflixContent(String region) async {
  final baseUrl = getBaseUrl(region);
  final watchRegion = region.toLowerCase() == 'worldwide' ? 'US' : region.toUpperCase();
  
  try {
    final url = Uri.parse(
      '${baseUrl}discover/movie?api_key=$_tmdbApiKey&with_watch_providers=8&watch_region=$watchRegion&sort_by=popularity.desc',
    );
    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      final list = _parseMoviesFromTmdb(response.body);
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}

  // Fallback to general discover with network ID 213 (Netflix network)
  try {
    final fallbackUrl = Uri.parse(
      '${baseUrl}discover/tv?api_key=$_tmdbApiKey&with_networks=213&sort_by=popularity.desc',
    );
    final response = await apiClient.get(fallbackUrl);
    if (response.statusCode == 200) {
      return _parseMoviesFromTmdb(response.body);
    }
  } catch (_) {}

  return [];
}

/// Fetches movies and series available on Disney Plus / Hotstar (Provider ID: 337 / 122).
Future<List<Movie>> fetchDisneyHotstarContent(String region) async {
  final baseUrl = getBaseUrl(region);
  final watchRegion = region.toLowerCase() == 'worldwide' ? 'US' : region.toUpperCase();

  try {
    final url = Uri.parse(
      '${baseUrl}discover/movie?api_key=$_tmdbApiKey&with_watch_providers=337|122&watch_region=$watchRegion&sort_by=popularity.desc',
    );
    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      final list = _parseMoviesFromTmdb(response.body);
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}

  // Fallback to Disney+ network 2739
  try {
    final fallbackUrl = Uri.parse(
      '${baseUrl}discover/tv?api_key=$_tmdbApiKey&with_networks=2739&sort_by=popularity.desc',
    );
    final response = await apiClient.get(fallbackUrl);
    if (response.statusCode == 200) {
      return _parseMoviesFromTmdb(response.body);
    }
  } catch (_) {}

  return [];
}

/// Fetches movies and series available on Amazon Prime (Provider ID: 9 / 119).
Future<List<Movie>> fetchAmazonPrimeContent(String region) async {
  final baseUrl = getBaseUrl(region);
  final watchRegion = region.toLowerCase() == 'worldwide' ? 'US' : region.toUpperCase();

  try {
    final url = Uri.parse(
      '${baseUrl}discover/movie?api_key=$_tmdbApiKey&with_watch_providers=9|119&watch_region=$watchRegion&sort_by=popularity.desc',
    );
    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      return _parseMoviesFromTmdb(response.body);
    }
  } catch (_) {}

  return [];
}
