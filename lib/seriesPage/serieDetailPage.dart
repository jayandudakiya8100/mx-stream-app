import 'package:mxstream/widgets/profile.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/functions/platform_helper.dart';

import 'package:mxstream/database/watch_history_database.dart';
import 'package:mxstream/models/watch_history_model.dart';
import 'package:mxstream/functions/fetchers/fetch_serie_details.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/functions/share_content.dart';
import 'package:mxstream/seriesPage/UI/seasons_details.dart';
import 'package:mxstream/seriesPage/UI/serie_action_buttons.dart';
import 'package:mxstream/seriesPage/checkers/custom_tmdb_ids_effects_series.dart';
import 'package:mxstream/seriesPage/function/get_imdb_rating_series.dart';
import 'package:mxstream/seriesPage/function/series_tmdb_actions.dart';
import 'package:mxstream/moviesPage/UI/movie_action_buttons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:mxstream/seriesPage/function/watch_links_series.dart';
import 'package:mxstream/seriesPage/function/torrent_links_series.dart';
import 'package:mxstream/moviesPage/functions/f2m_parser.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mxstream/seriesPage/UI/iran_series_f2m_page.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';
import 'package:mxstream/widgets/m3_expressive_rating_bar.dart';
import 'package:hive/hive.dart';
import 'package:mxstream/services/api_client.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mxstream/moviesPage/UI/cast_crew_row.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/custom_divider.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';
import 'package:mxstream/homePage/widgets/set_watch_status_modal.dart';
import 'package:mxstream/functions/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:ui';

part 'serieDetailPageMobile.dart';
part 'serieDetailPageDesktop.dart';

class SerieDetailPage extends StatefulWidget {
  final String serieName;
  final int serieId;

  const SerieDetailPage(
      {super.key, required this.serieName, required this.serieId});

  @override
  _SerieDetailPageState createState() => _SerieDetailPageState();
}

class _SerieDetailPageState extends State<SerieDetailPage> {
  final apiKey = dotenv.env['TMDB_API_KEY'];
  Map<String, dynamic>? serieDetails;
  Map<String, dynamic>? externalIds;

  Map<String, dynamic>? serieInfo;
  final isSerieWatchlist = ValueNotifier<bool?>(null);
  final isSerieFavorite = ValueNotifier<bool?>(null);
  Future<dynamic>? _creditsFuture;
  final isUserLoggedIn = ValueNotifier<bool>(false);
  final isSerieRated = ValueNotifier<dynamic>(null);
  final userRating = ValueNotifier<double?>(null);
  double? userScore;
  String? posterPath;
  final screenShotController = ScreenshotController();

  void updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  double? popularity;
  int? budget;
  List<dynamic>? genres;
  String? backdrops;
  double? score;
  String? about;
  int? duration;
  String? releaseDate;
  String? language;
  int? seasons;
  int? episodes;
  List<dynamic>? seasonsList;
  String? imdbId;
  final imdbRating = ValueNotifier<String?>(null);
  final rottenTomatoesRating = ValueNotifier<String>('N/A');
  
  // F2M Iran background check variables
  final f2mGroups = ValueNotifier<List<F2MSeasonGroup>>([]);
  final hasF2MResults = ValueNotifier<bool>(false);
  final isCheckingF2M = ValueNotifier<bool>(false);

  // Key to force refresh of ShowWatchToggle
  final GlobalKey<_ShowWatchToggleState> _showWatchToggleKey = GlobalKey<_ShowWatchToggleState>();

  @override
  void initState() {
    super.initState();
    checkUserLogin();
    _fetchSerieDetails();
  }

  @override
  void dispose() {
    isSerieWatchlist.dispose();
    isSerieFavorite.dispose();
    isUserLoggedIn.dispose();
    isSerieRated.dispose();
    userRating.dispose();
    imdbRating.dispose();
    rottenTomatoesRating.dispose();
    f2mGroups.dispose();
    hasF2MResults.dispose();
    isCheckingF2M.dispose();
    super.dispose();
  }

  Future<void> _checkF2M(String id) async {
    if (isCheckingF2M.value) return;
    isCheckingF2M.value = true;

    try {
      final groups = await fetchF2MDownloadLinks(id);
      if (!mounted) return;
      f2mGroups.value = groups;
      hasF2MResults.value = groups.isNotEmpty;
      isCheckingF2M.value = false;
    } catch (_) {
      if (!mounted) return;
      f2mGroups.value = [];
      hasF2MResults.value = false;
      isCheckingF2M.value = false;
    }
  }

  Future<void> checkUserLogin() async {
    final openbox = Hive.box('sessionBox');
    final sessionData = openbox.get('sessionData');
    if (sessionData != null && mounted) {
      isUserLoggedIn.value = true;
    }
  }

  Map<String, List<Map<String, dynamic>>> _parseCredits(
      Map<String, dynamic>? credits) {
    final castList = credits?['cast'] as List<dynamic>? ?? const [];
    final crewList = credits?['crew'] as List<dynamic>? ?? const [];
    return {
      'cast': castList.cast<Map<String, dynamic>>().toList(),
      'crew': crewList.cast<Map<String, dynamic>>().toList(),
    };
  }

  void _applyAccountStates(Map<String, dynamic>? accountStates) {
    if (accountStates == null) return;
    isSerieWatchlist.value = accountStates['watchlist'];
    isSerieFavorite.value = accountStates['favorite'];
    isSerieRated.value = accountStates['rated'];
    if (accountStates['rated'] != false && accountStates['rated'] is Map) {
      userRating.value = accountStates['rated']['value'];
    }
  }

  Future<void> _fetchSerieDetails() async {
    try {
      final region =
          Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final sessionId = Hive.box('sessionBox').get('sessionData') as String?;
      final append = <String>[
        'credits',
        'external_ids',
        if (sessionId != null) 'account_states',
      ];
      final responseData = await fetchSerieDetails(
        widget.serieId,
        region,
        sessionId: sessionId,
        appendToResponse: append,
      );

      _creditsFuture = Future.value(
        _parseCredits(responseData['credits'] as Map<String, dynamic>?),
      );
      _applyAccountStates(
          responseData['account_states'] as Map<String, dynamic>?);

      final external = responseData['external_ids'] as Map<String, dynamic>?;
      final fetchedImdbId = external?['imdb_id'] as String?;

      if (!mounted) return;
      setState(() {
        serieDetails = responseData;
        externalIds = external;
        budget = responseData['budget'];
        genres = responseData['genres'];
        backdrops = responseData['backdrop_path'];
        score = responseData['vote_average'];
        about = responseData['overview'];
        duration = responseData['runtime'];
        posterPath = responseData['poster_path'];
        releaseDate = responseData['release_date'] ??
            responseData['first_air_date'];
        language = responseData['original_language'];
        seasons = responseData['number_of_seasons'];
        episodes = responseData['number_of_episodes'];
        seasonsList = responseData['seasons'] as List<dynamic>?;
        imdbId = fetchedImdbId;
      });

      if (fetchedImdbId != null) {
        if (region == 'iran') {
          _checkF2M(fetchedImdbId);
        }
        await getSerieRatings(
            fetchedImdbId, updateImdbRating, updateRottenTomatoesRating);
      }
    } catch (e) {
      throw Exception('Failed to load serie details');
    }
  }

  void updateImdbRating(String rating) {
    if (mounted) {
      imdbRating.value = rating;
    }
  }

  void updateRottenTomatoesRating(String rating) {
    if (mounted) {
      rottenTomatoesRating.value = rating;
    }
  }

  void _refreshShowWatchStatus() {
    _showWatchToggleKey.currentState?.refresh();
  }

  void onTapSerie(String serieName, int serieId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SerieDetailPage(serieName: serieName, serieId: serieId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLayout = MediaQuery.sizeOf(context).width < 800;
    if (isMobileLayout) {
      return _SerieDetailPageMobile(this);
    } else {
      return _SerieDetailPageDesktop(this);
    }
  }
}

// Custom widget for smooth show watch toggle
class ShowWatchToggle extends StatefulWidget {
  final int serieId;
  final String serieName;
  final String? posterPath;
  final int? numberOfEpisodes;
  final List<dynamic>? seasons;
  final VoidCallback? onToggle;

  const ShowWatchToggle({
    Key? key,
    required this.serieId,
    required this.serieName,
    required this.posterPath,
    this.numberOfEpisodes,
    this.seasons,
    this.onToggle,
  }) : super(key: key);

  @override
  State<ShowWatchToggle> createState() => _ShowWatchToggleState();
}

class _ShowWatchToggleState extends State<ShowWatchToggle> {
  bool? _isWatched;
  bool _isLoading = false;
  final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();

  @override
  void initState() {
    super.initState();
    _loadWatchStatus();
  }

  @override
  void didUpdateWidget(covariant ShowWatchToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numberOfEpisodes != widget.numberOfEpisodes) {
      _loadWatchStatus();
    }
  }

  Future<void> _loadWatchStatus() async {
    try {
      final totalEpisodes = widget.numberOfEpisodes ?? 0;
      final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(widget.serieId, 'tv');
      final watchedEpisodes = watchHistory.where((item) => item.seasonNumber != null && item.seasonNumber != 0).length;

      if (mounted) {
        setState(() {
          _isWatched = totalEpisodes > 0 && watchedEpisodes == totalEpisodes;
        });
      }
    } catch (e) {
      final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(widget.serieId, 'tv');
      if (mounted) {
        setState(() {
          _isWatched = watchHistory.isNotEmpty;
        });
      }
    }
  }

  Future<void> _toggleWatchStatus() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isWatched ?? false) {
        // Remove all episodes of this show from watch history
        final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(widget.serieId, 'tv');
        await _watchHistoryDb.deleteWatchHistoryItemsBatch([
          for (final item in watchHistory)
            if (item.id != null) item.id!,
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.serieName} removed from watched!'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mark entire show as watched by adding all episodes
        await _markEntireShowAsWatched();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.serieName} marked as watched!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Update local state immediately for smooth transition
      setState(() {
        _isWatched = !(_isWatched ?? false);
        _isLoading = false;
      });
      
      // Call the callback to refresh parent state
      widget.onToggle?.call();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating watch status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _markEntireShowAsWatched() async {
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final apiKey = dotenv.env['TMDB_API_KEY'];
    final seasonNumbers = <int>[
      for (final season in widget.seasons ?? const [])
        if (season['season_number'] is int && season['season_number'] != 0)
          season['season_number'] as int,
    ];

    try {
      // Cap concurrent season GETs so we don't exhaust the connection pool.
      const maxConcurrent = 6;
      final watchedAt = DateTime.now();
      final rows = <WatchHistoryItem>[];

      for (var i = 0; i < seasonNumbers.length; i += maxConcurrent) {
        final end = (i + maxConcurrent < seasonNumbers.length)
            ? i + maxConcurrent
            : seasonNumbers.length;
        final chunk = seasonNumbers.sublist(i, end);
        final responses = await Future.wait(chunk.map((seasonNumber) {
          return apiClient.get(
            Uri.parse(
                '${baseUrl}tv/${widget.serieId}/season/$seasonNumber?api_key=$apiKey'),
          );
        }));

        for (var j = 0; j < chunk.length; j++) {
          final response = responses[j];
          if (response.statusCode != 200) continue;

          final episodeData = json.decode(response.body);
          final episodesList = episodeData['episodes'] as List<dynamic>;
          final seasonNumber = chunk[j];

          for (final episode in episodesList) {
            rows.add(WatchHistoryItem(
              tmdbId: widget.serieId,
              title: widget.serieName,
              type: 'tv',
              posterPath: widget.posterPath,
              watchedAt: watchedAt,
              seasonNumber: seasonNumber,
              episodeNumber: episode['episode_number'] as int?,
              episodeTitle: episode['name'] as String?,
            ));
          }
        }
      }

      await _watchHistoryDb.addShowEpisodesBatch(rows);
    } catch (e) {
      throw Exception('Failed to mark entire show as watched: $e');
    }
  }

  // Method to refresh the watch status from external calls
  void refresh() {
    _loadWatchStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isWatched == null) {
      return buildM3FloatingPillButton(
        context: context,
        onTap: () {},
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading...',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return buildM3FloatingPillButton(
      context: context,
      backgroundColor: _isWatched! ? Colors.green.withValues(alpha: 0.25) : null,
      borderColor: _isWatched! ? Colors.green.withValues(alpha: 0.6) : null,
      onTap: _toggleWatchStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isWatched! ? Icons.check_circle_rounded : Icons.visibility_outlined,
            color: _isWatched! ? Colors.greenAccent : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _isWatched! ? 'Watched' : 'Mark as Watched',
            style: theme.textTheme.labelMedium?.copyWith(
              color: _isWatched! ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
