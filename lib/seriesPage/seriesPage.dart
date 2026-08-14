import 'dart:ui';
import 'package:Mirarr/functions/fetchers/fetch_popular_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_trending_series.dart';
import 'package:Mirarr/functions/fetchers/fetch_series_by_genre.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/seriesPage/function/on_tap_gridview_serie.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'dart:async';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
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

const _seriesScrollBehavior = _TouchMouseScrollBehavior();

class SerieSearchScreen extends StatefulWidget {
  static final GlobalKey<_SerieSearchScreenState> movieSearchKey =
      GlobalKey<_SerieSearchScreenState>();

  const SerieSearchScreen({super.key});
  @override
  _SerieSearchScreenState createState() => _SerieSearchScreenState();
}

class _SerieSearchScreenState extends State<SerieSearchScreen> {
  final apiKey = dotenv.env['TMDB_API_KEY'];

  List<Serie> trendingSeries = [];
  List<Serie> popularSeries = [];
  List<Genre> genres = [];
  Map<int, List<Serie>> seriesByGenre = {};
  late RegionProvider _regionProvider;

  final List<Serie> _dummySeries = List.generate(
    6,
    (index) => Serie(
      name: 'TV Show Title Placeholder',
      posterPath: '',
      overView: 'This is a description placeholder for the tv show loading state.',
      id: -1 - index,
      score: 8.5,
    ),
  );

  final List<Genre> _dummyGenres = [
    Genre(id: -100, name: 'Genre Placeholder 1'),
    Genre(id: -101, name: 'Genre Placeholder 2'),
  ];

  late final Map<int, List<Serie>> _dummySeriesByGenre = {
    -100: List.generate(
      6,
      (index) => Serie(
        name: 'TV Show Title Placeholder',
        posterPath: '',
        overView: 'This is a description placeholder for the tv show loading state.',
        id: -200 - index,
        score: 8.5,
      ),
    ),
    -101: List.generate(
      6,
      (index) => Serie(
        name: 'TV Show Title Placeholder',
        posterPath: '',
        overView: 'This is a description placeholder for the tv show loading state.',
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

  Future<List<Serie>> _fetchTrendingSeries() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchTrendingSeries(region);
  }

  Future<List<Serie>> _fetchPopularSeries() async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    return await fetchPopularSeries(region);
  }

  Future<void> _loadPrimarySeries() async {
    try {
      final primaryResults = await Future.wait([
        _fetchTrendingSeries(),
        _fetchPopularSeries(),
      ]);

      if (mounted) {
        setState(() {
          trendingSeries = primaryResults[0];
          popularSeries = primaryResults[1];
        });
      }
    } catch (e) {
      debugPrint('Error fetching primary series data: $e');
    }
  }

  Future<void> _loadGenreSeries() async {
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
            final series = await fetchSeriesByGenre(genre.id, region);
            return MapEntry(genre.id, series);
          } catch (e) {
            debugPrint('Failed to fetch series for genre ${genre.name}: $e');
            return MapEntry(genre.id, <Serie>[]);
          }
        }));

        if (!mounted) return;
        setState(() {
          seriesByGenre = {
            ...seriesByGenre,
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

    // Add listener for region changes
    _regionProvider = Provider.of<RegionProvider>(context, listen: false);
    _regionProvider.addListener(_onRegionChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposing
    _regionProvider.removeListener(_onRegionChanged);
    super.dispose();
  }

  Future<void> checkInternetAndFetchData() async {
    if (mounted) {
      setState(() {
        trendingSeries = [];
        popularSeries = [];
        genres = [];
        seriesByGenre = {};
      });
    }

    // Primary shelves and genre lists load concurrently.
    await Future.wait([
      _loadPrimarySeries(),
      _loadGenreSeries(),
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
          'Series',
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
                _buildSectionHeader('Trending TV Shows', null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ScrollConfiguration(
                    behavior: _seriesScrollBehavior,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemExtent: 262,
                      itemCount: trendingSeries.isEmpty
                          ? _dummySeries.length
                          : trendingSeries.length,
                      itemBuilder: (context, index) {
                        final loading = trendingSeries.isEmpty;
                        final serie = loading
                            ? _dummySeries[index]
                            : trendingSeries[index];
                        final card = CustomSeriesWidget(serie: serie);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: loading
                              ? _skeletonCard(child: card)
                              : TvFocusWrapper(
                                  autoFocus: index == 0,
                                  onTap: () => onTapSerie(
                                      serie.name, serie.id, context),
                                  child: card,
                                ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Popular TV Shows', null),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ScrollConfiguration(
                    behavior: _seriesScrollBehavior,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemExtent: 262,
                      itemCount: popularSeries.isEmpty
                          ? _dummySeries.length
                          : popularSeries.length,
                      itemBuilder: (context, index) {
                        final loading = popularSeries.isEmpty;
                        final serie = loading
                            ? _dummySeries[index]
                            : popularSeries[index];
                        final card = CustomSeriesWidget(serie: serie);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: loading
                              ? _skeletonCard(child: card)
                              : TvFocusWrapper(
                                  onTap: () => onTapSerie(
                                      serie.name, serie.id, context),
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
                    genres.isNotEmpty && !seriesByGenre.containsKey(genre.id);
                final seriesList = genres.isEmpty
                    ? _dummySeriesByGenre[genre.id]
                    : genreLoading
                        ? _dummySeries
                        : seriesByGenre[genre.id];

                final loading = genres.isEmpty || genreLoading;
                final header = _buildSectionHeader(
                  genre.name,
                  loading || seriesByGenre[genre.id] == null
                      ? null
                      : () => onTapGridSerie(
                          seriesByGenre[genre.id] ?? [], context),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Skeletonize title until real genre names arrive.
                    genres.isEmpty ? _skeletonCard(child: header) : header,
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ScrollConfiguration(
                        behavior: _seriesScrollBehavior,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemExtent: 262,
                          itemCount: seriesList?.length ?? 0,
                          itemBuilder: (context, itemIndex) {
                            final serie = seriesList?[itemIndex];
                            if (serie == null) return const SizedBox.shrink();
                            final card = CustomSeriesWidget(serie: serie);
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: loading
                                  ? _skeletonCard(child: card)
                                  : TvFocusWrapper(
                                      onTap: () => onTapSerie(
                                          serie.name, serie.id, context),
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
