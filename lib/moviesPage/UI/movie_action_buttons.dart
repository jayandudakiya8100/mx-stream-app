import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mxstream/widgets/m3_expressive_rating_bar.dart';
import 'package:mxstream/database/watch_history_database.dart';
import 'package:mxstream/moviesPage/functions/movie_tmdb_actions.dart';
import 'package:mxstream/widgets/profile.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:mxstream/utils/expressive_motion.dart';
import 'package:mxstream/widgets/custom_divider.dart';

Widget buildM3FloatingActionButton({
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

Widget buildM3FloatingPillButton({
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [child],
        ),
      ),
    ),
  );
}

Widget buildActionButton({
  required BuildContext context,
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

class MovieWatchlistButton extends StatefulWidget {
  final int movieId;
  final bool? initialIsWatchlist;
  final bool isUserLoggedIn;
  final bool isDesktop;

  const MovieWatchlistButton({
    Key? key,
    required this.movieId,
    required this.initialIsWatchlist,
    required this.isUserLoggedIn,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<MovieWatchlistButton> createState() => _MovieWatchlistButtonState();
}

class _MovieWatchlistButtonState extends State<MovieWatchlistButton> {
  bool? _isWatchlist;

  @override
  void initState() {
    super.initState();
    _isWatchlist = widget.initialIsWatchlist;
  }

  @override
  void didUpdateWidget(MovieWatchlistButton oldWidget) {
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
      await removeFromWatchList(accountId, sessionData, widget.movieId, context);
    } else {
      await addWatchList(accountId, sessionData, widget.movieId, context);
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

class MovieFavoriteButton extends StatefulWidget {
  final int movieId;
  final bool? initialIsFavorite;
  final bool isUserLoggedIn;
  final bool isDesktop;

  const MovieFavoriteButton({
    Key? key,
    required this.movieId,
    required this.initialIsFavorite,
    required this.isUserLoggedIn,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<MovieFavoriteButton> createState() => _MovieFavoriteButtonState();
}

class _MovieFavoriteButtonState extends State<MovieFavoriteButton> {
  bool? _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
  }

  @override
  void didUpdateWidget(MovieFavoriteButton oldWidget) {
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
      await removeFromFavorite(accountId, sessionData, widget.movieId, context);
    } else {
      await addFavorite(accountId, sessionData, widget.movieId, context);
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

class MovieWatchedButton extends StatefulWidget {
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final double? userRating;
  final bool initialIsWatched;
  final bool isDesktop;

  const MovieWatchedButton({
    Key? key,
    required this.movieId,
    required this.movieTitle,
    required this.posterPath,
    required this.userRating,
    required this.initialIsWatched,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<MovieWatchedButton> createState() => _MovieWatchedButtonState();
}

class _MovieWatchedButtonState extends State<MovieWatchedButton> {
  late bool _isWatched;
  final WatchHistoryDatabase _watchHistoryDb = WatchHistoryDatabase();

  @override
  void initState() {
    super.initState();
    _isWatched = widget.initialIsWatched;
  }

  @override
  void didUpdateWidget(MovieWatchedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsWatched != widget.initialIsWatched) {
      _isWatched = widget.initialIsWatched;
    }
  }

  Future<void> _toggleWatched() async {
    if (_isWatched) {
      try {
        final watchHistory = await _watchHistoryDb.getWatchHistoryByTmdbId(widget.movieId, 'movie');
        if (watchHistory.isNotEmpty) {
          await _watchHistoryDb.deleteWatchHistoryItem(watchHistory.first.id!);
          if (mounted) {
            setState(() {
              _isWatched = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.movieTitle} removed from watched!'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing movie from watched: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      try {
        await _watchHistoryDb.addMovieToHistory(
          tmdbId: widget.movieId,
          title: widget.movieTitle,
          posterPath: widget.posterPath,
          userRating: widget.userRating,
        );
        if (mounted) {
          setState(() {
            _isWatched = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.movieTitle} marked as watched!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error marking movie as watched: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return buildM3FloatingPillButton(
      context: context,
      backgroundColor: _isWatched ? Colors.green.withValues(alpha: 0.25) : null,
      borderColor: _isWatched ? Colors.green.withValues(alpha: 0.6) : null,
      onTap: _toggleWatched,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isWatched ? Icons.check_circle_rounded : Icons.visibility_outlined,
            color: _isWatched ? Colors.greenAccent : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _isWatched ? 'Watched' : 'Mark as Watched',
            style: theme.textTheme.labelMedium?.copyWith(
              color: _isWatched ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class MovieRatingButton extends StatefulWidget {
  final int movieId;
  final bool isUserLoggedIn;
  final dynamic initialIsRated;
  final double? initialUserRating;
  final bool isDesktop;

  const MovieRatingButton({
    Key? key,
    required this.movieId,
    required this.isUserLoggedIn,
    required this.initialIsRated,
    required this.initialUserRating,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<MovieRatingButton> createState() => _MovieRatingButtonState();
}

class _MovieRatingButtonState extends State<MovieRatingButton> {
  dynamic _isRated;
  double? _userRating;

  @override
  void initState() {
    super.initState();
    _isRated = widget.initialIsRated;
    _userRating = widget.initialUserRating;
  }

  @override
  void didUpdateWidget(MovieRatingButton oldWidget) {
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
                  await addRating(sessionData, widget.movieId, rating, context);
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
                  removeRating(sessionData, widget.movieId, context);
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
          tooltip: 'Rate Movie',
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
