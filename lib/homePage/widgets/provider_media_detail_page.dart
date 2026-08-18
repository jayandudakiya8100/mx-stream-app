import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';

import 'package:Mirarr/functions/fetchers/providers/provider_config.dart';
import 'package:Mirarr/functions/fetchers/providers/core/models.dart';
import 'package:Mirarr/functions/fetchers/providers/provider_manager.dart';
import 'package:Mirarr/homePage/widgets/set_watch_status_modal.dart';
import 'package:Mirarr/player/temp_player_sheet.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/widgets/search_screen.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';

class ProviderMediaDetailPage extends StatefulWidget {
  final String title;
  final String posterPath;
  final String permalink;
  final String providerName;

  const ProviderMediaDetailPage({
    super.key,
    required this.title,
    required this.posterPath,
    required this.permalink,
    this.providerName = 'VegaMovies',
  });

  @override
  State<ProviderMediaDetailPage> createState() => _ProviderMediaDetailPageState();
}

class _ProviderMediaDetailPageState extends State<ProviderMediaDetailPage> {
  bool _isLoading = true;
  ProviderMediaDetails? _detail;
  String? _errorMessage;
  int? _extractingEpisodeIndex;
  bool _isExtractingMovie = false;
  String _watchStatus = 'None';

  int get _stableMediaId => WatchStatusManager.getStableMediaId(
        widget.permalink.isNotEmpty ? widget.permalink : widget.title,
      );

  @override
  void initState() {
    super.initState();
    _watchStatus = WatchStatusManager.getStatus(_stableMediaId);
    WatchStatusManager.watchStatusNotifier.addListener(_onGlobalWatchStatusChanged);
    _loadDetails();
  }

  @override
  void dispose() {
    WatchStatusManager.watchStatusNotifier.removeListener(_onGlobalWatchStatusChanged);
    super.dispose();
  }

  void _onGlobalWatchStatusChanged() {
    if (mounted) {
      final updated = WatchStatusManager.getStatus(_stableMediaId);
      if (updated != _watchStatus) {
        setState(() {
          _watchStatus = updated;
        });
      }
    }
  }

  Future<void> _onToggleWatchStatus() async {
    final newStatus = await SetWatchStatusModal.show(
      context,
      tmdbId: _stableMediaId,
      title: widget.title,
      posterPath: widget.posterPath,
      initialStatus: _watchStatus,
      permalink: widget.permalink,
      providerName: widget.providerName,
    );
    if (newStatus != null && mounted) {
      setState(() {
        _watchStatus = newStatus;
      });
    }
  }

  void _openGlobalSearch() {
    final query = _detail?.title ?? widget.title;
    Navigator.push(
      context,
      ExpressivePageRoute(
        page: SearchScreen(initialQuery: query),
      ),
    );
  }

  Future<void> _openProviderRootLink() async {
    final targetUrl = widget.permalink.isNotEmpty
        ? widget.permalink
        : await ProviderConfig.resolveBaseUrl(widget.providerName);
    if (targetUrl.isNotEmpty && await canLaunchUrlString(targetUrl)) {
      await launchUrlString(targetUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showCastSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF16161A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.cast_rounded, color: Color(0xFF4C68FF), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Cast Media',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Connect to a Chromecast or compatible smart display on your local network to cast video.',
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tv_rounded, color: Colors.white),
                title: const Text('Scanning for devices...', style: TextStyle(color: Colors.white)),
                trailing: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4C68FF)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _shareMedia() {
    final title = _detail?.title ?? widget.title;
    final url = widget.permalink;
    Share.share('Check out $title\n$url');
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = ProviderManager.getProvider(widget.providerName);
      if (provider == null) throw Exception('Provider not found');
      final data = await provider.loadDetails(widget.permalink);
      if (mounted) {
        setState(() {
          _detail = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load details: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showStreamLinksSheet({
    required String title,
    required List<StreamLink> streams,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141418),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C68FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: Color(0xFF4C68FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Stream Resolution',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // List of Streams / Resolutions
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: streams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = streams[index];
                      final name = s.name.isNotEmpty ? s.name : 'Stream ${index + 1}';
                      final quality = s.quality.isNotEmpty ? s.quality : 'Direct Stream';

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E26),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4C68FF).withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.play_circle_filled_rounded,
                              color: Color(0xFF4C68FF),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            quality,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Copy Stream Link Button
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Copy Link',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: s.streamUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Copied: ${s.name}'),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF1E1E26),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              // Play Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4C68FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: const Size(60, 34),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  final header = s.name.isNotEmpty
                                      ? s.name
                                      : '$title [${s.quality}]';
                                  TempPlayerSheet.show(
                                    context: context,
                                    streamUrl: s.streamUrl,
                                    title: title,
                                    mediaHeader: header,
                                    quality: s.quality,
                                    availableStreams: streams,
                                  );
                                },
                                child: const Text(
                                  'Play',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            final header = s.name.isNotEmpty
                                ? s.name
                                : '$title [${s.quality}]';
                            TempPlayerSheet.show(
                              context: context,
                              streamUrl: s.streamUrl,
                              title: title,
                              mediaHeader: header,
                              quality: s.quality,
                              availableStreams: streams,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _playEpisode(EpisodeInfo ep, int index) async {
    setState(() {
      _extractingEpisodeIndex = index;
    });

    try {
      final provider = ProviderManager.getProvider(widget.providerName);
      if (provider == null) throw Exception('Provider not found');
      
      List<StreamLink> streams = [];
      String? fallbackUrl;
      if (ep.sources.isNotEmpty) {
        final futures = ep.sources.map<Future<List<StreamLink>>>((source) async {
          try {
            final extracted = await provider.extractStream(source.url);
            return extracted.map((s) => StreamLink(
              name: s.name,
              streamUrl: s.streamUrl,
              quality: source.resolution, // Preserve original resolution tag
            )).toList();
          } catch (_) {
            return <StreamLink>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (var res in results) {
          streams.addAll(res);
        }
        fallbackUrl = ep.sources.first.url;
      } else {
        fallbackUrl = ep.poster ?? widget.permalink;
        streams = await provider.extractStream(fallbackUrl);
      }
      
      if (!mounted) return;
      setState(() => _extractingEpisodeIndex = null);

      if (streams.isNotEmpty) {
        _showStreamLinksSheet(
          title: '${widget.title} - ${ep.name}',
          streams: streams,
        );
      } else {
        // Fallback open in browser if extraction cannot be automated
        if (fallbackUrl != null && await canLaunchUrlString(fallbackUrl)) {
          await launchUrlString(fallbackUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _extractingEpisodeIndex = null);
        final fallbackUrl = ep.sources.isNotEmpty ? ep.sources.first.url : widget.permalink;
        if (await canLaunchUrlString(fallbackUrl)) {
          await launchUrlString(fallbackUrl, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Future<void> _playMovie() async {
    if (_detail == null) return;
    setState(() => _isExtractingMovie = true);

    try {
      final provider = ProviderManager.getProvider(widget.providerName);
      List<StreamLink> streams = [];
      if (_detail!.sources.isNotEmpty && provider != null) {
        final futures = _detail!.sources.map<Future<List<StreamLink>>>((source) async {
          try {
            final extracted = await provider.extractStream(source.url);
            return extracted.map((s) => StreamLink(
              name: s.name,
              streamUrl: s.streamUrl,
              quality: source.resolution, // Preserve original resolution tag
            )).toList();
          } catch (_) {
            return <StreamLink>[];
          }
        });
        
        final results = await Future.wait(futures);
        for (var res in results) {
          streams.addAll(res);
        }
      }

      if (!mounted) return;
      setState(() => _isExtractingMovie = false);

      if (streams.isNotEmpty) {
        _showStreamLinksSheet(
          title: widget.title,
          streams: streams,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No streaming links available for this title.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtractingMovie = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final effectivePoster = (_detail?.poster != null && _detail!.poster.isNotEmpty)
        ? _detail!.poster
        : widget.posterPath;
    final backdropUrl = (_detail?.poster != null && _detail!.poster.isNotEmpty)
        ? _detail!.poster
        : effectivePoster;
    final displayTitle = _detail?.title ?? widget.title;
    final isSeries = _detail?.type == 'series';
    final rating = _detail?.rating ?? '7.0/10.0';
    final desc = _detail?.plot ?? 'Loading description...';
    final episodes = _detail?.episodes ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Skeletonizer(
        enabled: _isLoading,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero Backdrop & Top Bar
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Backdrop Image
                  SizedBox(
                    height: 380,
                    width: double.infinity,
                    child: backdropUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: backdropUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
                            errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
                          )
                        : Container(color: const Color(0xFF1E1E1E)),
                  ),

                  // Gradient Fades
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 0.75, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Action Bar
                  Positioned(
                    top: topPadding + 6,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                        ),
                        Row(
                          children: [
                            // 1. Casting
                            IconButton(
                              onPressed: _showCastSheet,
                              tooltip: 'Cast Media',
                              icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 22),
                            ),
                            // 2. Heart (Favorites / Watch Status)
                            IconButton(
                              onPressed: _onToggleWatchStatus,
                              tooltip: 'Watch Status: $_watchStatus',
                              icon: Icon(
                                _watchStatus != 'None'
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _watchStatus != 'None'
                                    ? Colors.redAccent
                                    : Colors.white,
                                size: 22,
                              ),
                            ),
                            // 3. Search icon to search all providers for this title
                            IconButton(
                              onPressed: _openGlobalSearch,
                              tooltip: 'Search all providers',
                              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 23),
                            ),
                            // 4. Provider Source Link
                            IconButton(
                              onPressed: _openProviderRootLink,
                              tooltip: 'Open in Provider (${widget.providerName})',
                              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 22),
                            ),
                            // 5. Share
                            IconButton(
                              onPressed: _shareMedia,
                              tooltip: 'Share',
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 21),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Metadata Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges row: [VegaMovies ↗] [Series/Movie] [6.7/10.0]
                    Row(
                      children: [
                        InkWell(
                          onTap: _openProviderRootLink,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.providerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSeries ? 'Series' : 'Movie',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Overview / Synopsis
                    Text(
                      desc,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cast
                    if (_detail?.cast.isNotEmpty == true) ...[
                      Text(
                        'Cast: ${_detail!.cast.take(5).join(', ')}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // For Movie: Large Play & Download Buttons
                    if (!isSeries) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isExtractingMovie ? null : _playMovie,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isExtractingMovie
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.play_arrow_rounded, size: 24),
                              label: const Text(
                                'Play Movie',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // Episode Header Tab
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${episodes.length} Episodes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white70, size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // Episodes List for Series
            if (isSeries)
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: bottomPadding + 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ep = episodes[index];
                      final isExtracting = _extractingEpisodeIndex == index;
                      final epThumb = (ep.poster != null && ep.poster!.isNotEmpty)
                          ? ep.poster!
                          : backdropUrl;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail with Play overlay
                            GestureDetector(
                              onTap: () => _playEpisode(ep, index),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 110,
                                      height: 68,
                                      child: epThumb.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: epThumb,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(color: const Color(0xFF222222)),
                                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF222222)),
                                            )
                                          : Container(color: const Color(0xFF222222)),
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: isExtracting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Episode Info & Direct Download
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ep.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ep.description ?? 'Tap to play or download',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () => _playEpisode(ep, index),
                              icon: const Icon(Icons.file_download_outlined, color: Colors.white70, size: 22),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: episodes.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
