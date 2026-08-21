import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/fetchers/fetch_movie_details.dart';
import 'package:mxstream/functions/fetchers/fetch_serie_details.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:mxstream/functions/fetchers/providers/core/models.dart';
import 'package:mxstream/functions/fetchers/providers/provider_config.dart';

class CastMember {
  final String name;
  final String character;
  final String image;

  CastMember({required this.name, required this.character, required this.image});
}

class EnrichedProviderItem {
  final Movie movie;
  final String type; // 'movie' or 'series'
  final String genres;
  final String runtimeOrSeasons;
  final String status;
  final List<CastMember> cast;
  final Map<String, dynamic> rawTmdbDetails;

  EnrichedProviderItem({
    required this.movie,
    required this.type,
    required this.genres,
    required this.runtimeOrSeasons,
    required this.status,
    required this.cast,
    required this.rawTmdbDetails,
  });
}

class ProviderMetadataMapper {
  /// Enriches a raw ProviderSearchItem with TMDB data if possible.
  /// Falls back to using the raw ProviderSearchItem data if TMDB fails or is not found.
  static Future<EnrichedProviderItem> enrichProviderItem(ProviderSearchItem item, String region) async {
    // 1. Clean the title to maximize TMDB search success
    String cleanTitle = item.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    cleanTitle = cleanTitle.split(RegExp(
      r'(\(|\{|WEB-DL|Blu-Ray|Season|Dual Audio|NetfFlix|JioHotstar|Amazon|HULU)', 
      caseSensitive: false
    )).first.trim();
    
    // 2. Try to fetch TMDB details
    if (cleanTitle.isNotEmpty) {
      final baseUrl = getBaseUrl(region);
      final imageBaseUrl = getImageBaseUrl(region);
      final apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
      final query = Uri.encodeComponent(cleanTitle);
      
      final searchUrl = item.type == 'series' 
          ? '${baseUrl}search/tv?api_key=$apiKey&query=$query'
          : '${baseUrl}search/movie?api_key=$apiKey&query=$query';
          
      try {
        final res = await http.get(Uri.parse(searchUrl));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final resultsList = data['results'] as List;
          
          if (resultsList.isNotEmpty) {
            final tmdbItem = resultsList.first;
            final int tmdbId = tmdbItem['id'];
            
            Map<String, dynamic> fullDetails;
            if (item.type == 'series') {
              fullDetails = await fetchSerieDetails(tmdbId, region, appendToResponse: ['credits']);
            } else {
              fullDetails = await fetchMovieDetails(tmdbId, region, appendToResponse: ['credits']);
            }
            
            final movie = Movie(
              title: fullDetails['title'] ?? fullDetails['name'] ?? cleanTitle,
              releaseDate: item.type == 'series' ? 'SERIES' : (fullDetails['release_date'] ?? ''),
              posterPath: fullDetails['poster_path'] != null ? '$imageBaseUrl/t/p/w500${fullDetails['poster_path']}' : item.poster,
              backdropPath: fullDetails['backdrop_path'] != null ? '$imageBaseUrl/t/p/original${fullDetails['backdrop_path']}' : item.poster,
              overView: fullDetails['overview'] ?? '',
              id: tmdbId, // Valid TMDB ID
              score: (fullDetails['vote_average'] as num?)?.toDouble() ?? 0.0,
            );

            final genres = (fullDetails['genres'] as List?)?.map((g) => g['name']).join(', ') ?? 'N/A';
            
            String runtimeOrSeasons = '';
            if (item.type == 'series') {
              runtimeOrSeasons = '${fullDetails['number_of_seasons'] ?? 0} Seasons | ${fullDetails['number_of_episodes'] ?? 0} Episodes';
            } else {
              runtimeOrSeasons = '${fullDetails['runtime'] ?? 0} mins';
            }

            final castList = <CastMember>[];
            final rawCast = fullDetails['credits']?['cast'] as List?;
            if (rawCast != null) {
              for (var c in rawCast) {
                castList.add(CastMember(
                  name: c['name'] ?? 'Unknown',
                  character: c['character'] ?? 'Unknown',
                  image: c['profile_path'] != null ? '$imageBaseUrl/t/p/w185${c['profile_path']}' : 'No Image',
                ));
              }
            }

            return EnrichedProviderItem(
              movie: movie,
              type: item.type,
              genres: genres,
              runtimeOrSeasons: runtimeOrSeasons,
              status: fullDetails['status'] ?? 'Unknown',
              cast: castList,
              rawTmdbDetails: fullDetails,
            );
          }
        }
      } catch (e) {
        debugPrint('ProviderMetadataMapper TMDB Error for "${item.title}": $e');
      }
    }
    
    // 3. Fallback: If TMDB fails or is not found, map directly from ProviderSearchItem
    final fallbackMovie = Movie(
      title: item.title,
      releaseDate: item.type == 'series' ? 'SERIES' : '',
      posterPath: item.poster,
      backdropPath: item.poster,
      overView: item.url, // Store the live watch URL in overview for fallback reference
      id: ProviderConfig.getStableMediaId(item.url),
      score: 0.0,
    );

    return EnrichedProviderItem(
      movie: fallbackMovie,
      type: item.type,
      genres: 'N/A',
      runtimeOrSeasons: 'N/A',
      status: 'Unknown',
      cast: [],
      rawTmdbDetails: {},
    );
  }
}
