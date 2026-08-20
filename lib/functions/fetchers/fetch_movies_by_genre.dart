import 'dart:convert';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:mxstream/services/api_client.dart';

final apiKey = dotenv.env['TMDB_API_KEY'];

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});
}

List<Genre> _parseGenres(String responseBody) {
  final List<Genre> genres = [];
  final List<dynamic> results = json.decode(responseBody)['genres'];
  for (var result in results) {
    final genre = Genre(
      name: result['name'],
      id: result['id'],
    );
    genres.add(genre);
  }
  return genres;
}

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

Future<List<Genre>> fetchGenres(String region) async {
  final baseUrl = getBaseUrl(region);
  final response = await apiClient.get(
    Uri.parse('${baseUrl}genre/movie/list?api_key=$apiKey'),
  );

  if (response.statusCode == 200) {
    return _parseGenres(response.body);
  } else {
    throw Exception('Failed to load genres');
  }
}

Future<List<Movie>> fetchMoviesByGenre(int genreId, String region) async {
  final baseUrl = getBaseUrl(region);

  final response = await apiClient.get(
    Uri.parse(
      '${baseUrl}discover/movie?api_key=$apiKey&with_genres=$genreId',
    ),
  );

  if (response.statusCode == 200) {
    return _parseMovies(response.body);
  } else {
    throw Exception('Failed to load movies by genre');
  }
}

