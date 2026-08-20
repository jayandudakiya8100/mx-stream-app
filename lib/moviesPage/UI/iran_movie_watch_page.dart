import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mxstream/moviesPage/checkers/custom_tmdb_ids_effects.dart';
import 'package:mxstream/moviesPage/functions/f2m_parser.dart';
import 'package:mxstream/moviesPage/functions/watch_links.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';

class IranMovieWatchPage extends StatefulWidget {
  final int movieId;
  final String movieTitle;
  final String releaseDate;
  final String imdbId;

  const IranMovieWatchPage({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.releaseDate,
    required this.imdbId,
  });

  @override
  State<IranMovieWatchPage> createState() => _IranMovieWatchPageState();
}

class _IranMovieWatchPageState extends State<IranMovieWatchPage> {
  // 1. F2M Downloads (Priority 1)
  List<F2MSeasonGroup> _f2mGroups = [];
  bool _isLoadingF2M = true;

  // 2. Direct Downloads (Priority 2)
  List<DownloadItem> _directDownloads = [];
  bool _isLoadingDirect = true;

  // 3. GitHub Watch Options (Priority 3)
  Map<String, Map<String, dynamic>> _watchOptions = {};
  bool _isLoadingWatchOptions = true;

  @override
  void initState() {
    super.initState();
    _loadAllSources();
  }

  void _loadAllSources() {
    _loadF2M();
    _loadDirectDownloads();
    _loadWatchOptions();
  }

  Future<void> _loadF2M() async {
    try {
      final groups = await fetchF2MDownloadLinks(widget.imdbId);
      if (mounted) {
        setState(() {
          _f2mGroups = groups;
          _isLoadingF2M = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _f2mGroups = [];
          _isLoadingF2M = false;
        });
      }
    }
  }

  Future<void> _loadDirectDownloads() async {
    try {
      final year = widget.releaseDate.split('-')[0];
      final imdbIdWithoutTT = widget.imdbId.startsWith('tt')
          ? widget.imdbId.substring(2)
          : widget.imdbId;

      final downloads = await fetchAllIranDownloadLinks(
        widget.movieTitle,
        year,
        imdbIdWithoutTT,
      );

      if (mounted) {
        setState(() {
          _directDownloads = downloads;
          _isLoadingDirect = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _directDownloads = [];
          _isLoadingDirect = false;
        });
      }
    }
  }

  Future<void> _loadWatchOptions() async {
    try {
      final rawSources = await fetchSources();
      final optionUrls = rawSources.map((key, value) {
        final url = value['url']
            .toString()
            .replaceAll('{movieId}', widget.movieId.toString());
        return MapEntry(key, {...value, 'url': url});
      });

      if (mounted) {
        setState(() {
          _watchOptions = optionUrls;
          _isLoadingWatchOptions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _watchOptions = {};
          _isLoadingWatchOptions = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    } catch (_) {}
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text('URL copied to clipboard'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainColor = getMovieColor(context, widget.movieId);
    final isDoneLoadingAll =
        !_isLoadingF2M && !_isLoadingDirect && !_isLoadingWatchOptions;

    final hasF2M = _f2mGroups.isNotEmpty;
    final hasDirect = _directDownloads.isNotEmpty;
    final hasWatch = _watchOptions.isNotEmpty;

    final hasAnyContent = hasF2M || hasDirect || hasWatch;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.movieTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (widget.releaseDate.isNotEmpty) ...[
                  Text(
                    widget.releaseDate.split('-')[0],
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇷', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'Iran Region',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Section 1: F2M Downloads (Priority 1)
          if (_isLoadingF2M)
            _buildLoadingSliver('F2M Downloads', mainColor)
          else if (hasF2M)
            ..._buildF2MSlivers(theme, mainColor),

          // Section 2: Direct Downloads (Priority 2)
          if (_isLoadingDirect)
            _buildLoadingSliver('Direct Downloads', mainColor)
          else if (hasDirect)
            ..._buildDirectDownloadsSlivers(theme, mainColor),

          // Section 3: Watch Options (Priority 3)
          if (_isLoadingWatchOptions)
            _buildLoadingSliver('Streaming Watch Options', mainColor)
          else if (hasWatch)
            ..._buildWatchOptionsSlivers(theme, mainColor),

          // All done and empty fallback
          if (isDoneLoadingAll && !hasAnyContent)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.movie_outlined,
                          size: 40,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Options Available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No watch or download sources were found for this movie right now.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSliver(String title, Color mainColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 16,
              height: 16,
              child: M3ExpressiveSpinner(size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. F2M UI ---
  List<Widget> _buildF2MSlivers(ThemeData theme, Color mainColor) {
    final widgets = <Widget>[];

    // Section Header
    widgets.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cloud_download_rounded, color: mainColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'F2M Downloads',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: mainColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (final group in _f2mGroups) {
      if (group.seasonName.isNotEmpty) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                group.seasonName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }

      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = group.items[index];
                return _buildF2MItemCard(theme, mainColor, item);
              },
              childCount: group.items.length,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildF2MItemCard(
      ThemeData theme, Color mainColor, F2MDownloadItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveInteractiveContainer(
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quality Title as Main Title
              Row(
                children: [
                  Icon(Icons.cloud_download_outlined, size: 18, color: mainColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Chips (F2M tag, Dubbed/Subbed/Audio tags, Quality, Encoder, Size)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMetaChip(
                    theme,
                    'F2M',
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.onSurfaceVariant,
                  ),
                  ...item.extraTags.map((tag) {
                    Color tagBg = Colors.teal.withValues(alpha: 0.2);
                    Color tagText = Colors.teal;
                    if (tag.contains('Dubbed')) {
                      tagBg = Colors.amber.withValues(alpha: 0.2);
                      tagText = Colors.amber;
                    } else if (tag.contains('Sub')) {
                      tagBg = Colors.blue.withValues(alpha: 0.2);
                      tagText = Colors.blue;
                    }
                    return _buildMetaChip(theme, tag, tagBg, tagText);
                  }),
                  if (item.quality.isNotEmpty && item.quality != item.title)
                    _buildMetaChip(
                      theme,
                      item.quality,
                      Colors.blue.withValues(alpha: 0.2),
                      Colors.blue,
                    ),
                  if (item.encoder.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      item.encoder,
                      Colors.purple.withValues(alpha: 0.2),
                      Colors.purple,
                    ),
                  if (item.size.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      item.size,
                      mainColor.withValues(alpha: 0.2),
                      mainColor,
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Download links
              ...item.links.map((link) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              link.label,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => _launchUrl(link.url),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Copy Link',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copyToClipboard(link.url),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(
      ThemeData theme, String label, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textCol,
        ),
      ),
    );
  }

  // --- 2. Direct Downloads UI ---
  List<Widget> _buildDirectDownloadsSlivers(ThemeData theme, Color mainColor) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.dns_rounded, color: mainColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Direct Server Downloads',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: mainColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _directDownloads[index];
              return _buildDirectDownloadTile(theme, mainColor, item);
            },
            childCount: _directDownloads.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildDirectDownloadTile(
      ThemeData theme, Color mainColor, DownloadItem item) {
    String quality = '';
    if (item.fileName.contains('1080p')) {
      quality = '1080p';
    } else if (item.fileName.contains('720p')) {
      quality = '720p';
    } else if (item.fileName.contains('480p')) {
      quality = '480p';
    } else if (item.fileName.contains('2160p') || item.fileName.contains('4K')) {
      quality = '4K';
    }

    String codec = '';
    if (item.fileName.contains('x265') || item.fileName.contains('HEVC')) {
      codec = 'x265';
    } else if (item.fileName.contains('x264')) {
      codec = 'x264';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveInteractiveContainer(
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.movie_outlined, size: 18, color: mainColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.fileName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMetaChip(
                    theme,
                    item.server,
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.onSurfaceVariant,
                  ),
                  if (item.size.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      item.size,
                      mainColor.withValues(alpha: 0.2),
                      mainColor,
                    ),
                  if (quality.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      quality,
                      Colors.blue.withValues(alpha: 0.2),
                      Colors.blue,
                    ),
                  if (codec.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      codec,
                      Colors.purple.withValues(alpha: 0.2),
                      Colors.purple,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: mainColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download', style: TextStyle(fontSize: 12)),
                        onPressed: () => _launchUrl(item.url),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: IconButton.filledTonal(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      tooltip: 'Copy Link',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => _copyToClipboard(item.url),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. Watch Options UI ---
  List<Widget> _buildWatchOptionsSlivers(ThemeData theme, Color mainColor) {
    final keys = _watchOptions.keys.toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.play_circle_filled_rounded,
                    color: mainColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Streaming Watch Options',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: mainColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final key = keys[index];
              final optionData = _watchOptions[key];
              return _buildWatchOptionTile(theme, mainColor, key, optionData);
            },
            childCount: keys.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildWatchOptionTile(ThemeData theme, Color mainColor, String name,
      Map<String, dynamic>? optionData) {
    final url = optionData?['url']?.toString() ?? '';
    final hasAds = optionData?['hasAds'] == true;
    final hasSubs = optionData?['hasSubs'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveInteractiveContainer(
        borderRadius: 14,
        onTap: url.isNotEmpty ? () => _launchUrl(url) : null,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded, color: mainColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (hasAds)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildMetaChip(
                    theme,
                    'Ads',
                    theme.colorScheme.errorContainer,
                    theme.colorScheme.onErrorContainer,
                  ),
                ),
              if (hasSubs)
                _buildMetaChip(
                  theme,
                  'Subs',
                  mainColor.withValues(alpha: 0.2),
                  mainColor,
                ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
