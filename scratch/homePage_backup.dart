import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:Mirarr/widgets/extensions_screen.dart';

import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/functions/fetchers/fetch_popular_movies.dart';
import 'package:Mirarr/functions/fetchers/fetch_streaming_providers.dart';
import 'package:Mirarr/functions/fetchers/fetch_trending_movies.dart';
import 'package:Mirarr/functions/fetchers/providers/media_provider_service.dart';
import 'package:Mirarr/functions/fetchers/providers/core/models.dart';
import 'package:Mirarr/functions/fetchers/providers/provider_manager.dart';
import 'package:Mirarr/functions/fetchers/providers/provider_config.dart';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/homePage/widgets/continue_watching_card.dart';
import 'package:Mirarr/homePage/widgets/home_content_card.dart';
import 'package:Mirarr/homePage/widgets/provider_media_detail_page.dart';
import 'package:Mirarr/homePage/widgets/set_watch_status_modal.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:Mirarr/moviesPage/UI/gridview_forlists_movies.dart';
import 'package:Mirarr/moviesPage/functions/on_tap_movie.dart';
import 'package:Mirarr/moviesPage/functions/watch_links.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';

class ProviderShelfSection {
  final String title;
  final String categoryPath;
  final List<ProviderSearchItem> items;
  ProviderShelfSection({required this.title, required this.categoryPath, required this.items});
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
  String _selectedProvider = 'VegaMovies';
  List<MediaProviderItem> _dynamicProviders = MediaProviderService.defaultProviders;
  final Map<int, ProviderSearchItem> _providerItemMap = {};
  List<ContinueWatchingItem> _continueWatchingList = [];
  List<Movie> _homeMovies = [];
  List<ProviderShelfSection> _shelves = [];

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
    _selectedProvider = MediaProviderService.getSelectedProvider();
    _homeShelfScrollController.addListener(_onHomeShelfScroll);
    _fetchDynamicProviders();
    _regionProvider = Provider.of<RegionProvider>(context, listen: false);
    _regionProvider.addListener(_onRegionChanged);
    _loadAllData();
  }

  void _onHomeShelfScroll() {
    if (!_homeShelfScrollController.hasClients || _isLoadingNextPage) return;
    final maxScroll = _homeShelfScrollController.position.maxScrollExtent;
    final currentScroll = _homeShelfScrollController.position.pixels;
    if (maxScroll - currentScroll <= 250) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingNextPage || _selectedProvider.toLowerCase() == 'none') return;
    _isLoadingNextPage = true;
    final nextPage = _currentHomeShelfPage + 1;

    try {
      final provider = ProviderManager.getProvider(_selectedProvider);
      if (provider == null) return;
      
      final newItems = await provider.getMainPage(category: 'home', page: nextPage);

      if (newItems.isNotEmpty && mounted) {
        final existingIds = <int>{
          ..._homeMovies.map((m) => m.id),
          ..._heroMovies.map((m) => m.id),
        };

        final uniqueNewItems = newItems.where((item) => !existingIds.contains(ProviderConfig.getStableMediaId(item.url))).toList();

        for (final item in uniqueNewItems) {
          _providerItemMap[ProviderConfig.getStableMediaId(item.url)] = item;
        }
        
        final newMovies = uniqueNewItems.map((e) => Movie(
          title: e.title, releaseDate: '', posterPath: e.poster, backdropPath: e.poster, overView: '', id: ProviderConfig.getStableMediaId(e.url), score: 7.5
        )).toList();

        setState(() {
          _currentHomeShelfPage = nextPage;
          _homeMovies.addAll(newMovies);
        });
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() {
          _isLoadingNextPage = false;
        });
      }
    }
  }

  Future<void> _fetchDynamicProviders() async {
    final enabledProviders = await MediaProviderService.fetchProviders();
    
    final List<MediaProviderItem> mappedProviders = [
      const MediaProviderItem(id: 'none', name: 'None'),
      const MediaProviderItem(id: 'random', name: 'Random'),
    ];
    
    mappedProviders.addAll(enabledProviders);

    if (mounted) {
      setState(() {
        _dynamicProviders = mappedProviders;
      });
    }
  }

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
    if (_selectedProvider.toLowerCase() == 'none') {
      if (!mounted) return;
      setState(() {
        _heroMovie = null;
        _heroMovies = [];
        _heroIndex = 0;
        _homeMovies = [];
        _shelves = [];
      });
      return;
    }

    try {
      debugPrint('[_loadShelves] Selected provider: $_selectedProvider');
      final provider = ProviderManager.getProvider(_selectedProvider);
      if (provider == null) {
        debugPrint('[_loadShelves] Error: Provider "$_selectedProvider" not found in ProviderManager!');
        return;
      }
      
      debugPrint('[_loadShelves] Fetching home items from provider: ${provider.name}');
      final homeItems = await provider.getMainPage(category: 'home');
      final netflixItems = await provider.getMainPage(category: 'netflix');
      final primeItems = await provider.getMainPage(category: 'prime');
      final hotstarItems = await provider.getMainPage(category: 'hotstar');
      final animeItems = await provider.getMainPage(category: 'anime');
      
      if (!mounted) return;
      
      _providerItemMap.clear();
      final allItems = [...homeItems, ...netflixItems, ...primeItems, ...hotstarItems, ...animeItems];
      for (final item in allItems) {
        _providerItemMap[ProviderConfig.getStableMediaId(item.url)] = item;
      }

      List<ProviderShelfSection> newShelves = [];
      if (homeItems.isNotEmpty) {
        newShelves.add(ProviderShelfSection(title: 'Latest Updates', categoryPath: 'home', items: homeItems));
      }
      if (netflixItems.isNotEmpty) {
        newShelves.add(ProviderShelfSection(title: 'Netflix', categoryPath: 'netflix', items: netflixItems));
      }
      if (primeItems.isNotEmpty) {
        newShelves.add(ProviderShelfSection(title: 'Amazon Prime', categoryPath: 'prime', items: primeItems));
      }
      if (hotstarItems.isNotEmpty) {
        newShelves.add(ProviderShelfSection(title: 'Disney+ Hotstar', categoryPath: 'hotstar', items: hotstarItems));
      }
      if (animeItems.isNotEmpty) {
        newShelves.add(ProviderShelfSection(title: 'Anime Series', categoryPath: 'anime', items: animeItems));
      }

      final heroList = homeItems.take(5).map((e) => Movie(
        title: e.title, releaseDate: '', posterPath: e.poster, backdropPath: e.poster, overView: '', id: ProviderConfig.getStableMediaId(e.url), score: 7.5
      )).toList();
      
      final homeList = homeItems.map((e) => Movie(
        title: e.title, releaseDate: '', posterPath: e.poster, backdropPath: e.poster, overView: '', id: ProviderConfig.getStableMediaId(e.url), score: 7.5
      )).toList();

      Movie? hero = heroList.isNotEmpty ? heroList.first : (homeList.isNotEmpty ? homeList.first : null);
      String heroStatus = 'None';
      if (hero != null) {
        heroStatus = WatchStatusManager.getStatus(hero.id);
      }

      setState(() {
        _heroMovie = hero;
        _heroMovies = heroList.isNotEmpty ? heroList : homeList.take(6).toList();
        _heroIndex = 0;
        _heroWatchStatus = heroStatus;
        _homeMovies = homeList;
        _shelves = newShelves;
      });

      _startHeroAutoSlide();
    } catch (_) {}
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
    final providerItem = _providerItemMap[movie.id];
    if (providerItem != null) {
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: ProviderMediaDetailPage(
            title: providerItem.title,
            posterPath: providerItem.poster,
            permalink: providerItem.url,
            providerName: _selectedProvider,
          ),
        ),
      );
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
    final providerItem = _providerItemMap[movie.id];
    final currentStatus = WatchStatusManager.getStatus(movie.id);
    final newStatus = await SetWatchStatusModal.show(
      context,
      tmdbId: movie.id,
      title: movie.title,
      posterPath: movie.posterPath,
      initialStatus: currentStatus,
      permalink: providerItem?.url,
      providerName: _selectedProvider,
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

  void _showHomeFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.sizeOf(context).height * 0.70,
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Manage Extensions Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExtensionsScreen(
                              repoUrl: 'https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/CS.json',
                            ),
                          ),
                        ).then((_) {
                          _fetchDynamicProviders();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.extension_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Manage Extensions (Cloudstream)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'ACTIVE PROVIDER', 
                      style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Provider List
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _dynamicProviders.length,
                      itemBuilder: (context, index) {
                        final provider = _dynamicProviders[index];
                        final isSelected =
                            _selectedProvider.toLowerCase() == provider.name.toLowerCase();

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedProvider = provider.name;
                            });
                            setModalState(() {});
                            MediaProviderService.setSelectedProvider(provider.name);
                            Navigator.pop(ctx);
                            _loadAllData();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            child: Row(
                              children: [
                                // Checkmark on left
                                SizedBox(
                                  width: 24,
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // Provider name
                                Text(
                                  provider.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 15.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyProviderState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.extension_off_rounded,
                color: Colors.white38,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Provider Selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select an active media provider using the button below to browse content from streaming catalogs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showHomeFilterBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(CupertinoIcons.line_horizontal_3_decrease, size: 18),
              label: const Text(
                'Select Provider',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = TvFocusModeManager.isTvDevice;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = isTv
        ? 16.0
        : (bottomPadding > 0 ? bottomPadding : 88.0);
    final isNone = _selectedProvider.toLowerCase() == 'none';

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: isNone
                ? _buildEmptyProviderState(context)
                : RefreshIndicator(
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
                                    : _shelves[i].items.map((e) => Movie(title: e.title, releaseDate: '', posterPath: e.poster, backdropPath: e.poster, overView: '', id: ProviderConfig.getStableMediaId(e.url), score: 7.5)).toList(),
                                scrollController:
                                    i == 0 ? _homeShelfScrollController : null,
                                isLoadingNext:
                                    i == 0 ? _isLoadingNextPage : false,
                                onSeeAll: () => _openGridCategory(
                                  _shelves[i].title,
                                  i == 0
                                      ? _homeMovies
                                      : _shelves[i].items.map((e) => Movie(title: e.title, releaseDate: '', posterPath: e.poster, backdropPath: e.poster, overView: '', id: ProviderConfig.getStableMediaId(e.url), score: 7.5)).toList(),
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

          // Floating Action Button (FAB)
          Positioned(
            right: 20,
            bottom: bottomInset + 12,
            child: TvFocusWrapper(
              onTap: _showHomeFilterBottomSheet,
              borderRadius: 24,
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: isNone ? 14 : 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.line_horizontal_3_decrease,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (!isNone) ...[
                      const SizedBox(width: 8),
                      Text(
                        _selectedProvider,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
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
