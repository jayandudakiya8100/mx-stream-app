part of 'serieDetailPage.dart';

class _SerieDetailPageDesktop extends StatelessWidget {
  final _SerieDetailPageState state;

  const _SerieDetailPageDesktop(this.state);

  @override
  Widget build(BuildContext context) {
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

    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

    final bool isTv = TvFocusModeManager.isTvDevice;

    final Widget bodyContent = serieDetails == null
        ? const M3ExpressiveSpinner()
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
                                  memCacheWidth: 500,
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
                                        widget.serieName,
                                        style: getSeriesTitleTextStyle(widget.serieId),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      if (genres != null && (genres).isNotEmpty) ...[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              (genres).map((g) => g['name']).join(', '),
                                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
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
                                              state.isSerieRated,
                                              state.userRating,
                                            ]),
                                            builder: (context, _) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SerieRatingButton(
                                                    serieId: widget.serieId,
                                                    isUserLoggedIn: state.isUserLoggedIn.value == true,
                                                    initialIsRated: state.isSerieRated.value,
                                                    initialUserRating: state.userRating.value,
                                                    isDesktop: true,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  ShowWatchToggle(
                                                    key: showWatchToggleKey,
                                                    serieId: widget.serieId,
                                                    serieName: widget.serieName,
                                                    posterPath: posterPath,
                                                    numberOfEpisodes: episodes,
                                                    seasons: state.seasonsList,
                                                    onToggle: () {
                                                      // The widget handles its own state
                                                    },
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
                                          AnimatedBuilder(
                                            animation: Listenable.merge([
                                              state.isUserLoggedIn,
                                              state.isSerieWatchlist,
                                              state.isSerieFavorite,
                                            ]),
                                            builder: (context, _) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SerieWatchlistButton(
                                                    serieId: widget.serieId,
                                                    initialIsWatchlist: state.isSerieWatchlist.value,
                                                    isUserLoggedIn: state.isUserLoggedIn.value == true,
                                                    isDesktop: true,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SerieFavoriteButton(
                                                    serieId: widget.serieId,
                                                    initialIsFavorite: state.isSerieFavorite.value,
                                                    isUserLoggedIn: state.isUserLoggedIn.value == true,
                                                    isDesktop: true,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: state.hasF2MResults,
                                        builder: (context, hasF2MResults, _) {
                                          final region =
                                              Provider.of<RegionProvider>(context).currentRegion;
                                          final showF2MDownload =
                                              region == 'iran' && hasF2MResults;

                                          final detailsBtn = _buildPrimaryButton(
                                            text: 'Details',
                                            backgroundColor:
                                                getSeriesColor(context, widget.serieId),
                                            textStyle:
                                                getSeriesButtonTextStyle(widget.serieId),
                                            icon: Icons.info_outline_rounded,
                                            onPressed: () => seasonsAndEpisodes(
                                              context,
                                              widget.serieId,
                                              widget.serieName,
                                              imdbId!,
                                              seasons: state.seasonsList ?? const [],
                                              imagePath: backdrops,
                                              onWatchStatusChanged:
                                                  state._refreshShowWatchStatus,
                                            ),
                                          );

                                          if (!showF2MDownload) return detailsBtn;

                                          return Wrap(
                                            spacing: 16,
                                            runSpacing: 16,
                                            children: [
                                              detailsBtn,
                                              _buildSecondaryButton(
                                                text: 'Download',
                                                textStyle: getSeriesButtonTextStyle(widget.serieId),
                                                icon: Icons.download_rounded,
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
                                              ),
                                            ],
                                          );
                                        },
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
                                          _buildInfoCard(
                                            title: 'SEASONS',
                                            value: '$seasons',
                                          ),
                                          _buildInfoCard(
                                            title: 'EPISODES',
                                            value: '$episodes',
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                child: Text(
                                  'Cast',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: AppPlatform.isAndroid || AppPlatform.isIOS ? 18 : 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const CustomDivider(),
                              buildCastCrewSkeletonRow(isDesktop: true),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(25, 10, 0, 0),
                                child: Text(
                                  'Crew',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: AppPlatform.isAndroid || AppPlatform.isIOS ? 18 : 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const CustomDivider(),
                              buildCastCrewSkeletonRow(isDesktop: true),
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
                                        style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontSize: AppPlatform.isAndroid ||
                                                    AppPlatform.isIOS
                                                ? 18
                                                : 30,
                                            fontWeight: FontWeight.w700),
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
                                        style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontSize: AppPlatform.isAndroid ||
                                                    AppPlatform.isIOS
                                                ? 18
                                                : 30,
                                            fontWeight: FontWeight.w700),
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
                  ],
                ),
              ),
            );

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
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
                fontWeight: FontWeight.bold,
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
