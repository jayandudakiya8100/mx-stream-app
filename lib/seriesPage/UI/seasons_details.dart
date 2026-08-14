import 'dart:convert';
import 'dart:ui';

import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/functions/get_imdb_score.dart';
import 'package:Mirarr/moviesPage/UI/cast_crew_row.dart';
import 'package:Mirarr/seriesPage/UI/tvchart_table.dart';
import 'package:Mirarr/seriesPage/checkers/custom_tmdb_ids_effects_series.dart';
import 'package:Mirarr/seriesPage/function/seasons_api_cache.dart';
import 'package:Mirarr/seriesPage/function/torrent_links_series.dart';
import 'package:Mirarr/seriesPage/function/watch_links_series.dart';
import 'package:Mirarr/widgets/custom_divider.dart';
import 'package:Mirarr/widgets/m3_expressive_spinner.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:provider/provider.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';

final apiKey = dotenv.env['TMDB_API_KEY'];
final apiOmdbKey = dotenv.env['OMDB_API_KEY_FOR_EPISODES'];

Future<String?> fetchEpisodeImdbId(
    BuildContext context, int serieId, int seasonNumber, int episodeNumber) async {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return cachedSeasonsApiCall('episode_imdb_id_${region}_${serieId}_${seasonNumber}_$episodeNumber', () async {
    try {
      final baseUrl = getBaseUrl(region);
      final response = await apiClient.get(
        Uri.parse('${baseUrl}tv/$serieId/season/$seasonNumber/episode/$episodeNumber/external_ids?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imdb_id'] as String?;
      }
    } catch (_) {
      // Ignore
    }
    return null;
  });
}

Future<String?> fetchImdbRating(
    BuildContext context, int serieId, String imdbId, int seasonNumber, int episodeNumber) async {
  return cachedSeasonsApiCall('imdb_rating_${serieId}_${seasonNumber}_$episodeNumber',
      () async {
    try {
      final response = await apiClient.get(
        Uri.parse(
            'http://www.omdbapi.com/?i=$imdbId&season=$seasonNumber&Episode=$episodeNumber&apikey=$apiOmdbKey'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final omdbRating = data['imdbRating'];
        if (omdbRating != null && omdbRating != 'N/A' && omdbRating.toString().trim().isNotEmpty) {
          return omdbRating.toString();
        }
        var episodeImdbId = data['imdbID'] as String?;
        if (episodeImdbId == null || episodeImdbId.isEmpty) {
          episodeImdbId = await fetchEpisodeImdbId(context, serieId, seasonNumber, episodeNumber);
        }
        if (episodeImdbId != null && episodeImdbId.isNotEmpty) {
          final scores = await getImdbScoresBatch([episodeImdbId]);
          final score = scores[episodeImdbId];
          if (score != null) {
            return score.toStringAsFixed(1);
          }
        }
        return omdbRating;
      }
    } catch (e) {
      try {
        final episodeImdbId = await fetchEpisodeImdbId(context, serieId, seasonNumber, episodeNumber);
        if (episodeImdbId != null && episodeImdbId.isNotEmpty) {
          final scores = await getImdbScoresBatch([episodeImdbId]);
          final score = scores[episodeImdbId];
          if (score != null) {
            return score.toStringAsFixed(1);
          }
        }
      } catch (_) {}
    }
    return null;
  });
}

Future<Map<int, String>> fetchSeasonImdbRatings(
    BuildContext context, int serieId, String imdbId, int seasonNumber, List<int> tmdbEpisodeNumbers) async {
  return cachedSeasonsApiCall('season_ratings_${serieId}_$seasonNumber', () async {
    final Map<int, String> ratingsMap = {};
    final List<Map<String, dynamic>> pending = [];
    final Set<int> episodesFetchedFromOmdb = {};

    try {
      final response = await apiClient.get(
        Uri.parse(
            'http://www.omdbapi.com/?i=$imdbId&Season=$seasonNumber&apikey=$apiOmdbKey'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Episodes'] != null) {
          final episodes = data['Episodes'] as List<dynamic>;

          for (var episode in episodes) {
            final epNum = episode['Episode'] is int
                ? episode['Episode'] as int
                : int.parse(episode['Episode'].toString());
            final rating = episode['imdbRating'] as String?;
            final epImdbId = episode['imdbID'] as String?;

            episodesFetchedFromOmdb.add(epNum);

            if (rating != null && rating != 'N/A' && rating.trim().isNotEmpty) {
              ratingsMap[epNum] = rating;
            } else if (epImdbId != null && epImdbId.isNotEmpty) {
              pending.add({
                'episodeNumber': epNum,
                'imdbID': epImdbId,
              });
              ratingsMap[epNum] = 'N/A';
            } else {
              ratingsMap[epNum] = 'N/A';
            }
          }
        }
      }
    } catch (_) {
      // Ignore OMDB error, we will fall back to TMDB for missing/all episodes
    }

    // Identify all episodes that TMDB has but OMDB didn't return
    final List<int> missingEpisodeNumbers = tmdbEpisodeNumbers
        .where((epNum) => !episodesFetchedFromOmdb.contains(epNum))
        .toList();

    if (missingEpisodeNumbers.isNotEmpty) {
      // Fetch TMDB external IDs for these missing episodes in parallel
      final List<Future<String?>> futures = missingEpisodeNumbers
          .map((epNum) => fetchEpisodeImdbId(context, serieId, seasonNumber, epNum))
          .toList();

      final List<String?> imdbIds = await Future.wait(futures);

      for (int i = 0; i < missingEpisodeNumbers.length; i++) {
        final epNum = missingEpisodeNumbers[i];
        final epImdbId = imdbIds[i];
        if (epImdbId != null && epImdbId.isNotEmpty) {
          pending.add({
            'episodeNumber': epNum,
            'imdbID': epImdbId,
          });
        }
        ratingsMap[epNum] = 'N/A';
      }
    }

    // Now batch-fetch all pending episode ratings using our custom API
    if (pending.isNotEmpty) {
      try {
        final pendingImdbIds = pending.map((e) => e['imdbID'] as String).toList();
        final scoresMap = await getImdbScoresBatch(pendingImdbIds);
        for (var item in pending) {
          final epNum = item['episodeNumber'] as int;
          final epImdbId = item['imdbID'] as String;
          if (scoresMap.containsKey(epImdbId)) {
            ratingsMap[epNum] = scoresMap[epImdbId]!.toStringAsFixed(1);
          }
        }
      } catch (_) {
        // Ignore error
      }
    }

    return ratingsMap;
  });
}


void seasonsAndEpisodes(
  BuildContext context,
  int serieId,
  String serieName,
  String imdbId, {
  required List<dynamic> seasons,
  String? imagePath,
  VoidCallback? onWatchStatusChanged,
}) {
  final sortedSeasons = List<dynamic>.from(seasons)
    ..sort((a, b) {
      if (a['season_number'] == 0) return 1;
      if (b['season_number'] == 0) return -1;
      return a['season_number'].compareTo(b['season_number']);
    });

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 800),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      final isLargeScreen = MediaQuery.sizeOf(context).width >= 800;
      final double sheetHeight =
          MediaQuery.sizeOf(context).height * (isLargeScreen ? 0.75 : 0.60);

      if (sortedSeasons.isEmpty) {
        return Container(
          height: sheetHeight,
          alignment: Alignment.center,
          child: const Text('No seasons found.'),
        );
      }

      final seasons = sortedSeasons;

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        height: sheetHeight,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(
                  physics: const BouncingScrollPhysics(),
                  scrollbars: true,
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 400),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TvChartTable(
                                        imdbId: imdbId,
                                        imagePath: imagePath,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      getSeriesColor(context, serieId),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: Text('View Episode Ratings Table',
                                    style: getSeriesButtonTextStyle(serieId)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 0, 16),
                            child: Text('Seasons',
                                style: getSeriesTitleTextStyle(serieId)),
                          ),
                        ],
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final season = seasons[index];
                          final region = Provider.of<RegionProvider>(context,
                                  listen: false)
                              .currentRegion;
                          final coverUrl = season['poster_path'] != null
                              ? '${getImageBaseUrl(region)}/t/p/w500${season['poster_path']}'
                              : null;
                          final isAirDateNull = season['air_date'] == null;
                          final isEpisodeCountZero =
                              season['episode_count'] == 0;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6.0),
                                  child: Container(
                                    width: 50,
                                    height: 75,
                                    color: Colors.black,
                                    child: coverUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Skeletonizer(
                                              enabled: true,
                                              containersColor: Colors.white
                                                  .withOpacity(0.05),
                                              effect: ShimmerEffect(
                                                baseColor: Colors.white
                                                    .withOpacity(0.05),
                                                highlightColor: Colors.white
                                                    .withOpacity(0.15),
                                              ),
                                              child: Container(
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error,
                                                        color: Colors.white54,
                                                        size: 20),
                                          )
                                        : const Icon(Icons.movie,
                                            color: Colors.white54, size: 20),
                                  ),
                                ),
                                title: Text(
                                  season['season_number'] == 0
                                      ? 'Specials'
                                      : 'Season ${season['season_number']}',
                                  style: TextStyle(
                                    color: isAirDateNull
                                        ? Colors.grey
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '${season['episode_count']} ${season['episode_count'] == 1 ? 'Episode' : 'Episodes'}'
                                  '${season['air_date'] != null && season['air_date'].toString().isNotEmpty ? ' • ${season['air_date'].toString().split('-')[0]}' : ''}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SeasonWatchToggle(
                                      serieId: serieId,
                                      serieName: serieName,
                                      seasonNumber: season['season_number'],
                                      posterPath: season['poster_path'],
                                      episodeCount: season['episode_count'],
                                      onToggle: () {
                                        onWatchStatusChanged?.call();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: isAirDateNull
                                          ? Colors.grey
                                          : getSeriesColor(context, serieId),
                                    ),
                                  ],
                                ),
                                onTap: isAirDateNull && isEpisodeCountZero
                                    ? null
                                    : () => episodesGuide(
                                        season['season_number'],
                                        context,
                                        serieId,
                                        serieName,
                                        imdbId,
                                        coverUrl,
                                        onWatchStatusChanged:
                                            onWatchStatusChanged),
                              ),
                              const CustomDivider()
                            ],
                          );
                        },
                        childCount: seasons.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<List<dynamic>> fetchEpisodesGuide(BuildContext context, int seasonNumber,
    int serieId, String serieName, String imdbId) async {
  final region =
      Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return cachedSeasonsApiCall(
      'episodes_guide_${region}_${serieId}_$seasonNumber', () async {
    final baseUrl = getBaseUrl(region);
    final episodesResponse = await apiClient.get(
      Uri.parse('${baseUrl}tv/$serieId/season/$seasonNumber?api_key=$apiKey'),
    );

    if (episodesResponse.statusCode == 200) {
      final data = json.decode(episodesResponse.body);
      final episodes = data['episodes'] as List<dynamic>;
      final List<int> tmdbEpisodeNumbers = episodes
          .map((e) => e['episode_number'] is int
              ? e['episode_number'] as int
              : int.parse(e['episode_number'].toString()))
          .toList();

      final ratingsMap = await fetchSeasonImdbRatings(
          context, serieId, imdbId, seasonNumber, tmdbEpisodeNumbers);

      for (var episode in episodes) {
        final episodeNumber = episode['episode_number'];
        episode['imdb_rating'] = ratingsMap[episodeNumber] ?? 'N/A';
      }

      return episodes;
    } else {
      throw Exception('Failed to load episodes');
    }
  });
}

void episodesGuide(int seasonNumber, BuildContext context, int serieId,
    String serieName, String imdbId, String? seasonPosterPath, {VoidCallback? onWatchStatusChanged}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 800),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return _EpisodesGuideSheet(
        seasonNumber: seasonNumber,
        serieId: serieId,
        serieName: serieName,
        imdbId: imdbId,
        seasonPosterPath: seasonPosterPath,
        onWatchStatusChanged: onWatchStatusChanged,
      );
    },
  );
}

Future<Map<String, dynamic>> fetchEpisodesDetails(BuildContext context,
    int seasonNumber, int episodeNumber, int serieId) async {
  final region =
      Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return cachedSeasonsApiCall(
      'episode_details_${region}_${serieId}_${seasonNumber}_$episodeNumber',
      () async {
    final baseUrl = getBaseUrl(region);
    final response = await apiClient.get(
      Uri.parse(
          '${baseUrl}tv/$serieId/season/$seasonNumber/episode/$episodeNumber?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  });
}

void episodeDetails(int seasonNumber, int episodeNumber, BuildContext context,
    int serieId, String serieName, String imdbId, String? seasonPosterPath, {VoidCallback? onWatchStatusChanged}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 800),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return _EpisodeDetailsSheet(
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        serieId: serieId,
        serieName: serieName,
        imdbId: imdbId,
        seasonPosterPath: seasonPosterPath,
        onWatchStatusChanged: onWatchStatusChanged,
      );
    },
  );
}

class _EpisodesGuideSheet extends StatefulWidget {
  const _EpisodesGuideSheet({
    required this.seasonNumber,
    required this.serieId,
    required this.serieName,
    required this.imdbId,
    required this.seasonPosterPath,
    this.onWatchStatusChanged,
  });

  final int seasonNumber;
  final int serieId;
  final String serieName;
  final String imdbId;
  final String? seasonPosterPath;
  final VoidCallback? onWatchStatusChanged;

  @override
  State<_EpisodesGuideSheet> createState() => _EpisodesGuideSheetState();
}

class _EpisodesGuideSheetState extends State<_EpisodesGuideSheet> {
  Future<List<dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= Future.wait([
      fetchEpisodesGuide(
        context,
        widget.seasonNumber,
        widget.serieId,
        widget.serieName,
        widget.imdbId,
      ),
      _watchHistoryDb.getWatchHistoryByTmdbId(widget.serieId, 'tv'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final isLargeScreen = MediaQuery.sizeOf(context).width >= 800;
        final double sheetHeight =
            MediaQuery.sizeOf(context).height * (isLargeScreen ? 0.75 : 0.60);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: sheetHeight,
            alignment: Alignment.center,
            child: const M3ExpressiveSpinner(),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: sheetHeight,
            alignment: Alignment.center,
            child: Text('Error: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: sheetHeight,
            alignment: Alignment.center,
            child: const Text('No episodes found.'),
          );
        }

        final episodes = snapshot.data![0] as List<dynamic>;
        final watchHistory = snapshot.data![1] as List<WatchHistoryItem>;
        final watchedSet = watchHistory
            .where((item) =>
                item.seasonNumber == widget.seasonNumber &&
                item.episodeNumber != null)
            .map((item) => item.episodeNumber!)
            .toSet();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          height: sheetHeight,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Text('Episodes', style: getSeriesTitleTextStyle(widget.serieId)),
              const SizedBox(height: 10),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const ScrollBehavior().copyWith(
                    scrollbars: true,
                    physics: const BouncingScrollPhysics(),
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.builder(
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      final region = Provider.of<RegionProvider>(context,
                              listen: false)
                          .currentRegion;
                      final coverUrl = episode['still_path'] != null
                          ? '${getImageBaseUrl(region)}/t/p/w500${episode['still_path']}'
                          : null;

                      bool isReleased = true;
                      int daysUntilRelease = 0;
                      if (episode['air_date'] != null) {
                        try {
                          final airDate = DateTime.parse(episode['air_date']);
                          isReleased = airDate.isBefore(DateTime.now());
                          if (!isReleased) {
                            daysUntilRelease =
                                airDate.difference(DateTime.now()).inDays;
                          }
                        } catch (_) {}
                      }
                      return Column(
                        children: [
                          InkWell(
                            onTap: () => episodeDetails(
                              widget.seasonNumber,
                              episode['episode_number'],
                              context,
                              widget.serieId,
                              widget.serieName,
                              widget.imdbId,
                              coverUrl,
                              onWatchStatusChanged: widget.onWatchStatusChanged,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6.0),
                                    child: Container(
                                      width: 110,
                                      height: 62,
                                      color: Colors.black,
                                      child: coverUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: coverUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Skeletonizer(
                                                enabled: true,
                                                containersColor: Colors.white
                                                    .withOpacity(0.05),
                                                effect: ShimmerEffect(
                                                  baseColor: Colors.white
                                                      .withOpacity(0.05),
                                                  highlightColor: Colors.white
                                                      .withOpacity(0.15),
                                                ),
                                                child: Container(
                                                  color: Colors.grey[900],
                                                ),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(Icons.error,
                                                          color: Colors.white54,
                                                          size: 20),
                                            )
                                          : const Icon(Icons.tv,
                                              color: Colors.white54, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          episode['episode_number'] == 0
                                              ? 'Specials'
                                              : 'Episode ${episode['episode_number']}',
                                          style: TextStyle(
                                            color: isReleased
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (episode['name'] != null &&
                                            episode['name']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            episode['name'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        const SizedBox(height: 2),
                                        if (episode['air_date'] != null &&
                                            episode['air_date']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            episode['air_date'],
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isReleased && daysUntilRelease >= 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            '$daysUntilRelease days',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12),
                                          ),
                                        ),
                                      if (episode['imdb_rating'] != null &&
                                          episode['imdb_rating'] != 'N/A' &&
                                          episode['imdb_rating']
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: Text(
                                            '⭐ ${episode['imdb_rating']}',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      EpisodeWatchToggle(
                                        serieId: widget.serieId,
                                        serieName: widget.serieName,
                                        seasonNumber: widget.seasonNumber,
                                        episodeNumber:
                                            episode['episode_number'],
                                        episodeTitle: episode['name'],
                                        posterPath: widget.seasonPosterPath,
                                        initialIsWatched: watchedSet
                                            .contains(episode['episode_number']),
                                        onToggle: () {
                                          widget.onWatchStatusChanged?.call();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: isReleased
                                            ? getSeriesColor(
                                                context, widget.serieId)
                                            : Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const CustomDivider()
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeDetailsSheet extends StatefulWidget {
  const _EpisodeDetailsSheet({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.serieId,
    required this.serieName,
    required this.imdbId,
    required this.seasonPosterPath,
    this.onWatchStatusChanged,
  });

  final int seasonNumber;
  final int episodeNumber;
  final int serieId;
  final String serieName;
  final String imdbId;
  final String? seasonPosterPath;
  final VoidCallback? onWatchStatusChanged;

  @override
  State<_EpisodeDetailsSheet> createState() => _EpisodeDetailsSheetState();
}

class _EpisodeDetailsSheetState extends State<_EpisodeDetailsSheet> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= Future.wait([
      fetchEpisodesDetails(
        context,
        widget.seasonNumber,
        widget.episodeNumber,
        widget.serieId,
      ),
      fetchImdbRating(
        context,
        widget.serieId,
        widget.imdbId,
        widget.seasonNumber,
        widget.episodeNumber,
      ),
    ]).then((results) => {
          'episodeDetails': results[0],
          'imdbRating': results[1],
        });
  }

  List<Map<String, dynamic>> _mapsFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            alignment: Alignment.center,
            child: const M3ExpressiveSpinner(),
          );
        } else if (snapshot.hasError) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: Text('Error: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text('No data found.'),
          );
        }

        final episodeDetails =
            snapshot.data!['episodeDetails'] as Map<String, dynamic>;
        final imdbRating = snapshot.data!['imdbRating'];
        final overview =
            episodeDetails['overview'] ?? 'No overview available.';
        final episodeName = episodeDetails['name'] ?? '';
        final castList = _mapsFrom(episodeDetails['guest_stars']);
        final crewList = _mapsFrom(episodeDetails['crew']);
        final isLargeScreen = MediaQuery.sizeOf(context).width >= 800;

        final watchButton = FloatingActionButton(
          heroTag: null,
          backgroundColor: getSeriesColor(context, widget.serieId),
          onPressed: () => showWatchOptions(
            context,
            widget.serieId,
            widget.seasonNumber,
            widget.episodeNumber,
            widget.imdbId,
          ),
          child: Text(
            'Watch',
            style: getSeriesButtonTextStyle(widget.serieId),
          ),
        );

        final torrentButton = FloatingActionButton(
          heroTag: null,
          backgroundColor: getSeriesColor(context, widget.serieId),
          onPressed: () => showTorrentOptions(
            context,
            widget.serieName,
            widget.serieId,
            widget.seasonNumber,
            widget.episodeNumber,
            widget.imdbId,
          ),
          child: Text(
            'Torrent Search',
            style: getSeriesButtonTextStyle(widget.serieId),
          ),
        );

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                episodeName.toString().isNotEmpty
                    ? Text(episodeName,
                        style: getSeriesTitleTextStyle(widget.serieId))
                    : Text('Episode Overview',
                        style: getSeriesTitleTextStyle(widget.serieId)),
                const SizedBox(height: 10),
                if (imdbRating != null &&
                    imdbRating.toString().isNotEmpty &&
                    imdbRating != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'IMDB⭐ $imdbRating',
                      style: const TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 13,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: EpisodeWatchToggleButton(
                    serieId: widget.serieId,
                    serieName: widget.serieName,
                    seasonNumber: widget.seasonNumber,
                    episodeNumber: widget.episodeNumber,
                    episodeTitle: episodeName,
                    posterPath: widget.seasonPosterPath,
                    onToggle: () {
                      widget.onWatchStatusChanged?.call();
                    },
                  ),
                ),
                Text(
                  overview,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (isLargeScreen)
                  Row(
                    children: [
                      Expanded(child: watchButton),
                      const SizedBox(width: 16),
                      Expanded(child: torrentButton),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: watchButton,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: torrentButton,
                      ),
                    ],
                  ),
                if (castList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Guest Stars',
                      style: getSeriesTitleTextStyle(widget.serieId),
                    ),
                  ),
                  const CustomDivider(),
                  buildCastRow(castList, context),
                ],
                if (crewList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Crew',
                      style: getSeriesTitleTextStyle(widget.serieId),
                    ),
                  ),
                  const CustomDivider(),
                  buildCrewRow(crewList, context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// Watch history helper functions
final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();

Future<bool> isSeasonWatched(int serieId, int seasonNumber, BuildContext context, {int? episodeCount}) async {
  try {
    int totalEpisodes = episodeCount ?? 0;
    if (totalEpisodes == 0) {
      final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final baseUrl = getBaseUrl(region);
      final episodesResponse = await apiClient.get(
        Uri.parse('${baseUrl}tv/$serieId/season/$seasonNumber?api_key=$apiKey'),
      );
      
      if (episodesResponse.statusCode == 200) {
        final episodeData = json.decode(episodesResponse.body);
        final episodesList = episodeData['episodes'] as List<dynamic>;
        totalEpisodes = episodesList.length;
      }
    }
    
    if (totalEpisodes == 0) return false;
    
    // Get watched episodes for this season
    final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(serieId, 'tv');
    final watchedEpisodesInSeason = watchHistory.where((item) => item.seasonNumber == seasonNumber).length;
    
    return watchedEpisodesInSeason == totalEpisodes;
  } catch (e) {
    // Fallback to old logic if API call fails
    final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(serieId, 'tv');
    final seasonEpisodes = watchHistory.where((item) => item.seasonNumber == seasonNumber).toList();
    return seasonEpisodes.isNotEmpty;
  }
  
  return false;
}

Future<bool> isEpisodeWatched(int serieId, int seasonNumber, int episodeNumber) async {
  return await _watchHistoryDb.isWatched(serieId, 'tv', seasonNumber: seasonNumber, episodeNumber: episodeNumber);
}

Future<void> toggleSeasonWatched(int serieId, String serieName, int seasonNumber, String? posterPath, BuildContext context, {VoidCallback? onToggle}) async {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  final baseUrl = getBaseUrl(region);
  
  // Check if season is currently watched
  final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(serieId, 'tv');
  final seasonEpisodes = watchHistory.where((item) => item.seasonNumber == seasonNumber).toList();
  
  if (seasonEpisodes.isNotEmpty) {
    // Remove all episodes of this season
    await _watchHistoryDb.deleteWatchHistoryItemsBatch([
      for (final episode in seasonEpisodes)
        if (episode.id != null) episode.id!,
    ]);
  } else {
    // Mark all episodes of this season as watched
    try {
      final episodesResponse = await apiClient.get(
        Uri.parse('${baseUrl}tv/$serieId/season/$seasonNumber?api_key=$apiKey'),
      );

      if (episodesResponse.statusCode == 200) {
        final episodeData = json.decode(episodesResponse.body);
        final episodesList = episodeData['episodes'] as List<dynamic>;
        final watchedAt = DateTime.now();

        await _watchHistoryDb.addShowEpisodesBatch([
          for (final episode in episodesList)
            WatchHistoryItem(
              tmdbId: serieId,
              title: serieName,
              type: 'tv',
              posterPath: posterPath,
              watchedAt: watchedAt,
              seasonNumber: seasonNumber,
              episodeNumber: episode['episode_number'] as int?,
              episodeTitle: episode['name'] as String?,
            ),
        ]);
      }
    } catch (e) {
      throw Exception('Failed to toggle season watch status: $e');
    }
  }
  
  // Call the callback to refresh parent state
  onToggle?.call();
}

Future<void> toggleEpisodeWatched(int serieId, String serieName, int seasonNumber, int episodeNumber, String? episodeTitle, String? posterPath, {VoidCallback? onToggle}) async {
  final isWatched = await isEpisodeWatched(serieId, seasonNumber, episodeNumber);
  
  if (isWatched) {
    // Remove episode from watch history
    final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(serieId, 'tv');
    final episode = watchHistory.firstWhere(
      (item) => item.seasonNumber == seasonNumber && item.episodeNumber == episodeNumber,
    );
    await _watchHistoryDb.deleteWatchHistoryItem(episode.id!);
  } else {
    // Add episode to watch history
    await _watchHistoryDb.addShowToHistory(
      tmdbId: serieId,
      title: serieName,
      posterPath: posterPath,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
    );
  }
  
  // Call the callback to refresh parent state
  onToggle?.call();
}

// Custom widget for smooth season watch toggle
class SeasonWatchToggle extends StatefulWidget {
  final int serieId;
  final String serieName;
  final int seasonNumber;
  final String? posterPath;
  final int? episodeCount;
  final bool? initialIsWatched;
  final VoidCallback? onToggle;

  const SeasonWatchToggle({
    Key? key,
    required this.serieId,
    required this.serieName,
    required this.seasonNumber,
    required this.posterPath,
    this.episodeCount,
    this.initialIsWatched,
    this.onToggle,
  }) : super(key: key);

  @override
  State<SeasonWatchToggle> createState() => _SeasonWatchToggleState();
}

class _SeasonWatchToggleState extends State<SeasonWatchToggle> {
  bool? _isWatched;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsWatched != null) {
      _isWatched = widget.initialIsWatched;
    } else {
      _loadWatchStatus();
    }
  }

  Future<void> _loadWatchStatus() async {
    final isWatched = await isSeasonWatched(widget.serieId, widget.seasonNumber, context, episodeCount: widget.episodeCount);
    if (mounted) {
      setState(() {
        _isWatched = isWatched;
      });
    }
  }

  Future<void> _toggleWatchStatus() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await toggleSeasonWatched(
        widget.serieId,
        widget.serieName,
        widget.seasonNumber,
        widget.posterPath,
        context,
        onToggle: () {
          widget.onToggle?.call();
        },
      );
      
      // Update local state immediately for smooth transition
      setState(() {
        _isWatched = !(_isWatched ?? false);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isWatched == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      );
    }

    return TvFocusWrapper(
      borderRadius: 10.0,
      onTap: _toggleWatchStatus,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            _isWatched! ? Icons.check_circle : Icons.visibility_off,
            key: ValueKey(_isWatched),
            color: _isWatched! ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// Custom widget for smooth episode watch toggle
class EpisodeWatchToggle extends StatefulWidget {
  final int serieId;
  final String serieName;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;
  final String? posterPath;
  final bool? initialIsWatched;
  final VoidCallback? onToggle;

  const EpisodeWatchToggle({
    Key? key,
    required this.serieId,
    required this.serieName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.posterPath,
    this.initialIsWatched,
    this.onToggle,
  }) : super(key: key);

  @override
  State<EpisodeWatchToggle> createState() => _EpisodeWatchToggleState();
}

class _EpisodeWatchToggleState extends State<EpisodeWatchToggle> {
  bool? _isWatched;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsWatched != null) {
      _isWatched = widget.initialIsWatched;
    } else {
      _loadWatchStatus();
    }
  }

  Future<void> _loadWatchStatus() async {
    final isWatched = await isEpisodeWatched(widget.serieId, widget.seasonNumber, widget.episodeNumber);
    if (mounted) {
      setState(() {
        _isWatched = isWatched;
      });
    }
  }

  Future<void> _toggleWatchStatus() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await toggleEpisodeWatched(
        widget.serieId,
        widget.serieName,
        widget.seasonNumber,
        widget.episodeNumber,
        widget.episodeTitle,
        widget.posterPath,
        onToggle: () {
          widget.onToggle?.call();
        },
      );
      
      // Update local state immediately for smooth transition
      setState(() {
        _isWatched = !(_isWatched ?? false);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isWatched == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      );
    }

    return TvFocusWrapper(
      borderRadius: 10.0,
      onTap: _toggleWatchStatus,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            _isWatched! ? Icons.check_circle : Icons.visibility_off,
            key: ValueKey(_isWatched),
            color: _isWatched! ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// Custom widget for smooth episode watch toggle button (for episode details)
class EpisodeWatchToggleButton extends StatefulWidget {
  final int serieId;
  final String serieName;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;
  final String? posterPath;
  final bool? initialIsWatched;
  final VoidCallback? onToggle;

  const EpisodeWatchToggleButton({
    Key? key,
    required this.serieId,
    required this.serieName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.posterPath,
    this.initialIsWatched,
    this.onToggle,
  }) : super(key: key);

  @override
  State<EpisodeWatchToggleButton> createState() => _EpisodeWatchToggleButtonState();
}

class _EpisodeWatchToggleButtonState extends State<EpisodeWatchToggleButton> {
  bool? _isWatched;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsWatched != null) {
      _isWatched = widget.initialIsWatched;
    } else {
      _loadWatchStatus();
    }
  }

  Future<void> _loadWatchStatus() async {
    final isWatched = await isEpisodeWatched(widget.serieId, widget.seasonNumber, widget.episodeNumber);
    if (mounted) {
      setState(() {
        _isWatched = isWatched;
      });
    }
  }

  Future<void> _toggleWatchStatus() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await toggleEpisodeWatched(
        widget.serieId,
        widget.serieName,
        widget.seasonNumber,
        widget.episodeNumber,
        widget.episodeTitle,
        widget.posterPath,
        onToggle: () {
          widget.onToggle?.call();
        },
      );
      
      // Update local state immediately for smooth transition
      setState(() {
        _isWatched = !(_isWatched ?? false);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isWatched == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 4),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return TvFocusWrapper(
      borderRadius: 20.0,
      onTap: _toggleWatchStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isWatched! ? Colors.green.withValues(alpha: 0.7) : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Row(
            key: ValueKey(_isWatched),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWatched! ? Icons.check_circle : Icons.visibility_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _isWatched! ? 'Watched' : 'Mark as Watched',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
