import 'package:flutter/material.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:mxstream/widgets/cast/cast-details.dart';
import 'package:mxstream/widgets/cast/crew-details.dart';
import 'package:provider/provider.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/functions/get_base_url.dart';

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

    final String name = widget.item['name'] ?? '';
    final String subtitle = widget.isCast
        ? (widget.item['character'] ?? '')
        : (widget.item['job'] ?? '');
    final int id = widget.item['id'] ?? 0;
    final String? profilePath = widget.item['profile_path'];
    final double avatarRadius = widget.isDesktop ? 36.0 : 32.0;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: TvFocusWrapper(
            borderRadius: 36.0,
            onTap: () {
              if (widget.isCast) {
                onTapCast(context, id);
              } else {
                onTapCrew(context, id);
              }
            },
            child: SizedBox(
              width: 78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Portrait Avatar
                  Container(
                    width: avatarRadius * 2,
                    height: avatarRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profilePath != null && profilePath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl:
                                  '${getImageBaseUrl(widget.region)}/t/p/w185$profilePath',
                              memCacheWidth: 185,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHigh,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerHigh,
                                child: Icon(Icons.person_rounded,
                                    color: colorScheme.onSurfaceVariant, size: 28),
                              ),
                            )
                          : Container(
                              color: colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.person_rounded,
                                  color: colorScheme.onSurfaceVariant, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Actor Name
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    // Character / Job
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10,
                        height: 1.15,
                      ),
                    ),
                  ],
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
  return SizedBox(
    height: 135.0,
    child: Skeletonizer(
      enabled: true,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 50,
                  height: 10,
                  color: Colors.white10,
                ),
              ],
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
    height: 135.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    height: 135.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    height: 150.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    height: 150.0,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
