import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:mxstream/widgets/extensions_screen.dart';
import 'package:mxstream/functions/fetchers/providers/VegaMovies/vega_movies_provider.dart';
import 'package:mxstream/functions/fetchers/fetch_movie_details.dart';
import 'package:mxstream/functions/fetchers/fetch_serie_details.dart';
import 'package:mxstream/functions/fetchers/providers/provider_metadata_mapper.dart';

import 'package:mxstream/database/watch_history_database.dart';
import 'package:mxstream/functions/fetchers/fetch_popular_movies.dart';
import 'package:mxstream/functions/fetchers/fetch_trending_movies.dart';
import 'package:mxstream/functions/fetchers/fetch_popular_series.dart';
import 'package:mxstream/functions/fetchers/fetch_trending_series.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/navigation_provider.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/homePage/widgets/continue_watching_card.dart';
import 'package:mxstream/homePage/widgets/home_content_card.dart';

import 'package:mxstream/homePage/widgets/set_watch_status_modal.dart';
import 'package:mxstream/models/watch_history_model.dart';
import 'package:mxstream/moviesPage/UI/gridview_forlists_movies.dart';
import 'package:mxstream/moviesPage/functions/on_tap_movie.dart';
import 'package:mxstream/moviesPage/functions/watch_links.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:mxstream/seriesPage/function/on_tap_serie.dart';
import 'package:mxstream/utils/expressive_motion.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';

class MovieShelfSection {
  final String title;
  final List<Movie> items;
  MovieShelfSection({required this.title, required this.items});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();
  late RegionProvider _regionProvider;

  // Data lists
  Movie? _heroMovie;
  List<Movie> _heroMovies = [];
  int _heroIndex = 0;
  final PageController _heroPageController = PageController();
  Timer? _heroAutoSlideTimer;
  String _heroWatchStatus = 'None';

  List<ContinueWatchingItem> _continueWatchingList = [];
  List<Movie> _homeMovies = [];
  List<MovieShelfSection> _shelves = [];

  // Horizontal pagination state
  int _currentHomeShelfPage = 1;
  bool _isLoadingNextPage = false;
  final ScrollController _homeShelfScrollController = ScrollController();

  bool _isLoading = true;

  // Fallback dummy items for skeletonizer loading state
  final List<Movie> _dummyMovies = List.generate(
    6,
    (index) => Movie(
      title: 'Loading Title Placeholder',
      releaseDate: '2026-01-01',
      posterPath: '',
      backdropPath: '',
      overView: 'Overview loading...',
      id: -100 - index,
      score: 8.5,
    ),
  );

  final List<ContinueWatchingItem> _dummyContinueWatching = List.generate(
    4,
    (index) => ContinueWatchingItem(
      id: -200 - index,
      title: 'Show Title Placeholder',
      posterPath: '',
      episodeBadge: 'S1:E1',
      progress: 0.6,
    ),
  );

  @override
  void initState() {
    super.initState();
    _homeShelfScrollController.addListener(_onHomeShelfScroll);
    _regionProvider = Provider.of<RegionProvider>(context, listen: false);
    _regionProvider.addListener(_onRegionChanged);
    _loadAllData();
  }

  void _onHomeShelfScroll() {}

  Future<void> _loadNextPage() async {}


  @override
  void dispose() {
    _homeShelfScrollController.removeListener(_onHomeShelfScroll);
    _homeShelfScrollController.dispose();
    _heroAutoSlideTimer?.cancel();
    _heroPageController.dispose();
    _regionProvider.removeListener(_onRegionChanged);
    super.dispose();
  }

  void _onRegionChanged() {
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    await Future.wait([
      _loadWatchHistory(),
      _loadShelves(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }



  Future<void> _loadWatchHistory() async {
    try {
      final history = await _watchHistoryDb.getAllWatchHistory();
      if (!mounted) return;

      if (history.isNotEmpty) {
        // Take up to 10 most recent items
        final items = history.take(10).map((h) {
          final isTv = h.type == 'tv';
          String? badge;
          if (isTv && h.seasonNumber != null && h.episodeNumber != null) {
            badge = 'S${h.seasonNumber}:E${h.episodeNumber}';
          }
          return ContinueWatchingItem(
            id: h.tmdbId,
            title: h.title,
            posterPath: h.posterPath ?? '',
            episodeBadge: badge,
            progress: 0.7, // Saved or calculated progress
            type: h.type,
            seasonNumber: h.seasonNumber,
            episodeNumber: h.episodeNumber,
          );
        }).toList();

        setState(() {
          _continueWatchingList = items;
        });
      }
    } catch (e) {
      debugPrint('Error loading watch history for continue watching: $e');
    }
  }

  Future<void> _loadShelves() async {
    _currentHomeShelfPage = 1;
    try {
      final region = _regionProvider.currentRegion;
      final vegaMovies = VegaMoviesProviderImpl();

      // Start VegaMovies requests
      final vegaCategories = [
        {'id': 'home', 'title': 'Latest Releases'},
        {'id': 'netflix', 'title': 'Netflix Originals'},
        {'id': 'prime', 'title': 'Amazon Prime Video'},
        {'id': 'hotstar', 'title': 'Disney+ Hotstar'},
        {'id': 'anime', 'title': 'Anime Hub'},
      ];

      final vegaFutures = vegaCategories.map((cat) async {
        try {
          final results = await vegaMovies.getMainPage(category: cat['id']!);
          if (results.isEmpty) return null;
          
          // Limit to 15 items per shelf to prevent TMDB API rate limiting
          final enrichFutures = results.take(15).map((item) => ProviderMetadataMapper.enrichProviderItem(item, region));
          final enrichedItems = await Future.wait(enrichFutures);
          
          final movies = enrichedItems.map((e) => e.movie).toList();
          return MovieShelfSection(title: cat['title']!, items: movies);
        } catch (e) {
          debugPrint('Error fetching VegaMovies category ${cat['id']}: $e');
          return null;
        }
      }).toList();

      // Wait for all concurrent requests
      final vegaShelvesResults = await Future.wait(vegaFutures);

      if (!mounted) return;

      List<MovieShelfSection> newShelves = [];

      // 1. Prepend VegaMovies Shelves
      for (var shelf in vegaShelvesResults) {
        if (shelf != null && shelf.items.isNotEmpty) {
          newShelves.add(shelf);
        }
      }

      // The top shelf becomes the hero list
      final heroList = newShelves.isNotEmpty ? newShelves.first.items : <Movie>[];
      Movie? hero = heroList.isNotEmpty ? heroList.first : null;
      String heroStatus = 'None';
      if (hero != null) heroStatus = WatchStatusManager.getStatus(hero.id);

      setState(() {
        _heroMovie = hero;
        _heroMovies = heroList;
        _heroIndex = 0;
        _heroWatchStatus = heroStatus;
        _homeMovies = heroList; // First shelf is used for pagination if needed
        _shelves = newShelves;
      });

      _startHeroAutoSlide();
    } catch (e) {
      debugPrint('Error loading home shelves: $e');
    }
  }

  void _startHeroAutoSlide() {
    _heroAutoSlideTimer?.cancel();
    if (_heroMovies.length <= 1) return;
    _heroAutoSlideTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted || _heroMovies.length <= 1 || !_heroPageController.hasClients) return;
      final nextIndex = (_heroIndex + 1) % _heroMovies.length;
      _heroPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Movie? get _currentHeroMovie =>
      _heroMovies.isNotEmpty && _heroIndex < _heroMovies.length
          ? _heroMovies[_heroIndex]
          : _heroMovie;

  void _onTapMovieCard(Movie movie) {
    if (movie.releaseDate == 'SERIES') {
       onTapSerie(movie.title, movie.id, context);
    } else {
       onTapMovie(movie.title, movie.id, context);
    }
  }

  void _onHeroPlay([Movie? targetMovie]) {
    final movie = targetMovie ?? _currentHeroMovie;
    if (movie == null) return;
    _onTapMovieCard(movie);
  }

  void _onHeroInfo([Movie? targetMovie]) {
    final movie = targetMovie ?? _currentHeroMovie;
    if (movie == null) return;
    _onTapMovieCard(movie);
  }

  Future<void> _onHeroStatusTap([Movie? targetMovie]) async {
    final movie = targetMovie ?? _currentHeroMovie;
    if (movie == null) return;
    final currentStatus = WatchStatusManager.getStatus(movie.id);
    final newStatus = await SetWatchStatusModal.show(
      context,
      tmdbId: movie.id,
      title: movie.title,
      posterPath: movie.posterPath,
      initialStatus: currentStatus,
      permalink: null,
      providerName: null,
    );
    if (newStatus != null && mounted) {
      setState(() {
        _heroWatchStatus = newStatus;
      });
    }
  }

  void _openGridCategory(String title, List<Movie> list) {
    if (list.isEmpty) return;
    Navigator.push(
      context,
      ExpressivePageRoute(
        page: ListGridViewMovies(
          movieList: list,
          title: title,
          onTapMovieCard: (movie) => _onTapMovieCard(movie),
        ),
      ),
    );
  }

  void _showHomeFilterBottomSheet() {}

  Widget _buildEmptyProviderState(BuildContext context) { return const SizedBox(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = TvFocusModeManager.isTvDevice;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = isTv
        ? 16.0
        : (bottomPadding > 0 ? bottomPadding : 88.0);
    final isNone = false;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: RefreshIndicator(
                    onRefresh: _loadAllData,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        // 1. Hero Spotlight Banner with Transparent Overlay Header
                        SliverToBoxAdapter(
                          child: _buildHeroBanner(context),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),

                        // 2. Continue Watching Section
                        if (_continueWatchingList.isNotEmpty || _isLoading)
                          SliverToBoxAdapter(
                            child: _buildContinueWatchingSection(context),
                          ),

                        // 3. Dynamic Category Shelves mapped one by one from VegaMovies!
                        if (_isLoading && _shelves.isEmpty) ...[
                          for (final dummyTitle in [
                            'Latest Releases',
                            'Netflix Series',
                            'Disney Plus Hotstar',
                            'Amazon Prime Video',
                            'Korean Series',
                            'Anime Series'
                          ])
                            SliverToBoxAdapter(
                              child: _buildContentShelf(
                                title: dummyTitle,
                                movies: _dummyMovies,
                              ),
                            ),
                        ] else ...[
                          for (int i = 0; i < _shelves.length; i++) ...[
                            SliverToBoxAdapter(
                              child: _buildContentShelf(
                                title: _shelves[i].title,
                                onTapMovieCard: (movie) => _onTapMovieCard(movie),
                                movies: i == 0
                                    ? _homeMovies
                                    : _shelves[i].items,
                                scrollController:
                                    i == 0 ? _homeShelfScrollController : null,
                                isLoadingNext:
                                    i == 0 ? _isLoadingNextPage : false,
                                onSeeAll: () => _openGridCategory(
                                  _shelves[i].title,
                                  i == 0
                                      ? _homeMovies
                                      : _shelves[i].items,
                                ),
                              ),
                            ),
                          ],
                        ],

                        // Bottom Spacing for Bottom Navigation Bar
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: isTv ? 24.0 : BottomBar.getHeight(context) + 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

        ],
      ),
    );
  }

  // --- Hero Spotlight Widget ---
  Widget _buildHeroBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = _regionProvider.currentRegion;
    final imageBase = getImageBaseUrl(region);
    final topPadding = MediaQuery.paddingOf(context).top;

    final currentMovie = _currentHeroMovie;
    final heroTitle = currentMovie?.title ?? 'Featured Title';
    final heroStatus = currentMovie != null ? WatchStatusManager.getStatus(currentMovie.id) : 'None';

    return SizedBox(
      height: 520,
      width: double.infinity,
      child: Stack(
        children: [
          // Background Hero Slideable PageView
          if (_heroMovies.isNotEmpty)
            PageView.builder(
              controller: _heroPageController,
              itemCount: _heroMovies.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _heroIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final movie = _heroMovies[index];
                final heroPoster = movie.posterPath;
                final heroBackdrop = movie.backdropPath ?? heroPoster;
                final imagePath = heroPoster.isNotEmpty ? heroPoster : heroBackdrop;
                final String bannerImageUrl = imagePath.isNotEmpty
                    ? (imagePath.startsWith('http') ? imagePath : '$imageBase/t/p/w780$imagePath')
                    : '';

                return SizedBox(
                  height: 520,
                  width: double.infinity,
                  child: bannerImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bannerImageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                );
              },
            )
          else
            Container(color: colorScheme.surfaceContainerHighest),

          // Multi-Stop Seamless Gradient Overlays (IgnorePointer so swipe gestures work smoothly)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.25, 0.65, 0.88, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.65), // Top scrim for status/header icons
                      Colors.transparent,
                      Colors.transparent,
                      colorScheme.surface.withValues(alpha: 0.85),
                      colorScheme.surface, // Solid fade to screen background
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Top Header (Search & Avatar)
          Positioned(
            top: topPadding + 6,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Search Icon Button
                ExpressiveInteractiveContainer(
                  onTap: () {
                    final nav = Provider.of<NavigationProvider>(context, listen: false);
                    nav.setIndex(1); // Search tab index
                  },
                  borderRadius: 20,
                  pressedBorderRadius: 24,
                  speed: ExpressiveSpeed.fast,
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 28,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),

                // Glowing Avatar Circle (matching Figma)
                ExpressiveInteractiveContainer(
                  onTap: () {
                    final nav = Provider.of<NavigationProvider>(context, listen: false);
                    nav.setIndex(4); // Settings tab index
                  },
                  borderRadius: 20,
                  pressedBorderRadius: 24,
                  speed: ExpressiveSpeed.fast,
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.2, -0.3),
                        radius: 0.9,
                        colors: [
                          Color(0xFF64B5F6),
                          Color(0xFF1976D2),
                          Color(0xFF0D47A1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1976D2).withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Hero Title & Action Bar at Bottom of Banner
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero Movie Title (Animated transition on slide)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    heroTitle,
                    key: ValueKey('hero_title_${currentMovie?.id ?? 0}'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      shadows: [
                        const Shadow(
                          color: Colors.black87,
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Carousel Dots Indicator
                if (_heroMovies.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_heroMovies.length, (dotIndex) {
                      final isActive = dotIndex == _heroIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 14),

                // Action Row (Left: Status, Center: Play, Right: Info)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Action: + [Status]
                    TvFocusWrapper(
                      onTap: () => _onHeroStatusTap(currentMovie),
                      borderRadius: 12,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              heroStatus != 'None'
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              heroStatus,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center Action: Prominent "▶ Play" Button
                    TvFocusWrapper(
                      autoFocus: true,
                      onTap: () => _onHeroPlay(currentMovie),
                      borderRadius: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Right Action: (i) Info
                  TvFocusWrapper(
                    onTap: () => _onHeroInfo(currentMovie),
                    borderRadius: 12,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Info',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // --- Continue Watching Section ---
  Widget _buildContinueWatchingSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _continueWatchingList.isEmpty ? _dummyContinueWatching : _continueWatchingList;
    final loading = _isLoading && _continueWatchingList.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Continue Watching',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  color: colorScheme.onSurface,
                  size: 22,
                ),
                tooltip: 'See All Watch History',
                onPressed: () {
                  final nav = Provider.of<NavigationProvider>(context, listen: false);
                  nav.setIndex(2); // Shelf / History tab (index 2)
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal List View with Edge Fading Effect
        SizedBox(
          height: 255,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.02, 0.90, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final card = ContinueWatchingCard(
                  item: item,
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: loading
                      ? Skeletonizer(
                          enabled: true,
                          containersColor: colorScheme.surfaceContainerHigh,
                          child: card,
                        )
                      : TvFocusWrapper(
                          onTap: () {
                            if (item.type == 'tv') {
                              onTapSerie(item.title, item.id, context);
                            } else {
                              onTapMovie(item.title, item.id, context);
                            }
                          },
                          child: card,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Reusable Horizontal Content Shelf with Edge Fading & Infinite Scroll ---
  Widget _buildContentShelf({
    required String title,
    required List<Movie> movies,
    VoidCallback? onSeeAll,
    ScrollController? scrollController,
    bool isLoadingNext = false,
    void Function(Movie)? onTapMovieCard,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loading = movies.isEmpty && _isLoading;
    final displayList = movies.isEmpty ? _dummyMovies : movies;
    final totalCount = displayList.length + (isLoadingNext ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                  color: colorScheme.onSurface,
                ),
              ),
              if (onSeeAll != null)
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: colorScheme.onSurface,
                    size: 22,
                  ),
                  tooltip: 'See All $title',
                  onPressed: onSeeAll,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal List View with Edge Fading Effect
        SizedBox(
          height: 250,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.02, 0.90, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                if (index >= displayList.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Skeletonizer(
                      enabled: true,
                      containersColor: colorScheme.surfaceContainerHigh,
                      child: HomeContentCard(
                        movie: _dummyMovies.first,
                      ),
                    ),
                  );
                }

                final movie = displayList[index];
                final card = HomeContentCard(
                  movie: movie,
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: loading
                      ? Skeletonizer(
                          enabled: true,
                          containersColor: colorScheme.surfaceContainerHigh,
                          child: card,
                        )
                      : TvFocusWrapper(
                          onTap: () => _onTapMovieCard(movie),
                          child: card,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
