part of 'serieDetailPage.dart';

class _SerieDetailPageMobile extends StatefulWidget {
  final _SerieDetailPageState state;

  const _SerieDetailPageMobile(this.state);

  @override
  State<_SerieDetailPageMobile> createState() => _SerieDetailPageMobileState();
}

class _SerieDetailPageMobileState extends State<_SerieDetailPageMobile> {
  String _watchStatus = 'None';
  int _selectedSeasonNumber = 1;
  bool _sortAscending = true;
  List<dynamic> _seasonEpisodes = [];
  bool _isLoadingSeason = false;
  bool _initialSeasonLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWatchStatus();
    _loadInitialSeason();
  }

  @override
  void didUpdateWidget(covariant _SerieDetailPageMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialSeasonLoaded && widget.state.seasonsList != null) {
      _loadInitialSeason();
    }
  }

  void _loadWatchStatus() {
    final status = WatchStatusManager.getStatus(widget.state.widget.serieId);
    setState(() {
      _watchStatus = status;
    });
  }

  void _loadInitialSeason() {
    final seasons = widget.state.seasonsList;
    if (seasons != null && seasons.isNotEmpty) {
      _initialSeasonLoaded = true;
      final firstValid = seasons.firstWhere(
        (s) => s['season_number'] != 0,
        orElse: () => seasons.first,
      );
      _fetchSeasonDetails(firstValid['season_number'] ?? 1);
    }
  }

  Future<void> _fetchSeasonDetails(int seasonNum) async {
    setState(() {
      _selectedSeasonNumber = seasonNum;
      _isLoadingSeason = true;
    });

    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final apiKey = widget.state.apiKey;

    try {
      final response = await apiClient.get(
        Uri.parse('${baseUrl}tv/${widget.state.widget.serieId}/season/$seasonNum?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _seasonEpisodes = data['episodes'] ?? [];
            _isLoadingSeason = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSeason = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  Future<void> _openWatchStatusModal() async {
    final s = widget.state;
    final newStatus = await SetWatchStatusModal.show(
      context,
      tmdbId: s.widget.serieId,
      title: s.widget.serieName,
      type: 'tv',
      posterPath: s.posterPath,
      initialStatus: _watchStatus,
    );
    if (newStatus != null && mounted) {
      setState(() {
        _watchStatus = newStatus;
      });
    }
  }

  void _openWebLink(String? imdbId, int serieId) {
    final url = (imdbId != null && imdbId.isNotEmpty)
        ? 'https://www.imdb.com/title/$imdbId'
        : 'https://www.themoviedb.org/tv/$serieId';
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sWidget = state.widget;
    final serieDetails = state.serieDetails;
    final backdrops = state.backdrops;
    final score = state.score;
    final genres = state.genres;
    final about = state.about;
    final releaseDate = state.releaseDate;
    final seasonsList = state.seasonsList;
    final imdbId = state.imdbId;
    final creditsFuture = state._creditsFuture;

    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final String year = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.substring(0, 4)
        : '';
    final topPadding = MediaQuery.paddingOf(context).top;

    if (serieDetails == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: M3ExpressiveSpinner()),
      );
    }

    final episodesToDisplay = List<dynamic>.from(_seasonEpisodes);
    if (!_sortAscending) {
      episodesToDisplay.sort((a, b) => (b['episode_number'] ?? 0).compareTo(a['episode_number'] ?? 0));
    } else {
      episodesToDisplay.sort((a, b) => (a['episode_number'] ?? 0).compareTo(b['episode_number'] ?? 0));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Scrollable Content Body
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-Bleed Backdrop Banner with Multi-Stop Gradient
                Stack(
                  children: [
                    SizedBox(
                      height: 360,
                      width: double.infinity,
                      child: backdrops != null && backdrops.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: '${getImageBaseUrl(region)}/t/p/w780$backdrops',
                              memCacheWidth: 780,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerLow,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerLow,
                                child: const Icon(Icons.tv_outlined, size: 48),
                              ),
                            )
                          : Container(color: colorScheme.surfaceContainerLow),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                              colorScheme.surface,
                            ],
                            stops: const [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Content Details Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Bold Series Title
                      Text(
                        sWidget.serieName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metadata Row (Provider Pill, Rating Pill, Type, Year)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Provider Badge Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'CineStream',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (imdbId != null && imdbId.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'IMDB',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Text(
                            'Series',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (year.isNotEmpty) ...[
                            Text(
                              '•',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              year,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (score != null && score > 0) ...[
                            Text(
                              '•',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              '${score.toStringAsFixed(1)}/10.0',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Overview / Plot Summary
                      if (about != null && about.isNotEmpty)
                        Text(
                          about,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                            fontSize: 13.5,
                            height: 1.45,
                            letterSpacing: 0.1,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Cast Section (Supports both circular avatar row & text fallback)
                      FutureBuilder(
                        future: creditsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return buildCastCrewSkeletonRow(isDesktop: false);
                          }
                          if (!snapshot.hasData || snapshot.hasError) {
                            return const SizedBox.shrink();
                          }
                          final Map<String, List<Map<String, dynamic>>> data =
                              snapshot.data as Map<String, List<Map<String, dynamic>>>;
                          final List<Map<String, dynamic>> castList = data['cast'] ?? [];

                          if (castList.isEmpty) return const SizedBox.shrink();

                          final bool hasProfilePhotos = castList.any(
                            (c) => c['profile_path'] != null && c['profile_path'].toString().isNotEmpty,
                          );

                          if (hasProfilePhotos) {
                            // Circular Cast Avatars (Screenshot 4)
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildCastRow(castList, context),
                                const SizedBox(height: 12),
                              ],
                            );
                          } else {
                            // Text Fallback (Screenshot 3)
                            final castNames = castList.take(4).map((c) => c['name']).join(', ');
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cast: $castNames',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            );
                          }
                        },
                      ),

                      // Genre Pills Row
                      if (genres != null && (genres as List).isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (genres as List<dynamic>).map<Widget>((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                genre['name'].toString(),
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Season & Episode Controls Header
                      Row(
                        children: [
                          // Season Selector Dropdown Pill
                          if (seasonsList != null && seasonsList.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedSeasonNumber,
                                  dropdownColor: colorScheme.surfaceContainerHigh,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  items: (seasonsList as List<dynamic>).map<DropdownMenuItem<int>>((s) {
                                    final sNum = s['season_number'] ?? 1;
                                    final sName = s['name'] ?? 'Season $sNum';
                                    return DropdownMenuItem<int>(
                                      value: sNum,
                                      child: Text(sName),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null && val != _selectedSeasonNumber) {
                                      _fetchSeasonDetails(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),

                          // Sort Order Button Pill (Ep ↑ / Ep ↓)
                          TvFocusWrapper(
                            onTap: () {
                              setState(() {
                                _sortAscending = !_sortAscending;
                              });
                            },
                            borderRadius: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _sortAscending ? 'Ep ↑' : 'Ep ↓',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Episode Count Indicator
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_download_outlined,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${episodesToDisplay.length} Episodes',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Episode List Cards
                      if (_isLoadingSeason)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: M3ExpressiveSpinner()),
                        )
                      else if (episodesToDisplay.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No episodes found for this season.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: episodesToDisplay.length,
                          itemBuilder: (context, index) {
                            final ep = episodesToDisplay[index];
                            final epNum = ep['episode_number'] ?? (index + 1);
                            final epName = ep['name'] ?? 'Episode $epNum';
                            final epOverview = ep['overview'] ?? '';
                            final epAirDate = ep['air_date'] ?? '';
                            final stillPath = ep['still_path'];
                            final stillUrl = stillPath != null
                                ? '${getImageBaseUrl(region)}/t/p/w300$stillPath'
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TvFocusWrapper(
                                onTap: () => showWatchOptions(
                                  context,
                                  sWidget.serieId,
                                  _selectedSeasonNumber,
                                  epNum,
                                  imdbId ?? '',
                                ),
                                borderRadius: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Thumbnail with Play Button Overlay
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  width: 120,
                                                  height: 72,
                                                  color: colorScheme.surfaceContainerHigh,
                                                  child: stillUrl != null
                                                      ? CachedNetworkImage(
                                                          imageUrl: stillUrl,
                                                          memCacheWidth: 240,
                                                          fit: BoxFit.cover,
                                                          placeholder: (context, url) => Container(
                                                            color: colorScheme.surfaceContainerHigh,
                                                          ),
                                                          errorWidget: (context, url, error) => Container(
                                                            color: colorScheme.surfaceContainerHigh,
                                                            child: const Icon(Icons.tv_outlined, size: 28),
                                                          ),
                                                        )
                                                      : const Icon(Icons.tv_outlined, size: 28),
                                                ),
                                              ),
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),

                                          // Episode Title & Air Date
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$epNum. $epName',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colorScheme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                if (epAirDate.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    epAirDate,
                                                    style: TextStyle(
                                                      color: colorScheme.onSurfaceVariant,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // Download Button on the right
                                          IconButton(
                                            icon: Icon(
                                              Icons.file_download_outlined,
                                              color: colorScheme.onSurfaceVariant,
                                              size: 22,
                                            ),
                                            tooltip: 'Download Episode',
                                            onPressed: () => showTorrentOptions(
                                              context,
                                              sWidget.serieName,
                                              sWidget.serieId,
                                              _selectedSeasonNumber,
                                              epNum,
                                              imdbId,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Episode Summary Text Below
                                      if (epOverview.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          epOverview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 80), // Padding to prevent overlap with floating button
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Top Navigation Header
          Positioned(
            top: topPadding + 4,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),

                // Action Row: Cast, Notification/Bell, Favorite, Share, Search
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 22),
                      tooltip: 'Cast',
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                      tooltip: 'Notifications',
                      onPressed: () {},
                    ),
                    ValueListenableBuilder<bool?>(
                      valueListenable: state.isSerieFavorite,
                      builder: (context, isFavorite, _) {
                        final fav = isFavorite ?? false;
                        return IconButton(
                          icon: Icon(
                            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: fav ? Colors.redAccent : Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            state.isSerieFavorite.value = !fav;
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                      tooltip: 'Share',
                      onPressed: () => ShareContent.shareTVShow(sWidget.serieId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
                      tooltip: 'Open in Browser',
                      onPressed: () => _openWebLink(imdbId, sWidget.serieId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                      tooltip: 'Search',
                      onPressed: () {
                        final nav = Provider.of<NavigationProvider>(context, listen: false);
                        Navigator.pop(context);
                        nav.setIndex(1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Watch Status Pill (Bottom Right Corner)
          Positioned(
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: TvFocusWrapper(
              onTap: _openWatchStatusModal,
              borderRadius: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_rounded,
                      color: colorScheme.onSurface,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _watchStatus,
                      style: TextStyle(
                        color: colorScheme.onSurface,
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
      ),
    );
  }
}
