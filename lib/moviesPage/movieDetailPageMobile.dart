part of 'movieDetailPage.dart';

class _MovieDetailPageMobile extends StatefulWidget {
  final _MovieDetailPageState state;

  const _MovieDetailPageMobile(this.state);

  @override
  State<_MovieDetailPageMobile> createState() => _MovieDetailPageMobileState();
}

class _MovieDetailPageMobileState extends State<_MovieDetailPageMobile> {
  String _watchStatus = 'None';

  @override
  void initState() {
    super.initState();
    _loadWatchStatus();
  }

  void _loadWatchStatus() {
    final status = WatchStatusManager.getStatus(widget.state.widget.movieId);
    setState(() {
      _watchStatus = status;
    });
  }

  Future<void> _openWatchStatusModal() async {
    final s = widget.state;
    final newStatus = await SetWatchStatusModal.show(
      context,
      tmdbId: s.widget.movieId,
      title: s.widget.movieTitle,
      type: 'movie',
      posterPath: s.posterPath,
      initialStatus: _watchStatus,
    );
    if (newStatus != null && mounted) {
      setState(() {
        _watchStatus = newStatus;
      });
    }
  }

  void _openWebLink(String? imdbId, int movieId) {
    final url = (imdbId != null && imdbId.isNotEmpty)
        ? 'https://www.imdb.com/title/$imdbId'
        : 'https://www.themoviedb.org/movie/$movieId';
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sWidget = state.widget;
    final moviedetails = state.moviedetails;
    final duration = state.duration;
    final releaseDate = state.releaseDate;
    final score = state.score;
    final backdrops = state.backdrops;
    final genres = state.genres;
    final about = state.about;
    final imdbId = state.imdbId;
    final creditsFuture = state._creditsFuture;
    final screenshotController = state.screenshotController;

    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final int? hours = duration != null ? duration ~/ 60 : null;
    final int? minutes = duration != null ? duration % 60 : null;
    final String year = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.substring(0, 4)
        : '';

    final topPadding = MediaQuery.paddingOf(context).top;

    if (moviedetails == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: M3ExpressiveSpinner()),
      );
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
                                child: const Icon(Icons.movie_outlined, size: 48),
                              ),
                            )
                          : Container(color: colorScheme.surfaceContainerLow),
                    ),
                    // Multi-stop gradient blend
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
                      // Large Bold Movie Title
                      Text(
                        sWidget.movieTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metadata Row (Provider Pill, Type, Year, Duration, Rating)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Removed Provider Badge Pill
                          Text(
                            'Movie',
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
                          if (hours != null && minutes != null) ...[
                            Text(
                              '•',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              '${hours}h ${minutes}m',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (score != null && score > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    score.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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

                      // Cast Section (Supports both circular avatar row & text-only fallback)
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
                            // Version with circular avatar portraits (Screenshot 2)
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildCastRow(castList, context),
                                const SizedBox(height: 12),
                              ],
                            );
                          } else {
                            // Version without cast portraits: clean text line (Screenshot 1)
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

                      // Main Action Buttons (Play Movie & Download)
                      // 1. Play Movie Button (Full width white pill)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TvFocusWrapper(
                          onTap: () => showWatchOptions(
                            context,
                            sWidget.movieId,
                            sWidget.movieTitle,
                            releaseDate ?? '',
                            imdbId ?? '',
                          ),
                          borderRadius: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Play Movie',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Download Button (Full width dark pill)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TvFocusWrapper(
                          onTap: () => showTorrentOptions(
                            context,
                            sWidget.movieId,
                            sWidget.movieTitle,
                            releaseDate,
                            imdbId,
                          ),
                          borderRadius: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_download_outlined, color: colorScheme.onSurface, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Download',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Director's Other Movies Section
                      ValueListenableBuilder<Future<dynamic>?>(
                        valueListenable: state.directorMoviesFuture,
                        builder: (context, directorMoviesFuture, _) {
                          if (directorMoviesFuture == null) return const SizedBox.shrink();

                          return FutureBuilder(
                            future: directorMoviesFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.hasError) return const SizedBox.shrink();
                              final List<dynamic> movies = snapshot.data as List<dynamic>;
                              if (movies.isEmpty) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'More Like This',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 250,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: movies.length,
                                      itemBuilder: (context, index) {
                                        final movie = movies[index];
                                        final movieModel = Movie(
                                          title: movie['title'] ?? '',
                                          releaseDate: movie['release_date'] ?? '',
                                          posterPath: movie['poster_path'] ?? '',
                                          overView: movie['overview'] ?? '',
                                          id: movie['id'] ?? 0,
                                          score: (movie['vote_average'] as num?)?.toDouble() ?? 0.0,
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 14),
                                          child: TvFocusWrapper(
                                            onTap: () => state.onTapMovie(movieModel.title, movieModel.id),
                                            child: CustomMovieWidget(
                                              movie: movieModel,
                                              showAvailability: false,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
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

                // Action Row: Cast, Favorite, Share, Globe, Search
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cast Button
                    IconButton(
                      icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 22),
                      tooltip: 'Cast to Device',
                      onPressed: () {},
                    ),
                    // Favorite Toggle Button
                    ValueListenableBuilder<bool?>(
                      valueListenable: state.isMovieFavorite,
                      builder: (context, isFavorite, _) {
                        final fav = isFavorite ?? false;
                        return IconButton(
                          icon: Icon(
                            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: fav ? Colors.redAccent : Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            if (state.isUserLoggedIn.value) {
                              state.isMovieFavorite.value = !fav;
                            } else {
                              state.isMovieFavorite.value = !fav;
                            }
                          },
                        );
                      },
                    ),
                    // Share Button
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                      tooltip: 'Share',
                      onPressed: () => ShareContent.shareMovie(sWidget.movieId),
                    ),
                    // Globe / IMDB Web Link Button
                    IconButton(
                      icon: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
                      tooltip: 'Open in Browser',
                      onPressed: () => _openWebLink(imdbId, sWidget.movieId),
                    ),
                    // Search Button
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
