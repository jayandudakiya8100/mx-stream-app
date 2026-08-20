import 'dart:ui';
import 'package:mxstream/functions/fetchers/fetch_movies_by_genre.dart';
import 'package:mxstream/functions/fetchers/fetch_popular_movies.dart';
import 'package:mxstream/functions/fetchers/fetch_trending_movies.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/moviesPage/functions/on_tap_gridview_movie.dart';
import 'package:mxstream/moviesPage/functions/on_tap_movie.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/utils/expressive_motion.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mxstream/moviesPage/UI/customMovieWidget.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'dart:async';
import 'package:mxstream/database/watch_history_database.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class _TouchMouseScrollBehavior extends MaterialScrollBehavior {
  const _TouchMouseScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

const _movieScrollBehavior = _TouchMouseScrollBehavior();

class MovieSearchScreen extends StatefulWidget {
  static final GlobalKey<_MovieSearchScreenState> movieSearchKey =
      GlobalKey<_MovieSearchScreenState>();

  const MovieSearchScreen({super.key});
  @override
  _MovieSearchScreenState createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final apiKey = dotenv.env['TMDB_API_KEY'];

  List<Movie> trendingMovies = [];
  List<Movie> popularMovies = [];
  List<Genre> genres = [];
  Map<int, List<Movie>> moviesByGenre = {};
  late RegionProvider _regionProvider;
  final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();
  final ValueNotifier<Set<int>> _watchedMovieIds = ValueNotifier({});

  Future<void> _loadWatchedMovies() async {
    try {
      final watched = await _watchHistoryDb.getWatchedMovies();
      if (!mounted) return;
      final next = watched.map((e) => e.tmdbId).toSet();
      final current = _watchedMovieIds.value;
      if (next.length == current.length && next.containsAll(current)) return;
      _watchedMovieIds.value = next;
    } catch (e) {
      debugPrint('Error loading watched movies: $e');
    }
  }

  Future<void> _onMovieTapped(Movie movie) async {
    await onTapMovie(movie.title, movie.id, context);
    if (mounted) {
      _loadWatchedMovies();
    }
  }

  final List<Movie> _dummyMovies = List.generate(
    6,
    (index) => Movie(
      title: 'Movie Title Placeholder',
      releaseDate: '2026-01-01',
      posterPath: '',
      overView: 'This is a description placeholder for the movie loading state.',
      id: -1 - index,
      score: 8.5,
    ),
  );

  final List<Genre> _dummyGenres = [
    Genre(id: -100, name: 'Genre Placeholder 1'),
    Genre(id: -101, name: 'Genre Placeholder 2'),
  ];

  late final Map<int, List<Movie>> _dummyMoviesByGenre = {
    -100: List.generate(
      6,
      (index) => Movie(
        title: 'Movie Title Placeholder',
        releaseDate: '2026-01-01',
        posterPath: '',
        overView: 'This is a description placeholder for the movie loading state.',
        id: -200 - index,
        score: 8.5,
      ),
    ),
    -101: List.generate(
      6,
      (index) => Movie(
        title: 'Movie Title Placeholder',
        releaseDate: '2026-01-01',
        posterPath: '',
        overView: 'This is a description placeholder for the movie loading state.',
        id: -300 - index,
        score: 8.5,
      ),
    ),
  };

  /// Static bone fill — animated shimmer would setState the whole card subtree every frame.
  Widget _skeletonCard({required Widget child}) {
    final fill = Colors.white.withValues(alpha: 0.05);
    return Skeletonizer(
      enabled: true,
      ignorePointers: true,
      containersColor: fill,
      effect: SolidColorEffect(color: fill),
      child: child,
    );
  }

  Future<List<Movie>> _fetchTrendingMovies() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchTrendingMovies(region);
  }

  Future<List<Movie>> _fetchPopularMovies() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchPopularMovies(region);
  }

  Future<void> _loadPrimaryMovies() async {
    try {
      final primaryResults = await Future.wait([
        _fetchTrendingMovies(),
        _fetchPopularMovies(),
      ]);

      if (mounted) {
        setState(() {
          trendingMovies = primaryResults[0];
          popularMovies = primaryResults[1];
        });
      }
    } catch (e) {
      debugPrint('Error fetching primary movie data: $e');
    }
  }

  Future<void> _loadGenreMovies() async {
    try {
      final region =
          Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final fetchedGenres = await fetchGenres(region);
      if (!mounted) return;

      // Show genre headers immediately; rows skeleton until each batch lands.
      setState(() {
        genres = fetchedGenres;
      });

      // Cap concurrent genre discovers so posters keep connection-pool headroom.
      const batchSize = 8;
      if (fetchedGenres.isEmpty) return;

      for (var i = 0; i < fetchedGenres.length; i += batchSize) {
        final end = (i + batchSize < fetchedGenres.length)
            ? i + batchSize
            : fetchedGenres.length;
        final chunk = fetchedGenres.sublist(i, end);
        final results = await Future.wait(chunk.map((genre) async {
          try {
            final movies = await fetchMoviesByGenre(genre.id, region);
            return MapEntry(genre.id, movies);
          } catch (e) {
            debugPrint('Failed to fetch movies for genre ${genre.name}: $e');
            return MapEntry(genre.id, <Movie>[]);
          }
        }));

        if (!mounted) return;
        setState(() {
          moviesByGenre = {
            ...moviesByGenre,
            for (final entry in results) entry.key: entry.value,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching genres: $e');
    }
  }

  void _onRegionChanged() {
    checkInternetAndFetchData();
  }

  @override
  void initState() {
    super.initState();
    checkInternetAndFetchData();
    _loadWatchedMovies();

    // Add listener for region changes
    _regionProvider = Provider.of<RegionProvider>(context, listen: false);
    _regionProvider.addListener(_onRegionChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposing
    _regionProvider.removeListener(_onRegionChanged);
    _watchedMovieIds.dispose();
    super.dispose();
  }

  Future<void> checkInternetAndFetchData() async {
    if (mounted) {
      setState(() {
        trendingMovies = [];
        popularMovies = [];
        genres = [];
        moviesByGenre = {};
      });
    }
    _loadWatchedMovies();

    // Primary shelves and genre lists load concurrently.
    await Future.wait([
      _loadPrimaryMovies(),
      _loadGenreMovies(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentGenres = genres.isEmpty ? _dummyGenres : genres;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Movies',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader('Trending Movies', null),
                const SizedBox(height: 10),
                SizedBox(
                  height: 250,
                  child: ScrollConfiguration(
                    behavior: _movieScrollBehavior,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemExtent: 154,
                      itemCount: trendingMovies.isEmpty
                          ? _dummyMovies.length
                          : trendingMovies.length,
                      itemBuilder: (context, index) {
                        final loading = trendingMovies.isEmpty;
                        final movie =
                            loading ? _dummyMovies[index] : trendingMovies[index];
                        final card = CustomMovieWidget(
                          movie: movie,
                          showAvailability: false,
                          watchedMovieIds: loading ? null : _watchedMovieIds,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: loading
                              ? _skeletonCard(child: card)
                              : TvFocusWrapper(
                                  autoFocus: index == 0,
                                  onTap: () => _onMovieTapped(movie),
                                  child: card,
                                ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionHeader('Popular Movies', null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: ScrollConfiguration(
                    behavior: _movieScrollBehavior,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemExtent: 154,
                      itemCount: popularMovies.isEmpty
                          ? _dummyMovies.length
                          : popularMovies.length,
                      itemBuilder: (context, index) {
                        final loading = popularMovies.isEmpty;
                        final movie =
                            loading ? _dummyMovies[index] : popularMovies[index];
                        final card = CustomMovieWidget(
                          movie: movie,
                          showAvailability: false,
                          watchedMovieIds: loading ? null : _watchedMovieIds,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: loading
                              ? _skeletonCard(child: card)
                              : TvFocusWrapper(
                                  onTap: () => _onMovieTapped(movie),
                                  child: card,
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final genre = currentGenres[index];
                final genreLoading =
                    genres.isNotEmpty && !moviesByGenre.containsKey(genre.id);
                final moviesList = genres.isEmpty
                    ? _dummyMoviesByGenre[genre.id]
                    : genreLoading
                        ? _dummyMovies
                        : moviesByGenre[genre.id];

                final loading = genres.isEmpty || genreLoading;
                final header = _buildSectionHeader(
                  genre.name,
                  loading || moviesByGenre[genre.id] == null
                      ? null
                      : () => onTapGridMovie(
                          moviesByGenre[genre.id]!, context),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Skeletonize title until real genre names arrive.
                    genres.isEmpty ? _skeletonCard(child: header) : header,
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: ScrollConfiguration(
                        behavior: _movieScrollBehavior,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemExtent: 154,
                          itemCount: moviesList?.length ?? 0,
                          itemBuilder: (context, itemIndex) {
                            final movie = moviesList![itemIndex];
                            final card = CustomMovieWidget(
                              movie: movie,
                              showAvailability: false,
                              watchedMovieIds: loading ? null : _watchedMovieIds,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: loading
                                  ? _skeletonCard(child: card)
                                  : TvFocusWrapper(
                                      onTap: () => _onMovieTapped(movie),
                                      child: card,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              childCount: currentGenres.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          if (onTap != null)
            ExpressiveInteractiveContainer(
              onTap: onTap,
              borderRadius: 20,
              pressedBorderRadius: 28,
              speed: ExpressiveSpeed.fast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


