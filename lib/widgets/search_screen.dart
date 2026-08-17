import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/moviesPage/UI/cast_crew_row.dart';
import 'package:Mirarr/moviesPage/UI/customMovieWidget.dart';
import 'package:Mirarr/moviesPage/functions/on_tap_movie.dart';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:Mirarr/widgets/discover/discover_with_filters.dart';
import 'package:Mirarr/widgets/models/person.dart';
import 'package:Mirarr/widgets/person_result.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _categoryScrollController = ScrollController();
  int _selectedTabIndex = 0;

  List<Movie> movieResults = [];
  List<Serie> tvResults = [];
  List<Serie> animeResults = [];
  List<Serie> asianDramaResults = [];
  List<Serie> cartoonResults = [];
  List<Person> personResults = [];

  List<String> _searchHistory = [];

  final apiKey = dotenv.env['TMDB_API_KEY'];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _searchFetchId = 0;
  bool _isLoading = false;

  late FocusNode _searchFocusNode;

  final List<String> _tabs = [
    'All',
    'Movies',
    'TV Series',
    'Anime',
    'Asian Dramas',
    'Cartoons',
    'People',
    'Discover',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode = FocusNode();
    _loadSearchHistory();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
      _scrollToSelectedCategory(_selectedTabIndex);
    }
  }

  void _scrollToSelectedCategory(int index) {
    if (_categoryScrollController.hasClients) {
      final double targetOffset = (index * 90.0) - 40.0;
      _categoryScrollController.animateTo(
        targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _loadSearchHistory() {
    try {
      final box = Hive.box('sessionBox');
      final list = box.get('search_history');
      if (list is List && list.isNotEmpty) {
        setState(() {
          _searchHistory = List<String>.from(list);
        });
      } else {
        setState(() {
          _searchHistory = [];
        });
      }
    } catch (_) {
      setState(() {
        _searchHistory = [];
      });
    }
  }

  void _saveSearchHistory() {
    try {
      final box = Hive.box('sessionBox');
      box.put('search_history', _searchHistory);
    } catch (_) {}
  }

  void _addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _searchHistory.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      _searchHistory.insert(0, trimmed);
      if (_searchHistory.length > 25) {
        _searchHistory = _searchHistory.sublist(0, 25);
      }
    });
    _saveSearchHistory();
  }

  void _removeHistoryItem(String item) {
    setState(() {
      _searchHistory.remove(item);
    });
    _saveSearchHistory();
  }

  void _clearSearchHistory() {
    setState(() {
      _searchHistory.clear();
    });
    _saveSearchHistory();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _searchController.text.trim();
      if (!mounted) return;
      if (query.isNotEmpty) {
        _runSearch(query);
      } else {
        _searchFetchId++;
        setState(() {
          _isLoading = false;
          movieResults = [];
          tvResults = [];
          animeResults = [];
          asianDramaResults = [];
          cartoonResults = [];
          personResults = [];
        });
      }
    });
  }

  Future<void> _runSearch(String query) async {
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final encodedQuery = Uri.encodeQueryComponent(query);
    final currentFetchId = ++_searchFetchId;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _fetchMovies(baseUrl, encodedQuery),
        _fetchSeries(baseUrl, encodedQuery),
        _fetchPeople(baseUrl, encodedQuery),
      ]);

      if (!mounted || currentFetchId != _searchFetchId) return;

      final movies = results[0] as List<Movie>;
      final series = results[1] as List<Serie>;
      final people = results[2] as List<Person>;

      final anime = series.where((s) {
        final name = s.name.toLowerCase();
        final ov = s.overView.toLowerCase();
        return name.contains('anime') || ov.contains('anime') || ov.contains('japanese animation');
      }).toList();

      final asian = series.where((s) {
        final name = s.name.toLowerCase();
        final ov = s.overView.toLowerCase();
        return name.contains('drama') || name.contains('k-drama') || ov.contains('korean') || ov.contains('china');
      }).toList();

      final cartoons = series.where((s) {
        final name = s.name.toLowerCase();
        final ov = s.overView.toLowerCase();
        return name.contains('cartoon') || name.contains('animated') || ov.contains('animation');
      }).toList();

      setState(() {
        _isLoading = false;
        movieResults = movies;
        tvResults = series;
        animeResults = anime.isNotEmpty ? anime : series;
        asianDramaResults = asian.isNotEmpty ? asian : series;
        cartoonResults = cartoons.isNotEmpty ? cartoons : series;
        personResults = people;
      });

      _addToHistory(query);
    } catch (e) {
      if (!mounted || currentFetchId != _searchFetchId) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Search failed for "$query": $e');
    }
  }

  Future<List<Movie>> _fetchMovies(String baseUrl, String encodedQuery) async {
    final response = await apiClient.get(
      Uri.parse('${baseUrl}search/movie?api_key=$apiKey&query=$encodedQuery'),
    );
    if (response.statusCode != 200) throw Exception('Failed to load movie data');

    final List<Movie> movies = [];
    final List<dynamic> results = json.decode(response.body)['results'] ?? [];
    for (var result in results) {
      movies.add(Movie(
        title: result['title'] ?? '',
        releaseDate: result['release_date'] ?? '',
        posterPath: result['poster_path'] ?? '',
        overView: result['overview'] ?? '',
        id: result['id'] ?? 0,
        backdropPath: result['backdrop_path'] ?? '',
        score: (result['vote_average'] as num?)?.toDouble() ?? 0.0,
      ));
    }
    return movies;
  }

  Future<List<Serie>> _fetchSeries(String baseUrl, String encodedQuery) async {
    final response = await apiClient.get(
      Uri.parse('${baseUrl}search/tv?api_key=$apiKey&query=$encodedQuery'),
    );
    if (response.statusCode != 200) throw Exception('Failed to load serie data');

    final List<Serie> series = [];
    final List<dynamic> results = json.decode(response.body)['results'] ?? [];
    for (var result in results) {
      series.add(Serie(
        name: result['name'] ?? '',
        posterPath: result['poster_path'] ?? '',
        overView: result['overview'] ?? '',
        id: result['id'] ?? 0,
        backdropPath: result['backdrop_path'] ?? '',
        score: (result['vote_average'] as num?)?.toDouble() ?? 0.0,
      ));
    }
    return series;
  }

  Future<List<Person>> _fetchPeople(String baseUrl, String encodedQuery) async {
    final response = await apiClient.get(
      Uri.parse('${baseUrl}search/person?api_key=$apiKey&query=$encodedQuery'),
    );
    if (response.statusCode != 200) throw Exception('Failed to load people data');

    final List<Person> persons = [];
    final List<dynamic> results = json.decode(response.body)['results'] ?? [];
    for (var result in results) {
      persons.add(Person(
        name: result['name'] ?? '',
        profilePath: result['profile_path'] ?? '',
        id: result['id'] ?? 0,
        department: result['known_for_department'] ?? '',
      ));
    }
    return persons;
  }

  Widget _buildSearchHistoryList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),
            Text(
              'Search for movies, TV series, anime...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: BottomBar.getHeight(context) + 20,
      ),
      children: [
        ..._searchHistory.map((item) {
          return InkWell(
            onTap: () {
              _searchController.text = item;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: item.length),
              );
              _runSearch(item);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeHistoryItem(item),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Center(
          child: InkWell(
            onTap: _clearSearchHistory,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clear history',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 14),
          Text(
            "No results found for '$query'",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _buildSearchHistoryList();
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));

    final bool hasNoResults =
        movieResults.isEmpty && tvResults.isEmpty && personResults.isEmpty;
    if (hasNoResults) return _buildNoResultsState(query);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 12,
        bottom: BottomBar.getHeight(context) + 20,
      ),
      children: [
        // 1. Movies Shelf
        if (movieResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Movies',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    _tabController.animateTo(1); // Switch to Movies tab
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movieResults.length,
              itemBuilder: (context, index) {
                final movie = movieResults[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: TvFocusWrapper(
                    borderRadius: 16.0,
                    onTap: () => onTapMovie(movie.title, movie.id, context),
                    child: CustomMovieWidget(
                      movie: movie,
                      showAvailability: false,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. TV Series Shelf
        if (tvResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TV Series',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    _tabController.animateTo(2); // Switch to TV Series tab
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tvResults.length,
              itemBuilder: (context, index) {
                final serie = tvResults[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: TvFocusWrapper(
                    borderRadius: 16.0,
                    onTap: () => onTapSerie(serie.name, serie.id, context),
                    child: CustomSeriesWidget(
                      serie: serie,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 3. People Shelf
        if (personResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'People',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    _tabController.animateTo(6); // Switch to People tab
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: personResults.length,
              itemBuilder: (context, index) {
                final person = personResults[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: TvFocusWrapper(
                    borderRadius: 16.0,
                    onTap: () => person.department == 'Acting'
                        ? onTapCast(context, person.id)
                        : onTapCrew(context, person.id),
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFF1E1E1E),
                            backgroundImage: person.profilePath.isNotEmpty
                                ? NetworkImage('${getImageBaseUrl(Provider.of<RegionProvider>(context, listen: false).currentRegion)}/t/p/w185${person.profilePath}')
                                : null,
                            child: person.profilePath.isEmpty
                                ? const Icon(Icons.person_rounded, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
      ],
    );
  }

  Widget _buildMovieTab() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _buildSearchHistoryList();
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    if (movieResults.isEmpty) return _buildNoResultsState(query);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200
            ? 6
            : width > 900
                ? 5
                : width > 650
                    ? 4
                    : width > 400
                        ? 3
                        : 2;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: BottomBar.getHeight(context) + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: 0.58,
          ),
          itemCount: movieResults.length,
          itemBuilder: (context, index) {
            final movie = movieResults[index];
            return TvFocusWrapper(
              borderRadius: 16.0,
              onTap: () => onTapMovie(movie.title, movie.id, context),
              child: CustomMovieWidget(
                movie: movie,
                showAvailability: false,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTvTab(List<Serie> list) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _buildSearchHistoryList();
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    if (list.isEmpty) return _buildNoResultsState(query);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200
            ? 6
            : width > 900
                ? 5
                : width > 650
                    ? 4
                    : width > 400
                        ? 3
                        : 2;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: BottomBar.getHeight(context) + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: 0.58,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final serie = list[index];
            return TvFocusWrapper(
              borderRadius: 16.0,
              onTap: () => onTapSerie(serie.name, serie.id, context),
              child: CustomSeriesWidget(
                serie: serie,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeopleTab() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _buildSearchHistoryList();
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    if (personResults.isEmpty) return _buildNoResultsState(query);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200
            ? 6
            : width > 800
                ? 4
                : width > 600
                    ? 3
                    : 2;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: BottomBar.getHeight(context) + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: personResults.length,
          itemBuilder: (context, index) {
            final person = personResults[index];
            return TvFocusWrapper(
              borderRadius: 16.0,
              onTap: () => person.department == 'Acting'
                  ? onTapCast(context, person.id)
                  : onTapCrew(context, person.id),
              child: PersonSearchResult(
                person: person,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar Header (Voice Icon + Pill Search Bar Container)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  // Voice Mic Icon Button
                  IconButton(
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    splashRadius: 20,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),

                  // Pill Search Bar Container
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Theme(
                              data: theme.copyWith(
                                inputDecorationTheme: const InputDecorationTheme(
                                  filled: false,
                                  fillColor: Colors.transparent,
                                ),
                              ),
                              child: TextField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                autocorrect: false,
                                textAlignVertical: TextAlignVertical.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                cursorColor: Colors.white,
                                cursorWidth: 2,
                                decoration: const InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _addToHistory(val.trim());
                                  }
                                },
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _searchFetchId++;
                                setState(() {
                                  movieResults = [];
                                  tvResults = [];
                                  animeResults = [];
                                  asianDramaResults = [];
                                  cartoonResults = [];
                                  personResults = [];
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white60,
                                  size: 18,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              _tabController.animateTo(_tabs.indexOf('Discover'));
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Interactive Category Tabs (Horizontal Pill Selector with "All" option)
            SizedBox(
              height: 40,
              child: ListView.builder(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedTabIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                        _tabController.animateTo(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 18 : 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4C68FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // 3. Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildAllTab(),
                  _buildMovieTab(),
                  _buildTvTab(tvResults),
                  _buildTvTab(animeResults),
                  _buildTvTab(asianDramaResults),
                  _buildTvTab(cartoonResults),
                  _buildPeopleTab(),
                  DiscoverMoviesPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _categoryScrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
