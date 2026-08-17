import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:provider/provider.dart';

class HomeContentCard extends StatelessWidget {
  final Movie movie;

  const HomeContentCard({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final imageBase = getImageBaseUrl(region);

    final imageUrl = movie.posterPath.startsWith('http')
        ? movie.posterPath
        : '$imageBase/t/p/w342${movie.posterPath}';

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rounded Poster Image
          Container(
            height: 195,
            width: 140,
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
              child: movie.posterPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      memCacheWidth: 320,
                      fit: BoxFit.cover,
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
                  : Container(
                      color: colorScheme.surfaceContainerHigh,
                      child: Icon(
                        Icons.movie_outlined,
                        size: 36,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Title Text Underneath Poster
          Text(
            movie.title,
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
  }
}
