import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';

class ImageGalleryPage extends StatelessWidget {
  final List<String> imageUrls;

  const ImageGalleryPage({Key? key, required this.imageUrls}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Image Gallery',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.75,
        ),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: colorScheme.surfaceContainerHigh,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CachedNetworkImage(
                imageUrl:
                    '${getImageBaseUrl(region)}/t/p/w500${imageUrls[index]}',
                memCacheWidth: 400,
                maxWidthDiskCache: 500,
                placeholder: (context, url) => Container(
                  color: colorScheme.surfaceContainerHigh,
                  child: const M3ExpressiveSpinner(),
                ),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHigh,
                  child: Icon(Icons.error_outline_rounded, color: colorScheme.error),
                ),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}

