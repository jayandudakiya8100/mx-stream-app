part of 'movieDetailPage.dart';

class _MovieDetailPageDesktop extends StatelessWidget {
  final _MovieDetailPageState state;

  const _MovieDetailPageDesktop(this.state);

  @override
  Widget build(BuildContext context) {
    final widget = state.widget;
    final moviedetails = state.moviedetails;
    final duration = state.duration;
    final releaseDate = state.releaseDate;
    final posterPath = state.posterPath;
    final score = state.score;
    final backdrops = state.backdrops;
    final genres = state.genres;
    final about = state.about;
    final budget = state.budget;
    final revenue = state.revenue;
    final productionCountries = state.productionCountries;
    final productionCompanies = state.productionCompanies;
    final spokenLanguages = state.spokenLanguages;
    final imdbId = state.imdbId;
    final availabilityFuture = state._availabilityFuture;
    final creditsFuture = state._creditsFuture;
    final language = state.language;

    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    int? hours = duration != null ? duration ~/ 60 : null;
    int? minutes = duration != null ? duration % 60 : null;
    String year = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.substring(0, 4)
        : 'NA';

    final bool isTv = TvFocusModeManager.isTvDevice;

    final Widget bodyContent = moviedetails == null
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              physics: const BouncingScrollPhysics(),
              scrollbars: true,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: isTv ? 0.0 : BottomBar.getHeight(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    RepaintBoundary(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(
                              '${getImageBaseUrl(region)}/t/p/w1280$backdrops',
                            ),
                            fit: BoxFit.cover,
                            opacity: 0.3,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CachedNetworkImage(
                                  imageUrl:
                                      '${getImageBaseUrl(region)}/t/p/w500$posterPath',
                                  memCacheWidth: 600,
                                  placeholder: (context, url) => Skeletonizer(
                                    enabled: true,
                                    containersColor: Colors.white.withOpacity(0.05),
                                    effect: ShimmerEffect(
                                      baseColor: Colors.white.withOpacity(0.05),
                                      highlightColor: Colors.white.withOpacity(0.15),
                                    ),
                                    child: Container(
                                      height: 800,
                                      width: 600,
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
                                    height: 800,
                                    width: 600,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(20)),
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: imageProvider,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 40),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.movieTitle,
                                          style: getMovieTitleTextStyle(widget.movieId),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              year,
                                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                                            ),
                                            if (hours != null) ...[
                                              const Text('•', style: TextStyle(color: Colors.white38, fontSize: 16)),
                                              Text(
                                                "${hours}H ${minutes}M",
                                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                            if (genres != null && (genres).isNotEmpty) ...[
                                              const Text('•', style: TextStyle(color: Colors.white38, fontSize: 16)),
                                              Text(
                                                (genres).map((g) => g['name']).join(', '),
                                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (score != null)
                                              _buildRatingBadge(
                                                label: 'TMDB',
                                                score: score.toStringAsFixed(1),
                                                icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                                context: context,
                                              ),
                                            ValueListenableBuilder<String?>(
                                              valueListenable: state.imdbRating,
                                              builder: (_, rating, __) {
                                                if (rating == null || rating.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                return _buildRatingBadge(
                                                  label: 'IMDb',
                                                  score: rating,
                                                  icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                                  context: context,
                                                );
                                              },
                                            ),
                                            ValueListenableBuilder<String>(
                                              valueListenable: state.rottenTomatoesRating,
                                              builder: (_, rating, __) {
                                                if (rating == 'N/A') {
                                                  return const SizedBox.shrink();
                                                }
                                                return _buildRatingBadge(
                                                  label: 'Rotten Tomatoes',
                                                  score: rating,
                                                  icon: const Text('🍅', style: TextStyle(fontSize: 14)),
                                                  context: context,
                                                );
                                              },
                                            ),
                                            AnimatedBuilder(
                                              animation: Listenable.merge([
                                                state.isUserLoggedIn,
                                                state.isMovieRated,
                                                state.userRating,
                                                state.isWatched,
                                              ]),
                                              builder: (context, _) {
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    MovieRatingButton(
                                                      movieId: widget.movieId,
                                                      isUserLoggedIn: state.isUserLoggedIn.value,
                                                      initialIsRated: state.isMovieRated.value,
                                                      initialUserRating: state.userRating.value,
                                                      isDesktop: true,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    MovieWatchedButton(
                                                      movieId: widget.movieId,
                                                      movieTitle: widget.movieTitle,
                                                      posterPath: posterPath,
                                                      userRating: state.userRating.value,
                                                      initialIsWatched: state.isWatched.value,
                                                      isDesktop: true,
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          spacing: 12,
                                          children: [
                                            _buildActionButton(
                                              icon: Icons.image_rounded,
                                              iconColor: Colors.white,
                                              tooltip: 'View Gallery',
                                              onTap: () {
                                                state._openGalleryOnDemand();
                                              },
                                            ),
                                            AnimatedBuilder(
                                              animation: Listenable.merge([
                                                state.isUserLoggedIn,
                                                state.isMovieWatchlist,
                                                state.isMovieFavorite,
                                              ]),
                                              builder: (context, _) {
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    MovieWatchlistButton(
                                                      movieId: widget.movieId,
                                                      initialIsWatchlist: state.isMovieWatchlist.value,
                                                      isUserLoggedIn: state.isUserLoggedIn.value,
                                                      isDesktop: true,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    MovieFavoriteButton(
                                                      movieId: widget.movieId,
                                                      initialIsFavorite: state.isMovieFavorite.value,
                                                      isUserLoggedIn: state.isUserLoggedIn.value,
                                                      isDesktop: true,
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: [
                                            FutureBuilder(
                                              future: availabilityFuture,
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError || snapshot.data != true) {
                                                  return const SizedBox();
                                                }
                                                return _buildPrimaryButton(
                                                  text: 'Watch',
                                                  backgroundColor: getMovieColor(context, widget.movieId),
                                                  textStyle: getMovieButtonTextStyle(widget.movieId),
                                                  icon: Icons.play_arrow_rounded,
                                                  onPressed: () => showWatchOptions(
                                                    context,
                                                    widget.movieId,
                                                    widget.movieTitle,
                                                    releaseDate ?? '',
                                                    imdbId ?? '',
                                                  ),
                                                );
                                              },
                                            ),
                                            _buildSecondaryButton(
                                              text: 'Torrent Search',
                                              textStyle: getMovieButtonTextStyle(widget.movieId),
                                              icon: Icons.search_rounded,
                                              onPressed: () => showTorrentOptions(
                                                context,
                                                widget.movieId,
                                                widget.movieTitle,
                                                releaseDate,
                                                imdbId,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (about != null && about.isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          const Text(
                                            'Overview',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 800),
                                            child: Text(
                                              about,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 16,
                                                height: 1.5,
                                                fontWeight: FontWeight.w300,
                                              ),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: [
                                            if (hours != null)
                                              _buildInfoCard(
                                                title: 'DURATION',
                                                value: "${hours}H ${minutes}M",
                                              ),
                                            _buildInfoCard(
                                              title: 'YEAR',
                                              value: year,
                                            ),
                                            _buildInfoCard(
                                              title: 'LANGUAGE',
                                              value: language != null ? language.toUpperCase() : 'N/A',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    FutureBuilder(
                      future: creditsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return buildCastCrewSkeletonRow(isDesktop: true);
                        } else if (snapshot.hasError) {
                          return const Text(
                              'Error loading cast and crew details');
                        } else {
                          final Map<String, List<Map<String, dynamic>>> data =
                              snapshot.data
                                  as Map<String, List<Map<String, dynamic>>>;
                          final List<Map<String, dynamic>> castList =
                              data['cast'] ?? [];
                          final List<Map<String, dynamic>> crewList =
                              data['crew'] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (castList.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                      child: Text(
                                        'Cast',
                                        textAlign: TextAlign.justify,
                                        style: getMovieTitleTextStyle(
                                            widget.movieId),
                                      ),
                                    )
                                  ],
                                ),
                                const CustomDivider(),
                                buildCastRowDesktop(castList, context),
                              ],
                              if (crewList.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                      child: Text(
                                        'Crew',
                                        textAlign: TextAlign.justify,
                                        style: getMovieTitleTextStyle(
                                            widget.movieId),
                                      ),
                                    ),
                                  ],
                                ),
                                const CustomDivider(),
                                buildCrewRowDesktop(crewList, context),
                              ],
                            ],
                          );
                        }
                      },
                    ),
                    const CustomDivider(),
                    if (state.directorName != null)
                      Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(25, 10, 0, 0),
                              child: Text("Movies by ${state.directorName}",
                                  style: getMovieTitleTextStyle(
                                      widget.movieId)),
                            ),
                          ),
                          ValueListenableBuilder<Future<dynamic>?>(
                            valueListenable: state.directorMoviesFuture,
                            builder: (context, directorMoviesFuture, _) {
                              if (directorMoviesFuture == null) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return FutureBuilder(
                                future: directorMoviesFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return const Text(
                                        'Error loading other movies');
                                  } else {
                                    List<dynamic> movies =
                                        snapshot.data as List<dynamic>;

                                    return SizedBox(
                                      height: 360,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemExtent: 216,
                                        itemCount: movies.length,
                                        itemBuilder: (context, index) {
                                          final movie = movies[index];
                                          return Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                children: [
                                                  Card(
                                                    elevation: 4,
                                                    child: GestureDetector(
                                                      onTap: () => state.onTapMovie(
                                                          movie['title'],
                                                          movie['id']),
                                                      child: SizedBox(
                                                        height: 300,
                                                        width: 200,
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(20),
                                                          child: movie['poster_path'].isNotEmpty
                                                              ? CachedNetworkImage(
                                                                  imageUrl: '${getImageBaseUrl(region)}/t/p/w200${movie['poster_path']}',
                                                                  fit: BoxFit.cover,
                                                                  placeholder: (context, url) => Skeletonizer(
                                                                    enabled: true,
                                                                    containersColor: Colors.white.withOpacity(0.05),
                                                                    effect: ShimmerEffect(
                                                                      baseColor: Colors.white.withOpacity(0.05),
                                                                      highlightColor: Colors.white.withOpacity(0.15),
                                                                    ),
                                                                    child: Container(
                                                                      color: Colors.grey[900],
                                                                    ),
                                                                  ),
                                                                  errorWidget: (context, url, error) => Container(
                                                                    color: Colors.grey[900],
                                                                    child: const Icon(Icons.error),
                                                                  ),
                                                                )
                                                              : Container(
                                                                  color: Colors.grey[900],
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 140,
                                                    child: Text(
                                                      movie['title'],
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      softWrap: true,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ));
                                        },
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    const CustomDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      child: Container(
                        alignment: Alignment.center,
                        child: ExpansionTile(
                          collapsedIconColor: Theme.of(context).primaryColor,
                          title: Text('Other Info',
                              style: getMovieTitleTextStyle(widget.movieId)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      budget != null && budget != 0
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Budget',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      color: Theme.of(context)
                                                          .primaryColor),
                                                ),
                                                Text(
                                                  '\$${NumberFormat("#,##0").format(budget)}',
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                      const CustomDivider(),
                                      revenue != null && revenue != 0
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Revenue',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      color: Theme.of(context)
                                                          .primaryColor),
                                                ),
                                                Text(
                                                  '\$${NumberFormat("#,##0").format(revenue)}',
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white),
                                                ),
                                              ],
                                            )
                                          : Container(),
                                      const CustomDivider(),
                                      Text(
                                        'Production Countries',
                                        style: TextStyle(
                                            fontSize: 18,
                                            color:
                                                Theme.of(context).primaryColor),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: (productionCountries
                                                as List<dynamic>)
                                            .map<Widget>((productionCountry) {
                                          return Text(
                                            productionCountry['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w200,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const CustomDivider(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Production Companies',
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: Theme.of(context)
                                                    .primaryColor),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: (productionCompanies
                                                    as List<dynamic>)
                                                .map<Widget>(
                                                    (productionCompany) {
                                              return Text(
                                                productionCompany['name'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w200,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                      const CustomDivider(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Spoken Languages',
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: Theme.of(context)
                                                    .primaryColor),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: (spokenLanguages
                                                    as List<dynamic>)
                                                .map<Widget>((spokenLanguage) {
                                              return Text(
                                                spokenLanguage['name'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w200,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
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
                  ],
                ),
              ),
            );

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: getMovieColor(context, widget.movieId),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
            child: Text(
              widget.movieTitle,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: isTv
          ? Column(
              children: [
                const BottomBar(),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
      bottomNavigationBar: isTv ? null : const BottomBar(),
    );
  }

  Widget _buildRatingBadge({
    required String label,
    required String score,
    required Widget icon,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label.isNotEmpty ? "$label $score" : score,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: TvFocusWrapper(
        borderRadius: 23.0,
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor != Colors.white
                ? iconColor.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: iconColor != Colors.white
                  ? iconColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required Color backgroundColor,
    required TextStyle textStyle,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textStyle.color, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: textStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required TextStyle textStyle,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
