import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/moviesPage/functions/check_availability.dart';
import 'package:flutter/material.dart';
import 'package:mxstream/moviesPage/models/movie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class MovieSearchResult extends StatefulWidget {
  final Movie movie;

  const MovieSearchResult({super.key, required this.movie});

  @override
  State<MovieSearchResult> createState() => _MovieSearchResultState();
}

class _MovieSearchResultState extends State<MovieSearchResult> {
  Future<bool>? _availabilityFuture;
  String? _region;

  void _resolveAvailability(String region) {
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
  void didUpdateWidget(MovieSearchResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id) {
      _resolveAvailability(_region ??
          Provider.of<RegionProvider>(context, listen: false).currentRegion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = _region ??
        Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (widget.movie.backdropPath != null &&
                widget.movie.backdropPath!.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl:
                      '${getImageBaseUrl(region)}/t/p/w780${widget.movie.backdropPath}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, err) =>
                      Container(color: colorScheme.surfaceContainerHigh),
                ),
              )
            else if (widget.movie.posterPath.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl:
                      '${getImageBaseUrl(region)}/t/p/w500${widget.movie.posterPath}',
                  fit: BoxFit.cover,
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Score Pill Badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      widget.movie.score != null
                          ? widget.movie.score!.toStringAsFixed(1)
                          : '0.0',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Availability Icon Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: FutureBuilder<bool>(
                  future: _availabilityFuture ?? Future.value(false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Icon(
                      snapshot.data == true
                          ? Icons.download_rounded
                          : Icons.cloud_off_rounded,
                      color: snapshot.data == true
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 14,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.movie.releaseDate.isNotEmpty)
                    Text(
                      widget.movie.releaseDate.contains('-')
                          ? widget.movie.releaseDate.split('-')[0]
                          : widget.movie.releaseDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
