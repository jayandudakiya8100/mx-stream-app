import 'package:Mirarr/widgets/models/person.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/functions/get_base_url.dart';

class PersonSearchResult extends StatelessWidget {
  final Person person;

  const PersonSearchResult({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;

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
            if (person.profilePath.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: '${getImageBaseUrl(region)}/t/p/w500${person.profilePath}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, err) => Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.person_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Image.asset(
                  'assets/images/person.png',
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
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
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
                    person.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (person.department != null && person.department!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      person.department!,
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

