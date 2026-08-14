part of 'movieDetailPage.dart';

class _MovieDetailPageMobile extends StatelessWidget {
  final _MovieDetailPageState state;

  const _MovieDetailPageMobile(this.state);

  @override
  Widget build(BuildContext context) {
    final widget = state.widget;
    final moviedetails = state.moviedetails;
    final duration = state.duration;
    final releaseDate = state.releaseDate;
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
    final screenshotController = state.screenshotController;
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
        ? const M3ExpressiveSpinner()
        : SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: isTv ? 0.0 : BottomBar.getHeight(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Stack(
                      children: [
                        TvFocusWrapper(
                          onTap: () {
                            state._openGalleryOnDemand();
                          },
                          child: Stack(
                            children: [
                              RepaintBoundary(
                                child: CachedNetworkImage(
                                imageUrl:
                                    '${getImageBaseUrl(region)}/t/p/w780$backdrops',
                                memCacheWidth: 780,
                                placeholder: (context, url) => Skeletonizer(
                                  enabled: true,
                                  containersColor: Colors.white.withOpacity(0.05),
                                  effect: ShimmerEffect(
                                    baseColor: Colors.white.withOpacity(0.05),
                                    highlightColor: Colors.white.withOpacity(0.15),
                                  ),
                                  child: Container(
                                    height: 300,
                                    width: double.infinity,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                                imageBuilder: (context, imageProvider) => Container(
                                  height: 300,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      fit: BoxFit.cover,
                                      image: imageProvider,
                                    ),
                                  ),
                                ),
                              ),
                              ),
                              Container(
                                height: 320,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black, Colors.transparent],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 70,
                          left: 10,
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                                color: Colors.black38,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(30))),
                            child: Text(
                              'TMDB⭐ ${score?.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: state.imdbRating,
                          builder: (_, rating, __) => Visibility(
                            visible: rating != null && rating.isNotEmpty,
                            child: Positioned(
                              bottom: 70,
                              left: 110,
                              child: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30))),
                                child: Text(
                                  'IMDB⭐ $rating',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w300,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: state.rottenTomatoesRating,
                          builder: (_, rating, __) => Visibility(
                            visible: rating != 'N/A',
                            child: Positioned(
                              bottom: 70,
                              left: 210,
                              child: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30))),
                                child: Text(
                                  'Rotten Tomatoes🍅 $rating',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w300,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 28,
                          left: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20)),
                                ),
                                width: MediaQuery.sizeOf(context).width - 20,
                                child: Text(
                                  widget.movieTitle,
                                  softWrap: true,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: getMovieTitleTextStyle(widget.movieId),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (AppPlatform.isAndroid)
                          Positioned(
                            top: 190,
                            right: 24,
                            child: Builder(
                              builder: (buttonContext) {
                                return _buildM3FloatingActionButton(
                                  context: context,
                                  onTap: () {
                                    final RenderBox button = buttonContext
                                        .findRenderObject() as RenderBox;
                                    final RenderBox overlay =
                                        Overlay.of(context)
                                            .context
                                            .findRenderObject() as RenderBox;
                                    final RelativeRect position =
                                        RelativeRect.fromRect(
                                      Rect.fromPoints(
                                        button.localToGlobal(Offset.zero,
                                            ancestor: overlay),
                                        button.localToGlobal(
                                            button.size
                                                .bottomRight(Offset.zero),
                                            ancestor: overlay),
                                      ),
                                      Offset.zero & overlay.size,
                                    );

                                    showMenu<String>(
                                      context: context,
                                      position: position,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      items: [
                                        PopupMenuItem<String>(
                                          value: 'cover',
                                          onTap: () {
                                            ShareContent.sharePartialScreenshot(
                                              screenshotController,
                                              _buildScreenShotImage(context),
                                              widget.movieId,
                                            );
                                          },
                                          child: const Row(
                                            children: [
                                              Icon(Icons.image_rounded,
                                                  size: 20),
                                              SizedBox(width: 12),
                                              Text('Cover Art'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'tmdb',
                                          onTap: () {
                                            ShareContent.shareMovie(
                                                widget.movieId);
                                          },
                                          child: const Row(
                                            children: [
                                              Icon(Icons.movie_outlined,
                                                  size: 20),
                                              SizedBox(width: 12),
                                              Text('TMDB Link'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'mirarr',
                                          onTap: () {
                                            ShareContent.shareMirarrWebMovie(
                                                widget.movieId);
                                          },
                                          child: const Row(
                                            children: [
                                              Icon(Icons.language_rounded,
                                                  size: 20),
                                              SizedBox(width: 12),
                                              Text('Mirarr WebApp Link'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  child: const Icon(
                                    Icons.share_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                );
                              },
                            ),
                          ),

                        // Positioned.fill gives this Stack bounded constraints
                        // (non-positioned Stack-of-Positioneds breaks in scroll views).
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            state.isUserLoggedIn,
                            state.isMovieWatchlist,
                            state.isMovieFavorite,
                            state.isMovieRated,
                            state.userRating,
                            state.isWatched,
                          ]),
                          builder: (context, _) {
                            final loggedIn = state.isUserLoggedIn.value;
                            return Positioned.fill(
                              child: Stack(
                                children: [
                                  if (loggedIn)
                                    Positioned(
                                      top: 140,
                                      right: 24,
                                      child: MovieWatchlistButton(
                                        movieId: widget.movieId,
                                        initialIsWatchlist:
                                            state.isMovieWatchlist.value,
                                        isUserLoggedIn: loggedIn,
                                        isDesktop: false,
                                      ),
                                    ),
                                  if (loggedIn)
                                    Positioned(
                                      top: 90,
                                      right: 24,
                                      child: MovieFavoriteButton(
                                        movieId: widget.movieId,
                                        initialIsFavorite:
                                            state.isMovieFavorite.value,
                                        isUserLoggedIn: loggedIn,
                                        isDesktop: false,
                                      ),
                                    ),
                                  Positioned(
                                    top: 40,
                                    left: 20,
                                    child: MovieWatchedButton(
                                      movieId: widget.movieId,
                                      movieTitle: widget.movieTitle,
                                      posterPath: state.posterPath,
                                      userRating: state.userRating.value,
                                      initialIsWatched: state.isWatched.value,
                                      isDesktop: false,
                                    ),
                                  ),
                                  if (loggedIn)
                                    Positioned(
                                      top: 40,
                                      right: 24,
                                      child: MovieRatingButton(
                                        movieId: widget.movieId,
                                        isUserLoggedIn: loggedIn,
                                        initialIsRated:
                                            state.isMovieRated.value,
                                        initialUserRating:
                                            state.userRating.value,
                                        isDesktop: false,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: (genres as List<dynamic>).map<Widget>((genre) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              genre['name'].toString(),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        about ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Duration',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${hours}H ${minutes}M",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Year',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  year,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Language',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  language != null ? language.toUpperCase() : 'N/A',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        FutureBuilder(
                          future: availabilityFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return const SizedBox();
                            } else {
                              return snapshot.data == true
                                  ? Container(
                                      width: double.infinity,
                                      height: 56,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: FilledButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: getMovieColor(context, widget.movieId),
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shadowColor: getMovieColor(context, widget.movieId).withValues(alpha: 0.4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(28),
                                          ),
                                        ),
                                        onPressed: () => showWatchOptions(
                                          context,
                                          widget.movieId,
                                          widget.movieTitle,
                                          releaseDate ?? '',
                                          imdbId ?? '',
                                        ),
                                        label: Text(
                                          'Watch',
                                          style: getMovieButtonTextStyle(widget.movieId).copyWith(fontSize: 16),
                                        ),
                                      ),
                                    )
                                  : const SizedBox();
                            }
                          },
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 22),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: () => showTorrentOptions(
                              context,
                              widget.movieId,
                              widget.movieTitle,
                              releaseDate,
                              imdbId,
                            ),
                            label: Text(
                              'Torrent Search',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder(
                    future: creditsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return buildCastCrewSkeletonRow(isDesktop: false);
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
                                        const EdgeInsets.fromLTRB(25, 15, 0, 0),
                                    child: Text(
                                      'Cast',
                                      textAlign: TextAlign.justify,
                                      style:
                                          getMovieTitleTextStyle(widget.movieId),
                                    ),
                                  ),
                                ],
                              ),
                              const CustomDivider(),
                              buildCastRow(castList, context),
                            ],
                            if (crewList.isNotEmpty) ...[
                              Row(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(25, 15, 0, 0),
                                    child: Text(
                                      'Crew',
                                      textAlign: TextAlign.justify,
                                      style:
                                          getMovieTitleTextStyle(widget.movieId),
                                    ),
                                  ),
                                ],
                              ),
                              const CustomDivider(),
                              buildCrewRow(crewList, context),
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
                                const EdgeInsets.fromLTRB(25, 15, 10, 0),
                            child: Text(
                              "Movies by ${state.directorName}",
                              style:
                                  getMovieTitleTextStyle(widget.movieId),
                            ),
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
                                    height: 250,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemExtent: 116,
                                      itemCount: movies.length,
                                      itemBuilder: (context, index) {
                                        final movie = movies[index];
                                        return Padding(
                                            padding:
                                                const EdgeInsets.all(8.0),
                                            child: Column(
                                              children: [
                                                TvFocusWrapper(
                                                   onTap: () => state.onTapMovie(
                                                       movie['title'],
                                                       movie['id']),
                                                   child: Card(
                                                     child: SizedBox(
                                                        height: 200,
                                                        width: 100,
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
                                                  width: 70,
                                                  child: Text(
                                                    movie['title'],
                                                    textAlign:
                                                        TextAlign.center,
                                                    maxLines: 2,
                                                    softWrap: true,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 10,
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
                        title: Text(
                          'Other Info',
                          style: getMovieTitleTextStyle(widget.movieId),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      children:
                                          (productionCountries as List<dynamic>)
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
                                              .map<Widget>((productionCompany) {
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
            );

    return Scaffold(
      extendBody: true,
      //only show appbar on ios and web
      appBar: AppPlatform.isIOS || AppPlatform.isWeb ?
      AppBar(
        automaticallyImplyLeading: true,
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
      )
      : null,
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

  Widget _buildScreenShotImage(BuildContext context) {
    final widget = state.widget;
    final duration = state.duration;
    final releaseDate = state.releaseDate;
    final backdrops = state.backdrops;
    final genres = state.genres;
    final about = state.about;

    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

    int? hours = duration != null ? duration ~/ 60 : null;
    int? minutes = duration != null ? duration % 60 : null;
    String year = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.substring(0, 4)
        : 'NA';

    return Container(
      constraints: const BoxConstraints(maxHeight: 800),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
        color: Colors.black,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(children: [
            CachedNetworkImage(
              imageUrl: '${getImageBaseUrl(region)}/t/p/w1280$backdrops',
              memCacheWidth: 1280,
              maxWidthDiskCache: 1280,
              placeholder: (context, url) => Skeletonizer(
                enabled: true,
                containersColor: Colors.white.withOpacity(0.05),
                effect: ShimmerEffect(
                  baseColor: Colors.white.withOpacity(0.05),
                  highlightColor: Colors.white.withOpacity(0.15),
                ),
                child: Container(
                  height: 300,
                  width: double.infinity,
                  color: Colors.grey[900],
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              imageBuilder: (context, imageProvider) => Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: imageProvider,
                  ),
                ),
              ),
            ),
            Container(
              height: 320,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    width: MediaQuery.sizeOf(context).width - 20,
                    child: Text(
                      widget.movieTitle,
                      softWrap: true,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: (genres as List<dynamic>).map<Widget>((genre) {
                return Text(
                  genre['name'] + ' | ',
                  softWrap: true,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'RobotoMono'),
                );
              }).toList(),
            ),
          ),
          const CustomDivider(),
          Container(
            alignment: Alignment.center,
            child: Text(
              about!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w200,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.left,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const CustomDivider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(
                width: 110,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                  decoration: BoxDecoration(
                    color: getMovieBackgroundColor(context, widget.movieId),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w200,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "${hours}H ${minutes}M",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                  decoration: BoxDecoration(
                    color: getMovieBackgroundColor(context, widget.movieId),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Year',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w200,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          year,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                  decoration: BoxDecoration(
                    color: getMovieBackgroundColor(context, widget.movieId),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Language',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w200,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          state.language != null ? state.language!.toUpperCase() : 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
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
    );
  }

  Widget _buildM3FloatingActionButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultBg = colorScheme.surfaceContainerHigh.withValues(alpha: 0.85);
    final defaultBorder = colorScheme.outlineVariant.withValues(alpha: 0.3);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? defaultBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TvFocusWrapper(
        borderRadius: 23.0,
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}
