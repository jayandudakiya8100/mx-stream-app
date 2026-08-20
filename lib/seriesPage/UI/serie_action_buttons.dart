import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mxstream/widgets/m3_expressive_rating_bar.dart';
import 'package:mxstream/seriesPage/function/series_tmdb_actions.dart';
import 'package:mxstream/widgets/profile.dart';
import 'package:mxstream/moviesPage/UI/movie_action_buttons.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:mxstream/utils/expressive_motion.dart';
import 'package:mxstream/widgets/custom_divider.dart';

class SerieWatchlistButton extends StatefulWidget {
  final int serieId;
  final bool? initialIsWatchlist;
  final bool isUserLoggedIn;
  final bool isDesktop;

  const SerieWatchlistButton({
    Key? key,
    required this.serieId,
    required this.initialIsWatchlist,
    required this.isUserLoggedIn,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<SerieWatchlistButton> createState() => _SerieWatchlistButtonState();
}

class _SerieWatchlistButtonState extends State<SerieWatchlistButton> {
  bool? _isWatchlist;

  @override
  void initState() {
    super.initState();
    _isWatchlist = widget.initialIsWatchlist;
  }

  @override
  void didUpdateWidget(SerieWatchlistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsWatchlist != widget.initialIsWatchlist) {
      _isWatchlist = widget.initialIsWatchlist;
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_isWatchlist == null || !widget.isUserLoggedIn) return;
    final currentStatus = _isWatchlist!;
    setState(() {
      _isWatchlist = !currentStatus;
    });

    final openbox = Hive.box('sessionBox');
    final String accountId = openbox.get('accountId');
    final String sessionData = openbox.get('sessionData');

    if (currentStatus) {
      await removeFromWatchList(accountId, sessionData, widget.serieId, context);
    } else {
      await addWatchList(accountId, sessionData, widget.serieId, context);
    }
    profileRefreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUserLoggedIn) return const SizedBox.shrink();

    final isWatchlist = _isWatchlist;
    const activeColor = Colors.lightBlueAccent;

    if (widget.isDesktop) {
      return buildActionButton(
        context: context,
        icon: isWatchlist == true ? Icons.bookmark : Icons.bookmark_border,
        iconColor: isWatchlist == true ? activeColor : Colors.white,
        tooltip: isWatchlist == true ? 'Remove from Watchlist' : 'Add to Watchlist',
        onTap: _toggleWatchlist,
      );
    } else {
      return buildM3FloatingActionButton(
        context: context,
        backgroundColor: isWatchlist == true
            ? activeColor.withValues(alpha: 0.25)
            : null,
        borderColor: isWatchlist == true
            ? activeColor.withValues(alpha: 0.6)
            : null,
        onTap: _toggleWatchlist,
        child: Icon(
          isWatchlist == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isWatchlist == true ? activeColor : Colors.white,
          size: 22,
        ),
      );
    }
  }
}

class SerieFavoriteButton extends StatefulWidget {
  final int serieId;
  final bool? initialIsFavorite;
  final bool isUserLoggedIn;
  final bool isDesktop;

  const SerieFavoriteButton({
    Key? key,
    required this.serieId,
    required this.initialIsFavorite,
    required this.isUserLoggedIn,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<SerieFavoriteButton> createState() => _SerieFavoriteButtonState();
}

class _SerieFavoriteButtonState extends State<SerieFavoriteButton> {
  bool? _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
  }

  @override
  void didUpdateWidget(SerieFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFavorite != widget.initialIsFavorite) {
      _isFavorite = widget.initialIsFavorite;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite == null || !widget.isUserLoggedIn) return;
    final currentStatus = _isFavorite!;
    setState(() {
      _isFavorite = !currentStatus;
    });

    final openbox = Hive.box('sessionBox');
    final String accountId = openbox.get('accountId');
    final String sessionData = openbox.get('sessionData');

    if (currentStatus) {
      await removeFromFavorite(accountId, sessionData, widget.serieId, context);
    } else {
      await addFavorite(accountId, sessionData, widget.serieId, context);
    }
    profileRefreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUserLoggedIn) return const SizedBox.shrink();

    final isFavorite = _isFavorite;

    if (widget.isDesktop) {
      return buildActionButton(
        context: context,
        icon: isFavorite == true ? Icons.favorite : Icons.favorite_border,
        iconColor: isFavorite == true ? Colors.redAccent : Colors.white,
        tooltip: isFavorite == true ? 'Remove from Favorites' : 'Add to Favorites',
        onTap: _toggleFavorite,
      );
    } else {
      return buildM3FloatingActionButton(
        context: context,
        backgroundColor: isFavorite == true
            ? Colors.redAccent.withValues(alpha: 0.25)
            : null,
        borderColor: isFavorite == true
            ? Colors.redAccent.withValues(alpha: 0.6)
            : null,
        onTap: _toggleFavorite,
        child: Icon(
          isFavorite == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite == true ? Colors.redAccent : Colors.white,
          size: 22,
        ),
      );
    }
  }
}

class SerieRatingButton extends StatefulWidget {
  final int serieId;
  final bool isUserLoggedIn;
  final dynamic initialIsRated;
  final double? initialUserRating;
  final bool isDesktop;

  const SerieRatingButton({
    Key? key,
    required this.serieId,
    required this.isUserLoggedIn,
    required this.initialIsRated,
    required this.initialUserRating,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<SerieRatingButton> createState() => _SerieRatingButtonState();
}

class _SerieRatingButtonState extends State<SerieRatingButton> {
  dynamic _isRated;
  double? _userRating;

  @override
  void initState() {
    super.initState();
    _isRated = widget.initialIsRated;
    _userRating = widget.initialUserRating;
  }

  @override
  void didUpdateWidget(SerieRatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsRated != widget.initialIsRated ||
        oldWidget.initialUserRating != widget.initialUserRating) {
      _isRated = widget.initialIsRated;
      _userRating = widget.initialUserRating;
    }
  }

  void _showRatingModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpressiveRatingBar(
                initialRating: _userRating ?? 5.0,
                minRating: 1.0,
                maxRating: 10.0,
                itemCount: 10,
                itemSize: 32.0,
                allowHalfRating: true,
                onRatingUpdate: (rating) {
                  setState(() {
                    _isRated = {'value': rating};
                    _userRating = rating;
                  });
                },
                onRatingEnd: (rating) async {
                  final openbox = Hive.box('sessionBox');
                  final String sessionData = openbox.get('sessionData');
                  await addRating(sessionData, widget.serieId, rating, context);
                  profileRefreshNotifier.value++;
                },
              ),
            ),
            if (_userRating != null) ...[
              const CustomDivider(),
              const SizedBox(height: 10),
              ExpressiveInteractiveContainer(
                onTap: () async {
                  final openbox = Hive.box('sessionBox');
                  final String sessionData = openbox.get('sessionData');
                  removeRating(sessionData, widget.serieId, context);
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _isRated = false;
                    _userRating = null;
                  });
                  profileRefreshNotifier.value++;
                },
                borderRadius: 16,
                speed: ExpressiveSpeed.fast,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    ' 🗑️ Delete Rating',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUserLoggedIn) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasRating = _isRated != null && _isRated != false && _userRating != null;

    if (widget.isDesktop) {
      if (hasRating) {
        return GestureDetector(
          onTap: _showRatingModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  _userRating!.toStringAsFixed(1),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return buildActionButton(
          context: context,
          icon: Icons.add_reaction_rounded,
          iconColor: Colors.white,
          tooltip: 'Rate Show',
          onTap: _showRatingModal,
        );
      }
    } else {
      if (hasRating) {
        return buildM3FloatingPillButton(
          context: context,
          backgroundColor: Colors.amber.withValues(alpha: 0.25),
          borderColor: Colors.amber.withValues(alpha: 0.6),
          onTap: _showRatingModal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                _userRating!.toStringAsFixed(1),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else {
        return buildM3FloatingActionButton(
          context: context,
          onTap: _showRatingModal,
          child: const Icon(
            Icons.star_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        );
      }
    }
  }
}
