
import 'package:Mirarr/functions/fetchers/fetch_movie_details.dart';
import 'package:Mirarr/functions/fetchers/fetch_serie_details.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/moviesPage/functions/on_tap_movie.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:provider/provider.dart';

class TMDBUrlParser {
  static bool isTMDBMovieUrl(String url) {
    return url.contains('/movie/') ||
        url.startsWith('themoviedb://movie/') ||
        url.startsWith('mirarr://movie/');
  }

  static bool isTMDBTVUrl(String url) {
    return url.contains('/tv/') ||
        url.startsWith('themoviedb://tv/') ||
        url.startsWith('mirarr://tv/');
  }

  static Future<String> _getMovieTitle(
      int movieId, BuildContext context) async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final responseData = await fetchMovieDetails(movieId, region);
    return responseData['title'];
  }

  static int? parseMovieId(String url) {
    try {
      if (!url.contains('/movie/')) return null;
      String path = url.substring(url.indexOf('/movie/') + '/movie/'.length);
      String firstSegment = path.split(RegExp(r'[-/?#]')).first;
      return int.tryParse(firstSegment);
    } catch (e) {
      debugPrint('Error parsing movie ID: $e');
      return null;
    }
  }

  static Future<String> _getSerieTitle(
      int serieId, BuildContext context) async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final responseData = await fetchSerieDetails(serieId, region);
    return responseData['name'];
  }

  static int? parseSerieId(String url) {
    try {
      if (!url.contains('/tv/')) return null;
      String path = url.substring(url.indexOf('/tv/') + '/tv/'.length);
      String firstSegment = path.split(RegExp(r'[-/?#]')).first;
      return int.tryParse(firstSegment);
    } catch (e) {
      debugPrint('Error parsing TV URL: $e');
      return null;
    }
  }

  static Future<void> handleUrl(String url, BuildContext context) async {
    // Ensure we're on the main thread and the context is valid
    if (!context.mounted) return;

    if (isTMDBMovieUrl(url)) {
      final movieId = parseMovieId(url);
      if (movieId != null) {
        try {
          final movieTitle = await _getMovieTitle(movieId, context);
          if (context.mounted) {
            onTapMovie(movieTitle, movieId, context);
          }
        } catch (e) {
          debugPrint('Error fetching movie title: $e');
          if (context.mounted) {
            onTapMovie('', movieId, context);
          }
        }
      }
    } else if (isTMDBTVUrl(url)) {
      final serieId = parseSerieId(url);
      if (serieId != null) {
        try {
          final serieTitle = await _getSerieTitle(serieId, context);
          if (context.mounted) {
            onTapSerie(serieTitle, serieId, context);
          }
        } catch (e) {
          debugPrint('Error fetching TV title: $e');
          if (context.mounted) {
            onTapSerie('', serieId, context);
          }
        }
      }
    }
  }
}
