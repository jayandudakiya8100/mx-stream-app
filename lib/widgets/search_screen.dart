import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:Mirarr/functions/fetchers/providers/global_provider_search_service.dart';
import 'package:Mirarr/functions/fetchers/providers/media_provider_service.dart';
import 'package:Mirarr/functions/fetchers/providers/vega_movies_provider.dart';
import 'package:Mirarr/homePage/widgets/provider_media_detail_page.dart';
import 'package:Mirarr/moviesPage/UI/gridview_forlists_movies.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    Key? key,
    this.initialQuery,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  StreamSubscription<ProviderSearchResultSection>? _searchSubscription;

  // Category filter state
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'All',
    'Movies',
    'TV Series',
    'Anime',
    'Asian Dramas',
  ];

  // Provider search results
  final Map<String, ProviderSearchResultSection> _providerResults = {};
  bool _isSearching = false;
  List<String> _searchHistory = [];
  Set<String> _enabledProviderIds = {};
  List<MediaProviderItem> _availableProviders = [];

  // Dummy cards for skeletonizer state
  final List<VegaMediaItem> _dummyItems = List.generate(
    5,
    (index) => VegaMediaItem(
      title: 'Loading Movie Title Placeholder',
      posterPath: '',
      permalink: '',
      id: index,
      score: 8.0,
    ),
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
    _loadSearchHistory();
    _loadAvailableProviders();

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialQuery!.trim();
        _executeGlobalSearch(widget.initialQuery!.trim());
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableProviders() async {
    final list = await MediaProviderService.fetchProviders();
    if (mounted) {
      setState(() {
        _availableProviders = list.where((p) => p.id != 'none' && p.id != 'random').toList();
        _enabledProviderIds = _availableProviders.map((p) => p.id.toLowerCase()).toSet();
      });
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
      }
    } catch (_) {}
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
      if (_searchHistory.length > 20) {
        _searchHistory = _searchHistory.sublist(0, 20);
      }
    });
    _saveSearchHistory();
  }

  void _onSearchInputChanged() {
    final query = _searchController.text.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      _searchSubscription?.cancel();
      setState(() {
        _isSearching = false;
        _providerResults.clear();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _executeGlobalSearch(query);
    });
  }

  void _executeGlobalSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    _addToHistory(cleanQuery);
    _searchSubscription?.cancel();

    setState(() {
      _isSearching = true;
      _providerResults.clear();
    });

    final targetIds = _enabledProviderIds.isNotEmpty ? _enabledProviderIds.toList() : null;

    _searchSubscription = GlobalProviderSearchService.searchAllProvidersStream(
      cleanQuery,
      selectedProviders: targetIds,
    ).listen(
      (section) {
        if (mounted && section.items.isNotEmpty) {
          setState(() {
            _providerResults[section.providerId] = section;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      },
    );
  }

  void _onTapMediaCard(VegaMediaItem item, String providerName) {
    Navigator.push(
      context,
      ExpressivePageRoute(
        page: ProviderMediaDetailPage(
          title: item.title,
          posterPath: item.posterPath,
          permalink: item.permalink,
          providerName: providerName,
        ),
      ),
    );
  }

  void _openProviderGrid(String providerName, List<VegaMediaItem> items) {
    if (items.isEmpty) return;
    Navigator.push(
      context,
      ExpressivePageRoute(
        page: ListGridViewMovies(
          movieList: items.map((e) => e.toMovie()).toList(),
          title: providerName,
        ),
      ),
    );
  }

  void _showProviderFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.sizeOf(context).height * 0.65,
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
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Providers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (_enabledProviderIds.length == _availableProviders.length) {
                              _enabledProviderIds.clear();
                            } else {
                              _enabledProviderIds = _availableProviders
                                  .map((p) => p.id.toLowerCase())
                                  .toSet();
                            }
                          });
                          setState(() {});
                        },
                        child: Text(
                          _enabledProviderIds.length == _availableProviders.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: const TextStyle(color: Color(0xFF3B5DF8), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _availableProviders.length,
                      itemBuilder: (context, index) {
                        final p = _availableProviders[index];
                        final isEnabled = _enabledProviderIds.contains(p.id.toLowerCase());

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF3B5DF8),
                          checkColor: Colors.white,
                          title: Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: p.url != null
                              ? Text(
                                  p.url!,
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                )
                              : null,
                          value: isEnabled,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _enabledProviderIds.add(p.id.toLowerCase());
                              } else {
                                _enabledProviderIds.remove(p.id.toLowerCase());
                              }
                            });
                            setState(() {});
                          },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = TvFocusModeManager.isTvDevice;
    final bottomInset = isTv ? 24.0 : BottomBar.getHeight(context) + 16;
    final query = _searchController.text.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 1. Search Bar Header
            _buildSearchBarHeader(context),

            const SizedBox(height: 10),
            // 2. Category Filter Chips Row
            _buildCategoryChipsRow(),

            // 3. Search Progress Indicator
            if (_isSearching)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B5DF8)),
                minHeight: 2,
              )
            else
              const SizedBox(height: 2),

            // 4. Body Content (Search History / Multi-Provider Results)
            Expanded(
              child: query.isEmpty
                  ? _buildSearchHistory()
                  : _buildMultiProviderResults(bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  // --- Search Bar Header ---
  Widget _buildSearchBarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Voice / Mic Icon
            const Icon(
              Icons.mic_none_rounded,
              color: Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 10),

            // Search Icon
            const Icon(
              Icons.search_rounded,
              color: Colors.white54,
              size: 21,
            ),
            const SizedBox(width: 10),

            // Input Field
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                cursorColor: const Color(0xFF4C68FF),
                decoration: const InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Search movies, series, anime...',
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
                textInputAction: TextInputAction.search,
                onSubmitted: (val) => _executeGlobalSearch(val),
              ),
            ),

            // Clear Button
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.transparent,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              ),

            // Filter Button
            GestureDetector(
              onTap: _showProviderFilterModal,
              child: Container(
                padding: const EdgeInsets.all(6),
                color: Colors.transparent,
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white70,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Category Chips Row ---
  Widget _buildCategoryChipsRow() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final title = _categories[index];

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(19),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4C68FF) : const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Multi-Provider Search Results Body ---
  Widget _buildMultiProviderResults(double bottomInset) {
    if (_providerResults.isEmpty && _isSearching) {
      // Loading skeleton state
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset, top: 12),
        itemCount: 3,
        itemBuilder: (context, index) {
          final dummyNames = ['VegaMovies', 'MoviesDrive', 'BollyFlix'];
          return _buildProviderSection(
            providerName: dummyNames[index],
            items: _dummyItems,
            isLoading: true,
          );
        },
      );
    }

    if (_providerResults.isEmpty && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No results found',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with a different movie or series name',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final sections = _providerResults.values.toList();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomInset, top: 8),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildProviderSection(
          providerName: section.providerName,
          items: section.items,
          isLoading: false,
        );
      },
    );
  }

  // --- Individual Provider Horizontal Section ---
  Widget _buildProviderSection({
    required String providerName,
    required List<VegaMediaItem> items,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                providerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => _openProviderGrid(providerName, items),
              ),
            ],
          ),
        ),

        // Horizontal Card Carousel with Edge Fade
        SizedBox(
          height: 230,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white, Colors.white, Colors.transparent],
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
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: isLoading
                      ? Skeletonizer(
                          enabled: true,
                          child: _buildMovieCard(item, providerName),
                        )
                      : TvFocusWrapper(
                          onTap: () => _onTapMediaCard(item, providerName),
                          child: _buildMovieCard(item, providerName),
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Single Movie Card Matching CloudStream Design ---
  Widget _buildMovieCard(VegaMediaItem item, String providerName) {
    return ExpressiveInteractiveContainer(
      onTap: () => _onTapMediaCard(item, providerName),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with Rounded Corners & Badge
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Container(
                    height: 170,
                    width: 120,
                    color: const Color(0xFF222222),
                    child: item.posterPath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.posterPath,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            errorWidget: (ctx, _, __) => const Center(
                              child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 32),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 32),
                          ),
                  ),

                  // Rating or Season Badge
                  if (item.episodeBadge != null || item.score > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.episodeBadge ?? '${item.score.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.episodeBadge == null) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.star, color: Colors.amber, size: 9),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Movie Title
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Search History & Suggestions ---
  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_rounded, size: 54, color: Colors.white12),
            SizedBox(height: 12),
            Text(
              'Search for movies, series, or anime',
              style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchHistory.clear();
                });
                _saveSearchHistory();
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _searchHistory.map((query) {
            return ActionChip(
              backgroundColor: const Color(0xFF1E1E1E),
              label: Text(query, style: const TextStyle(color: Colors.white, fontSize: 13)),
              avatar: const Icon(Icons.history, color: Colors.white38, size: 16),
              onPressed: () {
                _searchController.text = query;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: query.length),
                );
                _executeGlobalSearch(query);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
