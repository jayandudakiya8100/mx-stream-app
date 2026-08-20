import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:provider/provider.dart';

class ContinueWatchingItem {
  final int id;
  final String title;
  final String posterPath;
  final String? episodeBadge; // e.g. "S1:E18"
  final double progress; // 0.0 to 1.0 (e.g. 0.65)
  final String type; // 'movie' or 'tv'
  final int? seasonNumber;
  final int? episodeNumber;

  const ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.posterPath,
    this.episodeBadge,
    this.progress = 0.5,
    this.type = 'movie',
    this.seasonNumber,
    this.episodeNumber,
  });
}

class ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingItem item;

  const ContinueWatchingCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final imageBase = getImageBaseUrl(region);

    final imageUrl = item.posterPath.startsWith('http')
        ? item.posterPath
        : '$imageBase/t/p/w342${item.posterPath}';

    return SizedBox(
      width: 146,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
            // Poster Card with Center Play Button & Progress Ring
            Container(
              height: 200,
              width: 146,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surfaceContainerHigh,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Poster Image
                    if (item.posterPath.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        memCacheWidth: 300,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                    // Dark overlay for contrast
                    Container(
                      color: Colors.black.withValues(alpha: 0.32),
                    ),

                    // Centered Circular Play Button with Progress Ring
                    Center(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glassy dark circular background
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                            ),
                            // Circular Progress Indicator Stroke
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: item.progress.clamp(0.05, 1.0),
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            // Center Play Icon
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom badge (e.g. S1:E18 or title subtitle)
                    if (item.episodeBadge != null && item.episodeBadge!.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.episodeBadge!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title Text Underneath
            Text(
              item.title,
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
