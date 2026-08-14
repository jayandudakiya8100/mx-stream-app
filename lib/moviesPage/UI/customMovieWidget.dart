import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/moviesPage/functions/check_availability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class CustomMovieWidget extends StatefulWidget {
  final Movie movie;
  final bool showAvailability;
  final bool isWatched;
  final ValueListenable<Set<int>>? watchedMovieIds;

  const CustomMovieWidget({
    super.key,
    required this.movie,
    this.showAvailability = true,
    this.isWatched = false,
    this.watchedMovieIds,
  });

  @override
  State<CustomMovieWidget> createState() => _CustomMovieWidgetState();
}

class _CustomMovieWidgetState extends State<CustomMovieWidget> {
  Future<bool>? _availabilityFuture;
  String? _region;

  void _resolveAvailability(String region) {
    if (!widget.showAvailability) {
      _availabilityFuture = null;
      return;
    }
    _availabilityFuture = checkAvailability(widget.movie.id, region);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final region =
        Provider.of<RegionProvider>(context).currentRegion;
    if (_region != region) {
      _region = region;
      _resolveAvailability(region);
    }
  }

  @override
  void didUpdateWidget(CustomMovieWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id ||
        oldWidget.showAvailability != widget.showAvailability) {
      _resolveAvailability(_region ??
          Provider.of<RegionProvider>(context, listen: false).currentRegion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchedIds = widget.watchedMovieIds;
    if (watchedIds != null) {
      return ValueListenableBuilder<Set<int>>(
        valueListenable: watchedIds,
        builder: (context, ids, _) {
          return _buildCard(context, ids.contains(widget.movie.id));
        },
      );
    }
    return _buildCard(context, widget.isWatched);
  }

  Widget _buildCard(BuildContext context, bool isWatched) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = _region ??
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return Container(
      height: 500,
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            if (widget.movie.posterPath.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl:
                      '${getImageBaseUrl(region)}/t/p/w342${widget.movie.posterPath}',
                  memCacheWidth: 350,
                  fit: BoxFit.cover,
                  color: isWatched
                      ? Colors.black.withValues(alpha: 0.4)
                      : null,
                  colorBlendMode: isWatched ? BlendMode.darken : null,
                  placeholder: (context, url) =>
                      Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.movie,
                        size: 48, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Rating Badge Pill
            if (widget.movie.score != null && widget.movie.score! > 0)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        widget.movie.score!.toStringAsFixed(1),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Watched Badge
            if (isWatched)
              Positioned(
                top: 12,
                right: widget.showAvailability ? 54 : 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'WATCHED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Availability Icon
            if (widget.showAvailability && _availabilityFuture != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: FutureBuilder<bool>(
                    future: _availabilityFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return Icon(
                        snapshot.data == true
                            ? Icons.download_rounded
                            : Icons.cloud_off_rounded,
                        size: 18,
                        color: snapshot.data == true
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      );
                    },
                  ),
                ),
              ),
            // Details
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (widget.movie.releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.movie.releaseDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
