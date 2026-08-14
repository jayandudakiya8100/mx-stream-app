import 'package:flutter/material.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:Mirarr/widgets/cast/cast-details.dart';
import 'package:Mirarr/widgets/cast/crew-details.dart';
import 'package:provider/provider.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/functions/get_base_url.dart';

void onTapCast(BuildContext context, int castId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CastDetailPage(castId: castId),
    ),
  );
}

void onTapCrew(BuildContext context, int castId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CrewDetailPage(castId: castId),
    ),
  );
}

class CastCrewCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isDesktop;
  final bool isCast;
  final String region;

  const CastCrewCard({
    Key? key,
    required this.item,
    required this.isDesktop,
    required this.isCast,
    required this.region,
  }) : super(key: key);

  @override
  State<CastCrewCard> createState() => _CastCrewCardState();
}

class _CastCrewCardState extends State<CastCrewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double width = widget.isDesktop ? 120.0 : 90.0;
    final double height = widget.isDesktop ? 190.0 : 145.0;
    final double imageHeight = widget.isDesktop ? 120.0 : 90.0;
    final double borderRadius = widget.isDesktop ? 16.0 : 14.0;

    final String name = widget.item['name'] ?? '';
    final String subtitle = widget.isCast
        ? (widget.item['character'] ?? '')
        : (widget.item['job'] ?? '');
    final int id = widget.item['id'] ?? 0;
    final String? profilePath = widget.item['profile_path'];

    final outerPadding = widget.isDesktop
        ? const EdgeInsets.fromLTRB(16, 12, 0, 12)
        : const EdgeInsets.fromLTRB(10, 8, 0, 8);

    return Padding(
      padding: outerPadding,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: TvFocusWrapper(
            borderRadius: borderRadius,
            onTap: () {
              if (widget.isCast) {
                onTapCast(context, id);
              } else {
                onTapCrew(context, id);
              }
            },
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: _isHovered
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: _isHovered
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1.0,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(borderRadius - 1.0),
                    ),
                    child: SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: profilePath != null
                          ? CachedNetworkImage(
                              imageUrl: '${getImageBaseUrl(widget.region)}/t/p/${widget.isDesktop ? 'w185' : 'w185'}$profilePath',
                              memCacheWidth: widget.isDesktop ? 185 : 135,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Skeletonizer(
                                enabled: true,
                                child: Container(color: colorScheme.surfaceContainerLow),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerLow,
                                child: Icon(Icons.person_rounded, color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          : Container(
                              color: colorScheme.surfaceContainerLow,
                              child: Image.asset(
                                'assets/images/person.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildCastCrewSkeletonRow({required bool isDesktop}) {
  final double height = isDesktop ? 215.0 : 165.0;
  final double cardWidth = isDesktop ? 120.0 : 90.0;
  final double cardHeight = isDesktop ? 190.0 : 145.0;
  final double borderRadius = isDesktop ? 16.0 : 14.0;
  final outerPadding = isDesktop
      ? const EdgeInsets.fromLTRB(16, 12, 0, 12)
      : const EdgeInsets.fromLTRB(10, 8, 0, 8);

  return SizedBox(
    height: height,
    child: Skeletonizer(
      enabled: true,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: outerPadding,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget buildCastRow(List<Map<String, dynamic>> castList, BuildContext context) {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return SizedBox(
    height: 165.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemExtent: 100,
      itemCount: castList.length,
      itemBuilder: (context, index) {
        return CastCrewCard(
          item: castList[index],
          isDesktop: false,
          isCast: true,
          region: region,
        );
      },
    ),
  );
}

Widget buildCrewRow(List<Map<String, dynamic>> crewList, BuildContext context) {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return SizedBox(
    height: 165.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemExtent: 100,
      itemCount: crewList.length,
      itemBuilder: (context, index) {
        return CastCrewCard(
          item: crewList[index],
          isDesktop: false,
          isCast: false,
          region: region,
        );
      },
    ),
  );
}

Widget buildCrewRowDesktop(List<Map<String, dynamic>> crewList, BuildContext context) {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return SizedBox(
    height: 215.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemExtent: 136,
      itemCount: crewList.length,
      itemBuilder: (context, index) {
        return CastCrewCard(
          item: crewList[index],
          isDesktop: true,
          isCast: false,
          region: region,
        );
      },
    ),
  );
}

Widget buildCastRowDesktop(List<Map<String, dynamic>> castList, BuildContext context) {
  final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
  return SizedBox(
    height: 215.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemExtent: 136,
      itemCount: castList.length,
      itemBuilder: (context, index) {
        return CastCrewCard(
          item: castList[index],
          isDesktop: true,
          isCast: true,
          region: region,
        );
      },
    ),
  );
}

