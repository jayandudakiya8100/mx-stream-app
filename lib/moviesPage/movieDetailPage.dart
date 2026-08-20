import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/functions/platform_helper.dart';

import 'package:mxstream/database/watch_history_database.dart';
import 'package:mxstream/functions/fetchers/fetch_movie_details.dart';
import 'package:mxstream/functions/fetchers/fetch_other_movies_by_director.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/functions/share_content.dart';
import 'package:mxstream/moviesPage/checkers/custom_tmdb_ids_effects.dart';
import 'package:mxstream/moviesPage/functions/get_imdb_rating.dart';
import 'package:mxstream/moviesPage/functions/torrent_links.dart';
import 'package:mxstream/moviesPage/functions/watch_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mxstream/moviesPage/UI/cast_crew_row.dart';
import 'package:mxstream/moviesPage/UI/customMovieWidget.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:mxstream/moviesPage/UI/movie_action_buttons.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/moviesPage/functions/check_availability.dart';
import 'package:mxstream/widgets/custom_divider.dart';
import 'package:mxstream/widgets/image_gallery_page.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';
import 'package:mxstream/homePage/widgets/set_watch_status_modal.dart';
import 'package:mxstream/functions/navigation_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:ui';

part 'movieDetailPageMobile.dart';
part 'movieDetailPageDesktop.dart';

class MovieDetailPage extends StatefulWidget {
  final String movieTitle;
  final int movieId;

  const MovieDetailPage(
      {super.key, required this.movieTitle, required this.movieId});

  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  Future<List<String>>? _castImagesFuture;
  Future<dynamic>? _creditsFuture;
  Future<dynamic>? _availabilityFuture;
  final directorMoviesFuture = ValueNotifier<Future<dynamic>?>(null);
  String? directorName;
  final isMovieWatchlist = ValueNotifier<bool?>(null);
  final isMovieFavorite = ValueNotifier<bool?>(null);
  final isUserLoggedIn = ValueNotifier<bool>(false);
  final isMovieRated = ValueNotifier<dynamic>(null);
  final userRating = ValueNotifier<double?>(null);
  double? userScore;
  final screenshotController = ScreenshotController();

  void updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }


  // Watch history variables
  final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();
  final isWatched = ValueNotifier<bool>(false);

  Map<String, dynamic>? moviedetails;
  Map<String, dynamic>? movieInfo;

  double? popularity;
  int? budget;
  int? revenue;
  List<dynamic>? genres;
  List<dynamic>? productionCountries;
  List<dynamic>? productionCompanies;
  List<dynamic>? spokenLanguages;

  String? backdrops;
  double? score;
  String? about;
  int? duration;
  String? releaseDate;
  String? language;
  String? posterPath;

  String? imdbId;
  final imdbRating = ValueNotifier<String?>(null);
  final rottenTomatoesRating = ValueNotifier<String>('N/A');

  @override
  void initState() {
    super.initState();
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    _initPageData(region);
  }

  @override
  void dispose() {
    directorMoviesFuture.dispose();
    isMovieWatchlist.dispose();
    isMovieFavorite.dispose();
    isUserLoggedIn.dispose();
    isMovieRated.dispose();
    userRating.dispose();
    isWatched.dispose();
    imdbRating.dispose();
    rottenTomatoesRating.dispose();
    super.dispose();
  }

  void _initPageData(String region) {
    Future.wait([
      checkUserLogin(),
      _fetchMovieDetails(region),
      _checkWatchedStatus(),
    ]).catchError((_) => <dynamic>[]);
  }

  Future<void> _openGalleryOnDemand() async {
    _castImagesFuture ??= Future.value(const <String>[]);
    try {
      final imageUrls = await _castImagesFuture!;
      if (mounted) {
        _openImageGallery(imageUrls);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load image gallery')),
        );
      }
    }
  }

  void _openImageGallery(List<String> imageUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryPage(imageUrls: imageUrls),
      ),
    );
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
    isMovieWatchlist.value = accountStates['watchlist'];
    isMovieFavorite.value = accountStates['favorite'];
    isMovieRated.value = accountStates['rated'];
    if (accountStates['rated'] != false && accountStates['rated'] is Map) {
      userRating.value = accountStates['rated']['value'];
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

  Future<void> _fetchMovieDetails(String region) async {
    try {
      final sessionId = Hive.box('sessionBox').get('sessionData') as String?;
      final append = <String>[
        'credits',
        'images',
        'watch/providers',
        if (sessionId != null) 'account_states',
      ];
      final responseData = await fetchMovieDetails(
        widget.movieId,
        region,
        sessionId: sessionId,
        appendToResponse: append,
      );

      final credits = _parseCredits(
          responseData['credits'] as Map<String, dynamic>?);
      _creditsFuture = Future.value(credits);
      for (final crewMember in credits['crew'] ?? const []) {
        if (crewMember['job'] == 'Director') {
          directorName = crewMember['name'] as String?;
          directorMoviesFuture.value =
              fetchOtherMoviesByDirector(crewMember['id'], region);
          break;
        }
      }

      final available = availabilityFromProvidersPayload(
          responseData['watch/providers'] as Map<String, dynamic>?);
      seedAvailabilityCache(widget.movieId, region, available);
      _availabilityFuture = Future.value(available);

      final backdropsList =
          (responseData['images'] as Map<String, dynamic>?)?['backdrops']
                  as List<dynamic>? ??
              const [];
      _castImagesFuture = Future.value(
        backdropsList
            .map((image) => image['file_path'] as String)
            .toList(),
      );

      _applyAccountStates(
          responseData['account_states'] as Map<String, dynamic>?);

      if (!mounted) return;
      setState(() {
        moviedetails = responseData;
        budget = responseData['budget'];
        revenue = responseData['revenue'];
        genres = responseData['genres'];
        backdrops = responseData['backdrop_path'];
        score = responseData['vote_average'];
        about = responseData['overview'];
        duration = responseData['runtime'];
        releaseDate = responseData['release_date'];
        language = responseData['original_language'];
        posterPath = responseData['poster_path'];
        productionCountries = responseData['production_countries'];
        productionCompanies = responseData['production_companies'];
        spokenLanguages = responseData['spoken_languages'];
        imdbId = responseData['imdb_id'];
      });

      if (imdbId != null) {
        await getMovieRatings(
            imdbId, updateImdbRating, updateRottenTomatoesRating);
      }
    } catch (e) {
      throw Exception('Failed to load movie details');
    }
  }

  Future<void> _checkWatchedStatus() async {
    final watched = await _watchHistoryDb.isWatched(widget.movieId, 'movie');
    if (mounted) {
      isWatched.value = watched;
    }
  }

  void onTapMovie(String movieTitle, int movieId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MovieDetailPage(movieTitle: movieTitle, movieId: movieId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLayout = MediaQuery.sizeOf(context).width < 800;
    if (isMobileLayout) {
      return _MovieDetailPageMobile(this);
    } else {
      return _MovieDetailPageDesktop(this);
    }
  }
}
