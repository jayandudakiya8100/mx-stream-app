import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/moviesPage/functions/check_availability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class CustomMovieWidget extends StatefulWidget {
  final Movie movie;
  final bool showAvailability;
  final bool isWatched;
  final ValueListenable<Set<int>>? watchedMovieIds;
  final double width;
  final double height;

  const CustomMovieWidget({
    super.key,
    required this.movie,
    this.showAvailability = true,
    this.isWatched = false,
    this.watchedMovieIds,
    this.width = 140,
    this.height = 195,
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
    final region = Provider.of<RegionProvider>(context).currentRegion;
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
    final imageBase = getImageBaseUrl(region);

    final imageUrl = widget.movie.posterPath.startsWith('http')
        ? widget.movie.posterPath
        : '$imageBase/t/p/w342${widget.movie.posterPath}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : widget.width;
        final double cardHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? (constraints.maxHeight - 48).clamp(60.0, 400.0)
            : widget.height;

        return SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rounded Poster Image
              Container(
                height: cardHeight,
                width: cardWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.movie.posterPath.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          memCacheWidth: 320,
                          fit: BoxFit.cover,
                          color: isWatched
                              ? Colors.black.withValues(alpha: 0.4)
                              : null,
                          colorBlendMode: isWatched ? BlendMode.darken : null,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHigh,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHigh,
                            child: Icon(
                              Icons.movie_outlined,
                              size: 36,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.movie_outlined,
                            size: 36,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),

                      // Watched Badge (Top Right)
                      if (isWatched)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),

                      // Availability Icon (Top Right, if not watched)
                      if (!isWatched && widget.showAvailability && _availabilityFuture != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FutureBuilder<bool>(
                            future: _availabilityFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  snapshot.data != true) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.download_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title Text Underneath Poster
              Text(
                widget.movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
