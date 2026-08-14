import 'dart:async';
import 'package:Mirarr/functions/platform_helper.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:Mirarr/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:Mirarr/moviesPage/checkers/custom_tmdb_ids_effects.dart';
import 'package:Mirarr/moviesPage/movieDetailPage.dart';
import 'package:Mirarr/seriesPage/checkers/custom_tmdb_ids_effects_series.dart';
import 'package:Mirarr/seriesPage/serieDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/m3_expressive_spinner.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:provider/provider.dart';
import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:intl/intl.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  int _lastIndex = -1;
  late final NavigationProvider _nav;

  Future<void> _navigateToMovie(String title, int id) async {
    await Navigator.push(
      context,
      ExpressivePageRoute(
        page: MovieDetailPage(movieTitle: title, movieId: id),
      ),
    );
    if (mounted) {
      _loadWatchHistory();
    }
  }

  Future<void> _navigateToSerie(String title, int id) async {
    await Navigator.push(
      context,
      ExpressivePageRoute(
        page: SerieDetailPage(serieName: title, serieId: id),
      ),
    );
    if (mounted) {
      _loadWatchHistory();
    }
  }

  final WatchHistoryDatabase _database = WatchHistoryDatabase();
  final TextEditingController _movieSearchController = TextEditingController();
  final TextEditingController _showSearchController = TextEditingController();
  final TextEditingController _diarySearchController = TextEditingController();
  Timer? _searchDebounceTimer;
  
  String _movieQuery = '';
  String _showQuery = '';
  String _diaryQuery = '';

  List<WatchHistoryItem> watchedMovies = [];
  List<WatchHistoryItem> watchedShows = [];
  List<WatchHistoryItem> diaryItems = [];
  List<Map<String, dynamic>> _groupedShows = [];
  List<Map<String, dynamic>> _filteredGroupedShows = [];

  bool isLoading = true;

  // View state management
  String _activeSection = 'movies'; // 'movies', 'shows', 'diary'
  String _movieViewMode = 'grid'; // 'grid', 'list', 'compact'
  String _showViewMode = 'list'; // 'list' (episodes), 'grid' (grouped shows), 'compact' (grouped compact)
  String _diaryViewMode = 'timeline'; // 'timeline', 'list', 'grid'

  // Watch stats and runtime calculation state
  Box? _runtimesBox;
  int totalMovieMinutes = 0;
  int totalTvMinutes = 0;
  bool needsCalculation = false;
  int uncachedItemsCount = 0;
  bool isCalculating = false;
  double calculationProgress = 0.0;

  Future<Box> _getBox() async {
    if (_runtimesBox == null || !_runtimesBox!.isOpen) {
      _runtimesBox = await Hive.openBox('tmdbRuntimes');
    }
    return _runtimesBox!;
  }

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavigationProvider>()..addListener(_onNavChanged);
    _lastIndex = _nav.currentIndex;
    _loadWatchHistory();
  }

  void _onNavChanged() {
    if (_nav.currentIndex == 3 && _lastIndex != 3) {
      _loadWatchHistory();
    }
    _lastIndex = _nav.currentIndex;
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavChanged);
    _movieSearchController.dispose();
    _showSearchController.dispose();
    _diarySearchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  String _runtimeKey(WatchHistoryItem item) {
    return item.type == 'movie'
        ? 'movie_${item.tmdbId}'
        : 'tv_ep_${item.tmdbId}_${item.seasonNumber}_${item.episodeNumber}';
  }

  Widget _shelfPoster({
    required String? posterPath,
    required String region,
    required String size,
    required int memCacheWidth,
    required Widget placeholder,
  }) {
    if (posterPath == null || posterPath.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: '${getImageBaseUrl(region)}/t/p/$size$posterPath',
      memCacheWidth: memCacheWidth,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  Future<void> _loadWatchHistory() async {
    // This also runs on every entry into the shelf tab and on every pop back
    // from a detail page, so the spinner is only for the very first load.
    if (diaryItems.isEmpty) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final diary = await _database.getAllWatchHistory();

      final movies = diary.where((item) => item.type == 'movie').toList();
      final shows = diary.where((item) => item.type == 'tv').toList();

      final runtimesBox = await _getBox();

      int uncachedCount = 0;
      int movieMins = 0;
      int tvMins = 0;

      for (final item in diary) {
        final runtimeVal = runtimesBox.get(_runtimeKey(item)) as int?;
        if (runtimeVal == null) {
          uncachedCount++;
        } else if (item.type == 'movie') {
          movieMins += runtimeVal;
        } else {
          tvMins += runtimeVal;
        }
      }

      if (!mounted) return;
      setState(() {
        watchedMovies = movies;
        watchedShows = shows;
        diaryItems = diary;
        _rebuildGroupedShows();
        totalMovieMinutes = movieMins;
        totalTvMinutes = tvMins;
        needsCalculation = uncachedCount > 0;
        uncachedItemsCount = uncachedCount;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading watch history: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Drops a single entry without re-reading and re-decoding the whole
  /// history, which is what the delete affordances used to do.
  Future<void> _deleteHistoryItem(WatchHistoryItem item) async {
    final id = item.id;
    if (id == null) return;

    await _database.deleteWatchHistoryItem(id);
    final runtimesBox = await _getBox();
    final runtime = runtimesBox.get(_runtimeKey(item)) as int?;
    if (!mounted) return;

    setState(() {
      watchedMovies.removeWhere((entry) => entry.id == id);
      watchedShows.removeWhere((entry) => entry.id == id);
      diaryItems.removeWhere((entry) => entry.id == id);
      if (item.type == 'tv') {
        _rebuildGroupedShows();
      }

      if (runtime == null) {
        uncachedItemsCount = uncachedItemsCount > 0 ? uncachedItemsCount - 1 : 0;
        needsCalculation = uncachedItemsCount > 0;
      } else if (item.type == 'movie') {
        totalMovieMinutes -= runtime;
      } else {
        totalTvMinutes -= runtime;
      }
    });
  }

  void _debouncedSetState(void Function() fn) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(fn);
    });
  }

  Future<void> _fetchRuntimes() async {
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final apiKey = dotenv.env['TMDB_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TMDB API Key not found in environment.')),
      );
      return;
    }

    setState(() {
      isCalculating = true;
      calculationProgress = 0.0;
    });

    try {
      final runtimesBox = await _getBox();

      // 1. Gather all uncached items
      final List<WatchHistoryItem> uncachedMovies = [];
      for (final m in watchedMovies) {
        if (!runtimesBox.containsKey(_runtimeKey(m))) {
          uncachedMovies.add(m);
        }
      }

      // Group TV shows episodes by tvId and season number to request season runtimes
      final Map<String, List<WatchHistoryItem>> uncachedTvGroups = {};
      for (final s in watchedShows) {
        final key = _runtimeKey(s);
        if (!runtimesBox.containsKey(key)) {
          final groupKey = '${s.tmdbId}_${s.seasonNumber}';
          uncachedTvGroups.putIfAbsent(groupKey, () => []).add(s);
        }
      }

      final totalSteps = uncachedMovies.length + uncachedTvGroups.length;
      int completedSteps = 0;

      // 2. Fetch movies runtimes
      for (final movie in uncachedMovies) {
        try {
          final response = await apiClient.get(Uri.parse('${baseUrl}movie/${movie.tmdbId}?api_key=$apiKey'));
          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            final runtime = data['runtime'] as int? ?? 100;
            await runtimesBox.put('movie_${movie.tmdbId}', runtime);
          } else {
            await runtimesBox.put('movie_${movie.tmdbId}', 100);
          }
        } catch (_) {
          await runtimesBox.put('movie_${movie.tmdbId}', 100);
        }
        completedSteps++;
        if (mounted) {
          setState(() {
            calculationProgress = completedSteps / totalSteps;
          });
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 3. Fetch TV season runtimes
      for (final entry in uncachedTvGroups.entries) {
        final parts = entry.key.split('_');
        final tvId = int.parse(parts[0]);
        final seasonNum = int.parse(parts[1]);
        final eps = entry.value;

        try {
          final response = await apiClient.get(Uri.parse('${baseUrl}tv/$tvId/season/$seasonNum?api_key=$apiKey'));
          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            final List<dynamic>? episodesList = data['episodes'] as List<dynamic>?;
            
            final Map<int, int> runtimesMap = {};
            if (episodesList != null) {
              for (final ep in episodesList) {
                final epNum = ep['episode_number'] as int?;
                final runtimeVal = ep['runtime'] as int?;
                if (epNum != null) {
                  runtimesMap[epNum] = runtimeVal ?? 45;
                }
              }
            }

            for (final epItem in eps) {
              final runtime = runtimesMap[epItem.episodeNumber] ?? 45;
              await runtimesBox.put(
                'tv_ep_${epItem.tmdbId}_${epItem.seasonNumber}_${epItem.episodeNumber}',
                runtime,
              );
            }
          } else {
            for (final epItem in eps) {
              await runtimesBox.put(
                'tv_ep_${epItem.tmdbId}_${epItem.seasonNumber}_${epItem.episodeNumber}',
                45,
              );
            }
          }
        } catch (_) {
          for (final epItem in eps) {
            await runtimesBox.put(
              'tv_ep_${epItem.tmdbId}_${epItem.seasonNumber}_${epItem.episodeNumber}',
              45,
            );
          }
        }

        completedSteps++;
        if (mounted) {
          setState(() {
            calculationProgress = completedSteps / totalSteps;
          });
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() {
          isCalculating = false;
        });
        _loadWatchHistory();
      }
    } catch (e) {
      print('Error calculating runtimes: $e');
      if (mounted) {
        setState(() {
          isCalculating = false;
        });
        _loadWatchHistory();
      }
    }
  }

  void _showCalculationWarningDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          icon: Icon(Icons.warning_amber_rounded, color: colorScheme.primary, size: 32),
          title: Text(
            'Fetch Watch Times',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            'This will query TMDB API for $uncachedItemsCount uncached watch logs to calculate exact runtimes. This may take a while depending on network conditions.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _fetchRuntimes();
              },
              child: const Text('Calculate Now'),
            ),
          ],
        );
      },
    );
  }

  String _formatWatchTime(int totalMinutes) {
    if (totalMinutes == 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  String _formatWatchTimeYMD(int totalMinutes) {
    if (totalMinutes == 0) return '0d';
    int remainingMins = totalMinutes;
    final years = remainingMins ~/ 525600;
    remainingMins %= 525600;
    final months = remainingMins ~/ 43200;
    remainingMins %= 43200;
    final days = remainingMins ~/ 1440;
    List<String> parts = [];
    if (years > 0) parts.add('${years}y');
    if (months > 0) parts.add('${months}mo');
    if (days > 0) parts.add('${days}d');
    if (parts.isEmpty) {
      return totalMinutes > 0 ? '<1d' : '0d';
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final width = MediaQuery.sizeOf(context).width;
    final bool isLargeScreen = width >= 800;

    return Scaffold(
      extendBody: true,
      body: isLoading
          ? const M3ExpressiveSpinner()
          : isLargeScreen
              ? _buildDesktopLayout(region)
              : _buildMobileLayout(region),
    );
  }

  // Desktop Shell Layout
  Widget _buildDesktopLayout(String region) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopSidebar(),
        Expanded(
          child: Column(
            children: [
              _buildDesktopHeader(),
              Expanded(
                child: _buildMainContent(region),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Mobile Shell Layout
  Widget _buildMobileLayout(String region) {
    final double topPadding = AppPlatform.isMobile ? 36.0 : 12.0;

    return Column(
      children: [
        SizedBox(height: topPadding),
        _buildMobileSegmentControl(),
        _buildMobileControls(),
        _buildMobileWatchTimeBanner(),
        Expanded(
          child: _buildMainContent(region),
        ),
      ],
    );
  }

  // Desktop Left Sidebar
  Widget _buildDesktopSidebar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sections = [
      {'id': 'movies', 'label': 'Movies', 'icon': Icons.movie, 'desc': 'Watched films'},
      {'id': 'shows', 'label': 'TV Shows', 'icon': Icons.tv, 'desc': 'Logged episodes'},
      {'id': 'diary', 'label': 'Watch Diary', 'icon': Icons.book, 'desc': 'Chronological feed'},
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.shelves, size: 28, color: colorScheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY SHELF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Local Database',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // Sidebar Nav buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: sections.map((sec) {
                final isSelected = _activeSection == sec['id'];
                int count = 0;
                if (sec['id'] == 'movies') count = watchedMovies.length;
                if (sec['id'] == 'shows') count = watchedShows.length;
                if (sec['id'] == 'diary') count = diaryItems.length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _activeSection = sec['id'] as String),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sec['icon'] as IconData,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sec['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sec['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.2)
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Spacer(),
          // Stats box
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'SHELF STATS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatItem('Movies Logged', watchedMovies.length.toString()),
                  const SizedBox(height: 10),
                  _buildStatItem('TV Episodes Logged', watchedShows.length.toString()),
                  const SizedBox(height: 10),
                  _buildStatItem('Unique Shows', watchedShows.map((s) => s.tmdbId).toSet().length.toString()),
                  const SizedBox(height: 10),
                  _buildStatItem(
                    'Movies Time',
                    _formatWatchTime(totalMovieMinutes),
                    secondaryValue: _formatWatchTimeYMD(totalMovieMinutes),
                  ),
                  const SizedBox(height: 10),
                  _buildStatItem(
                    'TV Shows Time',
                    _formatWatchTime(totalTvMinutes),
                    secondaryValue: _formatWatchTimeYMD(totalTvMinutes),
                  ),
                  Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    height: 16,
                  ),
                  _buildStatItem(
                    'Total Watch Time',
                    _formatWatchTime(totalMovieMinutes + totalTvMinutes),
                    secondaryValue: _formatWatchTimeYMD(totalMovieMinutes + totalTvMinutes),
                  ),
                  if (isCalculating) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: calculationProgress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fetching... ${(calculationProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else if (needsCalculation) ...[
                    const SizedBox(height: 12),
                    _buildCalculateWatchTimeButton(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {String? secondaryValue}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (secondaryValue != null) ...[
              const SizedBox(height: 2),
              Text(
                secondaryValue,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCalculateWatchTimeButton({bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: compact ? 32 : 36,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(Icons.timer_outlined, size: compact ? 14 : 16),
        label: Text(
          'Calc. times ($uncachedItemsCount)',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _showCalculationWarningDialog,
      ),
    );
  }

  // Desktop Header
  Widget _buildDesktopHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeController = _activeSection == 'movies'
        ? _movieSearchController
        : _activeSection == 'shows'
            ? _showSearchController
            : _diarySearchController;

    String sectionTitle = '';
    if (_activeSection == 'movies') sectionTitle = 'Watched Movies';
    if (_activeSection == 'shows') sectionTitle = 'TV Shows';
    if (_activeSection == 'diary') sectionTitle = 'Watch Diary';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            sectionTitle,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 300,
            child: TextField(
              controller: activeController,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              cursorColor: colorScheme.primary,
              onChanged: (value) => _debouncedSetState(() {
                if (_activeSection == 'movies') _movieQuery = value;
                if (_activeSection == 'shows') {
                  _showQuery = value;
                  _applyShowQueryFilter();
                }
                if (_activeSection == 'diary') _diaryQuery = value;
              }),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                hintText: 'Search logs...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildViewSwitcher(),
        ],
      ),
    );
  }

  Widget _buildMobileSegmentControl() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sections = [
      {'id': 'movies', 'label': 'Movies', 'icon': Icons.movie_outlined},
      {'id': 'shows', 'label': 'Shows', 'icon': Icons.tv_outlined},
      {'id': 'diary', 'label': 'Diary', 'icon': Icons.book_outlined},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: sections.map((sec) {
          final isSelected = _activeSection == sec['id'];
          int count = 0;
          if (sec['id'] == 'movies') count = watchedMovies.length;
          if (sec['id'] == 'shows') count = watchedShows.length;
          if (sec['id'] == 'diary') count = diaryItems.length;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeSection = sec['id'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      sec['icon'] as IconData,
                      size: 16,
                      color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sec['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.2)
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


  // Mobile controls (Search & View Modes)
  Widget _buildMobileControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final activeController = _activeSection == 'movies'
        ? _movieSearchController
        : _activeSection == 'shows'
            ? _showSearchController
            : _diarySearchController;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: activeController,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              cursorColor: colorScheme.primary,
              onChanged: (value) => _debouncedSetState(() {
                if (_activeSection == 'movies') _movieQuery = value;
                if (_activeSection == 'shows') {
                  _showQuery = value;
                  _applyShowQueryFilter();
                }
                if (_activeSection == 'diary') _diaryQuery = value;
              }),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                hintText: 'Search $_activeSection...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildViewSwitcher(),
        ],
      ),
    );
  }

  // Mobile watch stats banner
  Widget _buildMobileWatchTimeBanner() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Movies Time', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(_formatWatchTime(totalMovieMinutes), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    _formatWatchTimeYMD(totalMovieMinutes),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              Container(height: 30, width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              Column(
                children: [
                  Text('TV Shows Time', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(_formatWatchTime(totalTvMinutes), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    _formatWatchTimeYMD(totalTvMinutes),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              Container(height: 30, width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              Column(
                children: [
                  Text('Total Time', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    _formatWatchTime(totalMovieMinutes + totalTvMinutes),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatWatchTimeYMD(totalMovieMinutes + totalTvMinutes),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          if (isCalculating) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: calculationProgress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Fetching... ${(calculationProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (needsCalculation) ...[
            const SizedBox(height: 8),
            _buildCalculateWatchTimeButton(compact: true),
          ],
        ],
      ),
    );
  }

  // Section view modes toggler buttons
  Widget _buildViewSwitcher() {
    if (_activeSection == 'movies') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewOptionButton('grid', Icons.grid_view, _movieViewMode, (val) => setState(() => _movieViewMode = val)),
          _buildViewOptionButton('list', Icons.view_list, _movieViewMode, (val) => setState(() => _movieViewMode = val)),
          _buildViewOptionButton('compact', Icons.grid_on_outlined, _movieViewMode, (val) => setState(() => _movieViewMode = val)),
        ],
      );
    } else if (_activeSection == 'shows') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewOptionButton('list', Icons.view_list, _showViewMode, (val) => setState(() => _showViewMode = val)),
          _buildViewOptionButton('grid', Icons.grid_view, _showViewMode, (val) => setState(() => _showViewMode = val)),
          _buildViewOptionButton('compact', Icons.grid_on_outlined, _showViewMode, (val) => setState(() => _showViewMode = val)),
        ],
      );
    } else {
      // Diary
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewOptionButton('timeline', Icons.timeline, _diaryViewMode, (val) => setState(() => _diaryViewMode = val)),
          _buildViewOptionButton('list', Icons.view_list, _diaryViewMode, (val) => setState(() => _diaryViewMode = val)),
          _buildViewOptionButton('grid', Icons.grid_view, _diaryViewMode, (val) => setState(() => _diaryViewMode = val)),
        ],
      );
    }
  }

  Widget _buildViewOptionButton(String mode, IconData icon, String currentMode, Function(String) onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = mode == currentMode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => onTap(mode),
      ),
    );
  }

  // Switch content areas
  Widget _buildMainContent(String region) {
    if (_activeSection == 'movies') {
      return _buildMoviesContent(region);
    } else if (_activeSection == 'shows') {
      return _buildShowsContent(region);
    } else {
      return _buildDiaryContent(region);
    }
  }

  // MOVIES CONTENT LAYER
  Widget _buildMoviesContent(String region) {
    final String query = _movieQuery.trim().toLowerCase();
    final List<WatchHistoryItem> baseList = watchedMovies;
    final List<WatchHistoryItem> filtered = query.isEmpty
        ? baseList
        : baseList
            .where((m) => m.title.toLowerCase().contains(query))
            .toList();

    if (baseList.isEmpty && query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.movie_outlined,
        title: 'No watched movies yet',
        subtitle: 'Start watching movies to see them here!',
      );
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.grey)),
      );
    }

    if (_movieViewMode == 'grid') {
      return _buildMovieGrid(filtered, region, isCompact: false);
    } else if (_movieViewMode == 'compact') {
      return _buildMovieGrid(filtered, region, isCompact: true);
    } else {
      return _buildMovieListView(filtered, region);
    }
  }

  Widget _buildMovieGrid(List<WatchHistoryItem> items, String region, {required bool isCompact}) {
    final width = MediaQuery.sizeOf(context).width;
    final isLarge = width >= 800;
    
    int crossAxisCount;
    if (isCompact) {
      crossAxisCount = isLarge ? 7 : 4;
    } else {
      crossAxisCount = isLarge ? 5 : 3;
    }

    return GridView.builder(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: isCompact ? 8 : 12,
        mainAxisSpacing: isCompact ? 8 : 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final movie = items[index];
        if (isCompact) {
          return _buildCompactGridCard(movie, region);
        } else {
          return _buildDetailedGridCard(movie, region);
        }
      },
    );
  }

  Widget _buildMovieListView(List<WatchHistoryItem> items, String region) {
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final movie = items[index];
        return _buildDetailedListRow(movie, region);
      },
    );
  }

  // TV SHOWS CONTENT LAYER
  Widget _buildShowsContent(String region) {
    final String query = _showQuery.trim().toLowerCase();
    final List<WatchHistoryItem> baseList = watchedShows;
    final List<WatchHistoryItem> filtered = query.isEmpty
        ? baseList
        : baseList
            .where((s) => s.title.toLowerCase().contains(query))
            .toList();

    if (baseList.isEmpty && query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.tv_outlined,
        title: 'No watched shows yet',
        subtitle: 'Start watching shows to see them here!',
      );
    }

    if (_showViewMode == 'list') {
      if (filtered.isEmpty) {
        return const Center(
          child: Text('No results', style: TextStyle(color: Colors.grey)),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final show = filtered[index];
          return _buildDetailedListRow(show, region);
        },
      );
    }

    if (_filteredGroupedShows.isEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.grey)),
      );
    }

    if (_showViewMode == 'compact') {
      return GridView.builder(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 7 : 4,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _filteredGroupedShows.length,
        itemBuilder: (context, index) {
          final showGroup = _filteredGroupedShows[index];
          return _buildGroupedShowCompactCard(showGroup, region);
        },
      );
    }

    // Grid Grouped Shows
    return GridView.builder(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 5 : 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredGroupedShows.length,
      itemBuilder: (context, index) {
        final showGroup = _filteredGroupedShows[index];
        return _buildGroupedShowDetailedCard(showGroup, region);
      },
    );
  }

  List<Map<String, dynamic>> _getGroupedShowsList(List<WatchHistoryItem> sourceList) {
    final Map<int, List<WatchHistoryItem>> groups = {};
    for (final item in sourceList) {
      groups.putIfAbsent(item.tmdbId, () => []).add(item);
    }
    return groups.entries.map((e) {
      final episodes = e.value;
      episodes.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      final latest = episodes.first;
      return {
        'tmdbId': e.key,
        'title': latest.title,
        'posterPath': latest.posterPath,
        'count': episodes.length,
        'episodes': episodes,
        'latestWatchedAt': latest.watchedAt,
      };
    }).toList()
      ..sort((a, b) => (b['latestWatchedAt'] as DateTime)
          .compareTo(a['latestWatchedAt'] as DateTime));
  }

  void _rebuildGroupedShows() {
    _groupedShows = _getGroupedShowsList(watchedShows);
    _applyShowQueryFilter();
  }

  void _applyShowQueryFilter() {
    final query = _showQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredGroupedShows = _groupedShows;
    } else {
      _filteredGroupedShows = _groupedShows
          .where((g) => (g['title'] as String).toLowerCase().contains(query))
          .toList();
    }
  }

  // DIARY CONTENT LAYER
  Widget _buildDiaryContent(String region) {
    final String query = _diaryQuery.trim().toLowerCase();
    final List<WatchHistoryItem> baseList = diaryItems;
    final List<WatchHistoryItem> filtered = query.isEmpty
        ? baseList
        : baseList
            .where((d) => d.title.toLowerCase().contains(query))
            .toList();

    if (baseList.isEmpty && query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book_outlined,
        title: 'Your diary is empty',
        subtitle: 'Watch movies and shows to build your diary!',
      );
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.grey)),
      );
    }

    if (_diaryViewMode == 'grid') {
      return _buildMovieGrid(filtered, region, isCompact: false);
    } else if (_diaryViewMode == 'list') {
      return ListView.builder(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildDetailedListRow(item, region);
        },
      );
    } else {
      // Timeline (default)
      return _buildTimelineDiaryView(filtered, region);
    }
  }

  // DIARY TIMELINE VIEW
  Widget _buildTimelineDiaryView(List<WatchHistoryItem> items, String region) {
    final Map<String, List<WatchHistoryItem>> grouped = {};
    for (final item in items) {
      final monthKey = DateFormat('MMMM yyyy').format(item.watchedAt);
      grouped.putIfAbsent(monthKey, () => []).add(item);
    }

    final keys = grouped.keys.toList();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final monthKey = keys[index];
          final monthItems = grouped[monthKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        monthKey,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(monthItems.length, (itemIndex) {
                final item = monthItems[itemIndex];
                final isLastItem = itemIndex == monthItems.length - 1 && index == keys.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 48,
                        child: Column(
                          children: [
                            Container(
                              width: 2,
                              height: 12,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            TvFocusWrapper(
                              onTap: () async {
                                final confirm = await _showDeleteConfirmation(item);
                                if (confirm == true) {
                                  await _deleteHistoryItem(item);
                                }
                              },
                              borderRadius: 16.0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: item.type == 'movie'
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: item.type == 'movie' ? Colors.orange : Colors.blue,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (item.type == 'movie' ? Colors.orange : Colors.blue).withValues(alpha: 0.2),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  item.type == 'movie' ? Icons.movie : Icons.tv,
                                  size: 14,
                                  color: item.type == 'movie' ? Colors.orange : Colors.blue,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isLastItem ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildTimelineItemCard(item, region),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineItemCard(WatchHistoryItem item, String region) {
    final isMovie = item.type == 'movie';
    return Dismissible(
      key: Key('timeline_item_${item.id ?? item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(item),
      onDismissed: (direction) async {
        await _deleteHistoryItem(item);
      },
      child: TvFocusWrapper(
        onTap: () {
          if (isMovie) {
            _navigateToMovie(item.title, item.tmdbId);
          } else {
            _navigateToSerie(item.title, item.tmdbId);
          }
        },
        borderRadius: 16.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.015),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 90,
                    child: _shelfPoster(
                      posterPath: item.posterPath,
                      region: region,
                      size: 'w92',
                      memCacheWidth: 120,
                      placeholder: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: (isMovie ? getMovieTitleTextStyle(item.tmdbId) : getSeriesTitleTextStyle(item.tmdbId)).copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                isMovie ? Icons.movie_outlined : Icons.tv_outlined,
                                size: 10,
                                color: Colors.white30,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isMovie
                                    ? 'Movie'
                                    : ('TV Show' +
                                        (item.seasonNumber != null
                                            ? ' • S${item.seasonNumber} E${item.episodeNumber}'
                                            : '')),
                                style: const TextStyle(color: Colors.white30, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('hh:mm a • EEE, MMM dd').format(item.watchedAt),
                            style: const TextStyle(color: Colors.white24, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // DETAILED CARD/ROW RENDERERS
  Widget _buildDetailedGridCard(WatchHistoryItem item, String region) {
    final isMovie = item.type == 'movie';
    return GestureDetector(
      onLongPress: () async {
        final confirm = await _showDeleteConfirmation(item);
        if (confirm == true) {
          await _deleteHistoryItem(item);
        }
      },
      child: TvFocusWrapper(
        onTap: () {
          if (isMovie) {
            _navigateToMovie(item.title, item.tmdbId);
          } else {
            _navigateToSerie(item.title, item.tmdbId);
          }
        },
        borderRadius: 16.0,
        child: Card(
          elevation: 6,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withValues(alpha: 0.03),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _shelfPoster(
                  posterPath: item.posterPath,
                  region: region,
                  size: 'w185',
                  memCacheWidth: 280,
                  placeholder: Icon(isMovie ? Icons.movie : Icons.tv, size: 40, color: Colors.grey[700]),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: (isMovie ? getMovieTitleTextStyle(item.tmdbId) : getSeriesTitleTextStyle(item.tmdbId)).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (item.seasonNumber != null && item.episodeNumber != null)
                        Text(
                          'S${item.seasonNumber} E${item.episodeNumber}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(item.watchedAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGridCard(WatchHistoryItem item, String region) {
    final isMovie = item.type == 'movie';
    return GestureDetector(
      onLongPress: () async {
        final confirm = await _showDeleteConfirmation(item);
        if (confirm == true) {
          await _deleteHistoryItem(item);
        }
      },
      child: TvFocusWrapper(
        onTap: () {
          if (isMovie) {
            _navigateToMovie(item.title, item.tmdbId);
          } else {
            _navigateToSerie(item.title, item.tmdbId);
          }
        },
        borderRadius: 8.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _shelfPoster(
                posterPath: item.posterPath,
                region: region,
                size: 'w185',
                memCacheWidth: 200,
                placeholder: Icon(isMovie ? Icons.movie : Icons.tv, size: 24, color: Colors.grey[700]),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isMovie ? Icons.movie : Icons.tv,
                  size: 8,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedListRow(WatchHistoryItem item, String region) {
    final isMovie = item.type == 'movie';
    return Dismissible(
      key: Key('detailed_list_item_${item.id ?? item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(item),
      onDismissed: (direction) async {
        await _deleteHistoryItem(item);
      },
      child: TvFocusWrapper(
        onTap: () {
          if (isMovie) {
            _navigateToMovie(item.title, item.tmdbId);
          } else {
            _navigateToSerie(item.title, item.tmdbId);
          }
        },
        borderRadius: 16.0,
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 108,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _shelfPoster(
                      posterPath: item.posterPath,
                      region: region,
                      size: 'w185',
                      memCacheWidth: 200,
                      placeholder: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.grey[600], size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: (isMovie ? getMovieTitleTextStyle(item.tmdbId) : getSeriesTitleTextStyle(item.tmdbId)).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (item.seasonNumber != null && item.episodeNumber != null) ...[
                        Text(
                          'Season ${item.seasonNumber}, Episode ${item.episodeNumber}' +
                              (item.episodeTitle != null ? ' - "${item.episodeTitle}"' : ''),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 10, color: Colors.white30),
                          const SizedBox(width: 4),
                          Text(
                            'Watched on ${DateFormat('MMM dd, yyyy').format(item.watchedAt)}',
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // GROUPED SHOWS RENDERERS
  Widget _buildGroupedShowDetailedCard(Map<String, dynamic> showGroup, String region) {
    final tmdbId = showGroup['tmdbId'] as int;
    final title = showGroup['title'] as String;
    final posterPath = showGroup['posterPath'] as String?;
    final count = showGroup['count'] as int;
    final episodes = showGroup['episodes'] as List<WatchHistoryItem>;

    return TvFocusWrapper(
      onTap: () => _navigateToSerie(title, tmdbId),
      borderRadius: 16.0,
      child: Card(
        elevation: 6,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white.withValues(alpha: 0.03),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _shelfPoster(
                posterPath: posterPath,
                region: region,
                size: 'w185',
                memCacheWidth: 280,
                placeholder: Icon(Icons.tv, size: 40, color: Colors.grey[700]),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    '$count Ep${count > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: getSeriesTitleTextStyle(tmdbId).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last: ${DateFormat('MMM dd').format(showGroup['latestWatchedAt'] as DateTime)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: InkWell(
                  onTap: () {
                    _showGroupedEpisodesBottomSheet(title, episodes, region);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.list_alt, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedShowCompactCard(Map<String, dynamic> showGroup, String region) {
    final tmdbId = showGroup['tmdbId'] as int;
    final title = showGroup['title'] as String;
    final posterPath = showGroup['posterPath'] as String?;
    final count = showGroup['count'] as int;
    final episodes = showGroup['episodes'] as List<WatchHistoryItem>;

    return TvFocusWrapper(
      onTap: () => _navigateToSerie(title, tmdbId),
      borderRadius: 8.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _shelfPoster(
              posterPath: posterPath,
              region: region,
              size: 'w185',
              memCacheWidth: 200,
              placeholder: const Icon(Icons.tv, size: 20, color: Colors.grey),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: InkWell(
                onTap: () => _showGroupedEpisodesBottomSheet(title, episodes, region),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.list_alt, size: 10, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BOTTOM SHEET & DIALOG LAYER
  void _showGroupedEpisodesBottomSheet(String showTitle, List<WatchHistoryItem> episodes, String region) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                showTitle,
                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Watched Episodes (Swipe left to delete)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: episodes.length,
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    return ListTileTheme(
                      textColor: Colors.white,
                      child: Dismissible(
                        key: Key('grouped_ep_${ep.id ?? ep.hashCode}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 24),
                        ),
                        confirmDismiss: (direction) => _showDeleteConfirmation(ep),
                        onDismissed: (direction) async {
                          await _deleteHistoryItem(ep);
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'S${ep.seasonNumber} E${ep.episodeNumber}' + (ep.episodeTitle != null ? ' - ${ep.episodeTitle}' : ''),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Watched: ${DateFormat('MMM dd, yyyy').format(ep.watchedAt)}',
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(WatchHistoryItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 32),
          title: Text(
            'Delete Watch Log',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "${item.title}" from your watch history?',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
