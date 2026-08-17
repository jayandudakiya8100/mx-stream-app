import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/seriesPage/models/serie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class CustomSeriesWidget extends StatelessWidget {
  final Serie serie;
  final double width;
  final double height;

  const CustomSeriesWidget({
    super.key,
    required this.serie,
    this.width = 140,
    this.height = 195,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final imageBase = getImageBaseUrl(region);

    final imageUrl = serie.posterPath.startsWith('http')
        ? serie.posterPath
        : '$imageBase/t/p/w342${serie.posterPath}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : width;
        final double cardHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? (constraints.maxHeight - 44).clamp(60.0, 400.0)
            : height;

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
                  child: serie.posterPath.isNotEmpty
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
                              Icons.tv_outlined,
                              size: 36,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.tv_outlined,
                            size: 36,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              // Title Text Underneath Poster
              Text(
                serie.name,
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
