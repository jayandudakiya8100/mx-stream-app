part of 'serieDetailPage.dart';

class _SerieDetailPageMobile extends StatelessWidget {
  final _SerieDetailPageState state;

  const _SerieDetailPageMobile(this.state);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final widget = state.widget;
    final serieDetails = state.serieDetails;
    final backdrops = state.backdrops;
    final posterPath = state.posterPath;
    final score = state.score;
    final genres = state.genres;
    final about = state.about;
    final seasons = state.seasons;
    final episodes = state.episodes;
    final language = state.language;
    final imdbId = state.imdbId;
    final creditsFuture = state._creditsFuture;
    final showWatchToggleKey = state._showWatchToggleKey;
    final screenShotController = state.screenShotController;

    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

    final bool isTv = TvFocusModeManager.isTvDevice;

    final Widget bodyContent = serieDetails == null
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
                          errorWidget: (context, url, error) => const Icon(Icons
                              .error), // Widget to display when there's an error loading the image.
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
                              fontSize: 13,
                              color: Colors
                                  .white, // Text color on top of the image
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: state.imdbRating,
                        builder: (_, rating, __) => Visibility(
                          visible: rating != null &&
                              rating.isNotEmpty &&
                              rating != 'N/A',
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
                                  fontSize: 13,
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
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
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
                                widget.serieName,
                                softWrap: true,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: getSeriesTitleTextStyle(widget.serieId),
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
                                  final RenderBox overlay = Overlay.of(context)
                                      .context
                                      .findRenderObject() as RenderBox;
                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                    Rect.fromPoints(
                                      button.localToGlobal(Offset.zero,
                                          ancestor: overlay),
                                      button.localToGlobal(
                                          button.size.bottomRight(Offset.zero),
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
                                          ShareContent.sharePartialScreenshotTV(
                                            screenShotController,
                                            _buildScreenShotImage(context),
                                            widget.serieId,
                                          );
                                        },
                                        child: const Row(
                                          children: [
                                            Icon(Icons.image_rounded, size: 20),
                                            SizedBox(width: 12),
                                            Text('Cover Art'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'tmdb',
                                        onTap: () {
                                          ShareContent.shareTVShow(
                                              widget.serieId);
                                        },
                                        child: const Row(
                                          children: [
                                            Icon(Icons.tv_rounded, size: 20),
                                            SizedBox(width: 12),
                                            Text('TMDB Link'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'mirarr',
                                        onTap: () {
                                          ShareContent.shareMirarrWebTVShow(
                                              widget.serieId);
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
                      // when logged-in action buttons are present.
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          state.isUserLoggedIn,
                          state.isSerieWatchlist,
                          state.isSerieFavorite,
                          state.isSerieRated,
                          state.userRating,
                        ]),
                        builder: (context, _) {
                          final loggedIn = state.isUserLoggedIn.value;
                          final isSerieWatchlist = state.isSerieWatchlist.value;
                          final isSerieFavorite = state.isSerieFavorite.value;
                          final isSerieRated = state.isSerieRated.value;
                          final userRating = state.userRating.value;
                          return Positioned.fill(
                            child: Stack(
                            children: [
                              if (loggedIn == true)
                                Positioned(
                                  top: 140,
                                  right: 24,
                                  child: _buildM3FloatingActionButton(
                                    context: context,
                                    backgroundColor: isSerieWatchlist == true
                                        ? Colors.lightBlueAccent
                                            .withValues(alpha: 0.25)
                                        : null,
                                    borderColor: isSerieWatchlist == true
                                        ? Colors.lightBlueAccent
                                            .withValues(alpha: 0.6)
                                        : null,
                                    onTap: () async {
                                      if (isSerieWatchlist == null) return;
                                      final movieId = widget.serieId;
                                      final openbox = Hive.box('sessionBox');
                                      final String accountId =
                                          openbox.get('accountId');
                                      final String sessionData =
                                          openbox.get('sessionData');
                                      if (isSerieWatchlist) {
                                        state.isSerieWatchlist.value = false;
                                        await removeFromWatchList(accountId,
                                            sessionData, movieId, context);
                                        profileRefreshNotifier.value++;
                                      } else {
                                        state.isSerieWatchlist.value = true;
                                        await addWatchList(accountId,
                                            sessionData, movieId, context);
                                        profileRefreshNotifier.value++;
                                      }
                                    },
                                    child: Icon(
                                      isSerieWatchlist == true
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      color: isSerieWatchlist == true
                                          ? Colors.lightBlueAccent
                                          : Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              if (loggedIn == true)
                                Positioned(
                                  top: 90,
                                  right: 24,
                                  child: _buildM3FloatingActionButton(
                                    context: context,
                                    backgroundColor: isSerieFavorite == true
                                        ? Colors.redAccent.withValues(alpha: 0.25)
                                        : null,
                                    borderColor: isSerieFavorite == true
                                        ? Colors.redAccent.withValues(alpha: 0.6)
                                        : null,
                                    onTap: () async {
                                      if (isSerieFavorite == null) return;
                                      final movieId = widget.serieId;
                                      final openbox = Hive.box('sessionBox');
                                      final String accountId =
                                          openbox.get('accountId');
                                      final String sessionData =
                                          openbox.get('sessionData');
                                      if (isSerieFavorite) {
                                        state.isSerieFavorite.value = false;
                                        await removeFromFavorite(accountId,
                                            sessionData, movieId, context);
                                        profileRefreshNotifier.value++;
                                      } else {
                                        state.isSerieFavorite.value = true;
                                        await addFavorite(accountId, sessionData,
                                            movieId, context);
                                        profileRefreshNotifier.value++;
                                      }
                                    },
                                    child: Icon(
                                      isSerieFavorite == true
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isSerieFavorite == true
                                          ? Colors.redAccent
                                          : Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              // logged in and rated
                              if (loggedIn == true &&
                                  isSerieRated != false &&
                                  userRating != null)
                                Positioned(
                                  top: 40,
                                  right: 24,
                                  child: _buildM3FloatingPillButton(
                                    context: context,
                                    backgroundColor:
                                        Colors.amber.withValues(alpha: 0.25),
                                    borderColor:
                                        Colors.amber.withValues(alpha: 0.6),
                                    onTap: () => showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              height: 20,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: ExpressiveRatingBar(
                                                initialRating: userRating,
                                                minRating: 1.0,
                                                maxRating: 10.0,
                                                itemCount: 10,
                                                itemSize: 32.0,
                                                allowHalfRating: true,
                                                onRatingUpdate: (rating) {
                                                  state.isSerieRated.value = {
                                                    'value': rating
                                                  };
                                                  state.userRating.value =
                                                      rating;
                                                },
                                                onRatingEnd: (rating) async {
                                                  final movieId = widget.serieId;
                                                  final openbox =
                                                      Hive.box('sessionBox');
                                                  final String sessionData =
                                                      openbox.get('sessionData');
                                                  await addRating(sessionData,
                                                      movieId, rating, context);
                                                  profileRefreshNotifier
                                                      .value++;
                                                },
                                              ),
                                            ),
                                            const CustomDivider(),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                final openbox =
                                                    Hive.box('sessionBox');

                                                final String sessionData =
                                                    openbox.get('sessionData');
                                                removeRating(sessionData,
                                                    widget.serieId, context);
                                                Navigator.of(context).pop();
                                                state.isSerieRated.value =
                                                    false;
                                                state.userRating.value = null;
                                              },
                                              child: const Text(
                                                ' 🗑️ Delete Rating',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 20,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          userRating.toStringAsFixed(1),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              //logged in not rated
                              if (loggedIn == true &&
                                  isSerieRated == false &&
                                  userRating == null)
                                Positioned(
                                  top: 40,
                                  right: 24,
                                  child: _buildM3FloatingActionButton(
                                    context: context,
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(
                                                height: 20,
                                              ),
                                              ExpressiveRatingBar(
                                                initialRating: 5.0,
                                                minRating: 1.0,
                                                maxRating: 10.0,
                                                itemCount: 10,
                                                itemSize: 32.0,
                                                allowHalfRating: true,
                                                onRatingUpdate: (rating) async {
                                                  final movieId =
                                                      widget.serieId;
                                                  final openbox =
                                                      Hive.box('sessionBox');

                                                  final String sessionData =
                                                      openbox.get('sessionData');
                                                  state.isSerieRated.value = {
                                                    'value': rating
                                                  };
                                                  state.userRating.value =
                                                      rating;
                                                  await addRating(
                                                      sessionData,
                                                      movieId,
                                                      rating,
                                                      context);
                                                  profileRefreshNotifier
                                                      .value++;
                                                },
                                              ),
                                              const SizedBox(
                                                height: 40,
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: const Icon(
                                      Icons.star_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                            ],
                            ),
                          );
                        },
                      ),

                        Positioned(
                          top: 40,
                          left: 20,
                          child: ShowWatchToggle(
                            key: showWatchToggleKey,
                            serieId: widget.serieId,
                            serieName: widget.serieName,
                            posterPath: posterPath,
                            numberOfEpisodes: episodes,
                            seasons: state.seasonsList,
                            onToggle: () {
                              // The widget handles its own state, no need to call _checkShowWatchedStatus
                            },
                          ),
                        ),
                    ],
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                                  'Seasons',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$seasons',
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
                                  'Episodes',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$episodes',
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
                    child: ValueListenableBuilder<bool>(
                      valueListenable: state.hasF2MResults,
                      builder: (context, hasF2MResults, _) {
                        final region =
                            Provider.of<RegionProvider>(context).currentRegion;
                        final showF2MDownload =
                            region == 'iran' && hasF2MResults;

                        final detailsBtn = FilledButton.icon(
                          icon:
                              const Icon(Icons.video_library_rounded, size: 24),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                getSeriesColor(context, widget.serieId),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: getSeriesColor(context, widget.serieId)
                                .withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () => seasonsAndEpisodes(context,
                              widget.serieId, widget.serieName, imdbId!,
                              seasons: state.seasonsList ?? const [],
                              imagePath: backdrops,
                              onWatchStatusChanged:
                                  state._refreshShowWatchStatus),
                          label: Text(
                            'Details',
                            style: getSeriesButtonTextStyle(widget.serieId)
                                .copyWith(fontSize: 16),
                          ),
                        );

                        if (!showF2MDownload) {
                          return SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: detailsBtn,
                          );
                        }

                        final downloadBtn = FilledButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 24),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              ExpressivePageRoute(
                                page: IranSeriesF2MPage(
                                  serieId: widget.serieId,
                                  serieName: widget.serieName,
                                  imdbId: imdbId!,
                                  f2mGroups: state.f2mGroups.value,
                                ),
                              ),
                            );
                          },
                          label: Text(
                            'Download',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        );

                        return Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: detailsBtn,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: downloadBtn,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  FutureBuilder(
                    future: creditsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                  child: Text(
                                    'Cast',
                                    textAlign: TextAlign.justify,
                                    style: getSeriesTitleTextStyle(widget.serieId),
                                  ),
                                ),
                              ],
                            ),
                            const CustomDivider(),
                            buildCastCrewSkeletonRow(isDesktop: false),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                  child: Text(
                                    'Crew',
                                    textAlign: TextAlign.justify,
                                    style: getSeriesTitleTextStyle(widget.serieId),
                                  ),
                                ),
                              ],
                            ),
                            const CustomDivider(),
                            buildCastCrewSkeletonRow(isDesktop: false),
                          ],
                        );
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
                                        style: getSeriesTitleTextStyle(
                                            widget.serieId),
                                      )),
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
                                        const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                    child: Text(
                                      'Crew',
                                      textAlign: TextAlign.justify,
                                      style:
                                          getSeriesTitleTextStyle(widget.serieId),
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
        backgroundColor: getSeriesColor(context, widget.serieId),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
            child: Text(
              widget.serieName,
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
    final backdrops = state.backdrops;
    final genres = state.genres;
    final about = state.about;
    final seasons = state.seasons;
    final episodes = state.episodes;
    final language = state.language;

    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

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
            RepaintBoundary(
              child: CachedNetworkImage(
                imageUrl: '${getImageBaseUrl(region)}/t/p/w780$backdrops',
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
                      widget.serieName,
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
                    color: getSeriesBackgroundColor(context, widget.serieId),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Seasons',
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
                          '$seasons',
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
                    color: getSeriesBackgroundColor(context, widget.serieId),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Episodes',
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
                          '$episodes',
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
                    color: getSeriesBackgroundColor(context, widget.serieId),
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
                          language != null ? language.toUpperCase() : 'N/A',
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

  Widget _buildM3FloatingPillButton({
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
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(24.0),
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
        borderRadius: 24.0,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          child: Center(child: child),
        ),
      ),
    );
  }
}
