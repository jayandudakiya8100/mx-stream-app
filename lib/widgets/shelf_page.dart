import 'dart:async';
import 'package:Mirarr/functions/platform_helper.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:Mirarr/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:Mirarr/moviesPage/movieDetailPage.dart';
import 'package:Mirarr/seriesPage/serieDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/m3_expressive_spinner.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'package:Mirarr/moviesPage/UI/customMovieWidget.dart';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
import 'package:Mirarr/homePage/widgets/set_watch_status_modal.dart';
import 'package:Mirarr/homePage/widgets/provider_media_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:provider/provider.dart';
import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:intl/intl.dart';

class ShelfItem {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String type; // 'movie' or 'tv'
  final String status;
  final DateTime date;
  final double score;
  final String? permalink;
  final String? providerName;

  ShelfItem({
    required this.tmdbId,
    required this.title,
    this.posterPath,
    required this.type,
    required this.status,
    required this.date,
    this.score = 0.0,
    this.permalink,
    this.providerName,
  });
}

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();

  String _searchQuery = '';
  String _activeCategory = 'Watching';
  String _viewMode = 'grid'; // 'grid' (medium), 'list', 'compact'
  String _sortBy = 'date_desc'; // 'date_desc', 'date_asc', 'title_asc', 'rating_desc'

  bool _isLoading = true;
  List<ShelfItem> _allItems = [];

  final List<String> _categories = [
    'Watching',
    'Completed',
    'On-Hold',
    'Dropped',
    'Plan to Watch',
    'Favorites',
  ];

  static IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Watching':
        return Icons.play_circle_filled_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'On-Hold':
        return Icons.pause_circle_filled_rounded;
      case 'Dropped':
        return Icons.cancel_rounded;
      case 'Plan to Watch':
        return Icons.bookmark_rounded;
      case 'Favorites':
        return Icons.favorite_rounded;
      default:
        return Icons.bookmark_border_rounded;
    }
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Watching':
        return const Color(0xFF4CAF50);
      case 'Completed':
        return const Color(0xFF2196F3);
      case 'On-Hold':
        return const Color(0xFFFFB300);
      case 'Dropped':
        return const Color(0xFFE53935);
      case 'Plan to Watch':
        return const Color(0xFFAB47BC);
      case 'Favorites':
        return const Color(0xFFE91E63);
      default:
        return Colors.white70;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WatchStatusManager.watchStatusNotifier.addListener(_onGlobalWatchStatusChanged);
    _loadShelfItems();
  }

  @override
  void dispose() {
    WatchStatusManager.watchStatusNotifier.removeListener(_onGlobalWatchStatusChanged);
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _onGlobalWatchStatusChanged() {
    if (mounted) {
      _loadShelfItems();
    }
  }

  Future<void> _loadShelfItems() async {
    setState(() => _isLoading = true);

    try {
      final db = WatchHistoryDatabase();
      final historyList = await db.getAllWatchHistory();

      final box = Hive.box('sessionBox');
      final Map<int, ShelfItem> itemMap = {};

      // 1. Load from WatchHistoryDatabase
      for (final h in historyList) {
        final status = h.notes ?? WatchStatusManager.getStatus(h.tmdbId);
        final effectiveStatus = status.isNotEmpty && status != 'None' ? status : 'Watching';
        itemMap[h.tmdbId] = ShelfItem(
          tmdbId: h.tmdbId,
          title: h.title,
          posterPath: h.posterPath,
          type: h.type,
          status: effectiveStatus,
          date: h.watchedAt,
        );
      }

      // 2. Load from Hive provider_media_meta keys (persisted provider items with links)
      for (final key in box.keys) {
        if (key is String && key.startsWith('provider_media_meta_')) {
          final raw = box.get(key);
          if (raw is Map) {
            final id = raw['id'] as int? ?? 0;
            final title = raw['title']?.toString() ?? '';
            final poster = raw['posterPath']?.toString();
            final permalink = raw['permalink']?.toString();
            final providerName = raw['providerName']?.toString() ?? 'VegaMovies';
            final status = raw['status']?.toString() ?? 'Watching';
            final type = raw['type']?.toString() ?? 'movie';
            final dateStr = raw['date']?.toString();
            final date = dateStr != null
                ? DateTime.tryParse(dateStr) ?? DateTime.now()
                : DateTime.now();

            if (id != 0 && title.isNotEmpty && status != 'None') {
              itemMap[id] = ShelfItem(
                tmdbId: id,
                title: title,
                posterPath: poster,
                type: type,
                status: status,
                date: date,
                permalink: permalink,
                providerName: providerName,
              );
            }
          }
        }
      }

      // 3. Load from Hive sessionBox status keys
      for (final key in box.keys) {
        if (key is String && key.startsWith('watch_status_')) {
          final idStr = key.replaceFirst('watch_status_', '');
          final tmdbId = int.tryParse(idStr);
          final statusVal = box.get(key) as String?;
          if (tmdbId != null && statusVal != null && statusVal.isNotEmpty && statusVal != 'None') {
            if (itemMap.containsKey(tmdbId)) {
              final existing = itemMap[tmdbId]!;
              itemMap[tmdbId] = ShelfItem(
                tmdbId: tmdbId,
                title: existing.title,
                posterPath: existing.posterPath,
                type: existing.type,
                status: statusVal,
                date: existing.date,
                permalink: existing.permalink,
                providerName: existing.providerName,
              );
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allItems = itemMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDetail(ShelfItem item) {
    if (item.permalink != null && item.permalink!.isNotEmpty) {
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: ProviderMediaDetailPage(
            title: item.title,
            posterPath: item.posterPath ?? '',
            permalink: item.permalink!,
            providerName: item.providerName ?? 'VegaMovies',
          ),
        ),
      ).then((_) => _loadShelfItems());
    } else if (item.providerName != null && item.providerName!.isNotEmpty && item.providerName != 'TMDB') {
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: ProviderMediaDetailPage(
            title: item.title,
            posterPath: item.posterPath ?? '',
            permalink: item.permalink ?? '',
            providerName: item.providerName ?? 'VegaMovies',
          ),
        ),
      ).then((_) => _loadShelfItems());
    } else if (item.tmdbId > 10000000) {
      // Provider hash ID fallback
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: ProviderMediaDetailPage(
            title: item.title,
            posterPath: item.posterPath ?? '',
            permalink: item.permalink ?? '',
            providerName: item.providerName ?? 'VegaMovies',
          ),
        ),
      ).then((_) => _loadShelfItems());
    } else if (item.type == 'movie') {
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: MovieDetailPage(movieTitle: item.title, movieId: item.tmdbId),
        ),
      ).then((_) => _loadShelfItems());
    } else {
      Navigator.push(
        context,
        ExpressivePageRoute(
          page: SerieDetailPage(serieName: item.title, serieId: item.tmdbId),
        ),
      ).then((_) => _loadShelfItems());
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort Shelf By',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildSortOption('Date Added (Newest First)', 'date_desc'),
              _buildSortOption('Date Added (Oldest First)', 'date_asc'),
              _buildSortOption('Title (A - Z)', 'title_asc'),
              _buildSortOption('Rating (Highest First)', 'rating_desc'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4C68FF) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: Color(0xFF4C68FF), size: 20),
          ],
        ),
      ),
    );
  }

  List<ShelfItem> _getFilteredItems() {
    List<ShelfItem> list = _allItems.where((item) {
      if (_activeCategory == 'Favorites') {
        return item.status.toLowerCase() == 'favorites' || item.status.toLowerCase() == 'favorite';
      }
      return item.status.toLowerCase() == _activeCategory.toLowerCase();
    }).toList();

    if (_searchQuery.isNotEmpty) {
      list = list.where((item) => item.title.toLowerCase().contains(_searchQuery)).toList();
    }

    switch (_sortBy) {
      case 'date_asc':
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'title_asc':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'rating_desc':
        list.sort((a, b) => b.score.compareTo(a.score));
        break;
      case 'date_desc':
      default:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _getFilteredItems();
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = TvFocusModeManager.isTvDevice
        ? 16.0
        : (bottomPadding > 0 ? bottomPadding : 88.0);

    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        top: true,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Search Bar Header (Puzzle Icon + Search Pill + View Switchers)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
                  child: Row(
                    children: [
                      // Puzzle/Shelf Extension Icon
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.extension_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Pill Search Bar
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16181F),
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Theme(
                                  data: theme.copyWith(
                                    inputDecorationTheme: const InputDecorationTheme(
                                      filled: false,
                                      fillColor: Colors.transparent,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    autocorrect: false,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    cursorColor: Colors.white,
                                    cursorWidth: 2,
                                    decoration: const InputDecoration(
                                      hintText: 'Search...',
                                      hintStyle: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _searchController.clear(),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white60,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // View Mode Switchers
                      // 1. Medium Grid (Active blue)
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = 'grid'),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _viewMode == 'grid' ? const Color(0xFF3B5490) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: _viewMode == 'grid' ? Colors.white : Colors.white60,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 2. List View
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = 'list'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _viewMode == 'list' ? const Color(0xFF3B5490) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.view_list_rounded,
                            color: _viewMode == 'list' ? Colors.white : Colors.white60,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 3. Compact Grid
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = 'compact'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _viewMode == 'compact' ? const Color(0xFF3B5490) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.grid_on_rounded,
                            color: _viewMode == 'compact' ? Colors.white : Colors.white60,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Main Content Area (Grid / List / Compact)
                Expanded(
                  child: _isLoading
                      ? const Center(child: M3ExpressiveSpinner())
                      : filteredItems.isEmpty
                          ? _buildEmptyState()
                          : _viewMode == 'grid'
                              ? _buildMediumGrid(filteredItems, bottomInset)
                              : _viewMode == 'compact'
                                  ? _buildCompactGrid(filteredItems, bottomInset)
                                  : _buildListView(filteredItems, bottomInset),
                ),

                // 3. Category Filter Pills (Bottom - Directly Above Navigation Bar)
                Container(
                  height: 42,
                  margin: EdgeInsets.only(
                    bottom: bottomInset + 4,
                  ),
                  child: ListView.builder(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _activeCategory == cat;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeCategory = cat;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 16 : 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFF1E1E24),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(cat),
                                  size: 15,
                                  color: isSelected ? Colors.black : _getStatusColor(cat),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Floating Sort Button on Bottom Right (Positioned above Category Bar)
            Positioned(
              right: 20,
              bottom: bottomInset + 52,
              child: GestureDetector(
                onTap: _showSortBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(14),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Sort',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
          Text(
            'No items in "$_activeCategory"',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set watch status on movies or series to see them here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediumGrid(List<ShelfItem> items, double bottomInset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 900
            ? 5
            : width > 600
                ? 4
                : 3; // 3 columns on mobile (Screenshot 2)

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.58,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.type == 'movie') {
              final movie = Movie(
                title: item.title,
                releaseDate: DateFormat('yyyy').format(item.date),
                posterPath: item.posterPath ?? '',
                overView: '',
                id: item.tmdbId,
                score: item.score,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToDetail(item),
                child: TvFocusWrapper(
                  borderRadius: 16.0,
                  onTap: () => _navigateToDetail(item),
                  child: CustomMovieWidget(
                    movie: movie,
                    showAvailability: false,
                  ),
                ),
              );
            } else {
              final serie = Serie(
                name: item.title,
                posterPath: item.posterPath ?? '',
                overView: '',
                id: item.tmdbId,
                score: item.score,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToDetail(item),
                child: TvFocusWrapper(
                  borderRadius: 16.0,
                  onTap: () => _navigateToDetail(item),
                  child: CustomSeriesWidget(
                    serie: serie,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCompactGrid(List<ShelfItem> items, double bottomInset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 900
            ? 7
            : width > 600
                ? 5
                : 4; // 4 columns in compact mode

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: 0.56,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.type == 'movie') {
              final movie = Movie(
                title: item.title,
                releaseDate: '',
                posterPath: item.posterPath ?? '',
                overView: '',
                id: item.tmdbId,
                score: item.score,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToDetail(item),
                child: TvFocusWrapper(
                  borderRadius: 12.0,
                  onTap: () => _navigateToDetail(item),
                  child: CustomMovieWidget(
                    movie: movie,
                    showAvailability: false,
                  ),
                ),
              );
            } else {
              final serie = Serie(
                name: item.title,
                posterPath: item.posterPath ?? '',
                overView: '',
                id: item.tmdbId,
                score: item.score,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToDetail(item),
                child: TvFocusWrapper(
                  borderRadius: 12.0,
                  onTap: () => _navigateToDetail(item),
                  child: CustomSeriesWidget(
                    serie: serie,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildListView(List<ShelfItem> items, double bottomInset) {
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final posterUrl = item.posterPath != null && item.posterPath!.isNotEmpty
            ? '${getImageBaseUrl(region)}/t/p/w185${item.posterPath}'
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _navigateToDetail(item),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 55,
                      height: 80,
                      color: const Color(0xFF1E1E1E),
                      child: posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
                              errorWidget: (_, __, ___) => const Icon(Icons.movie, color: Colors.white38),
                            )
                          : const Icon(Icons.movie, color: Colors.white38),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4C68FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.type.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF4C68FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, yyyy').format(item.date),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
