import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mxstream/services/api_client.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webfeed_plus/domain/rss_category.dart';
import 'package:webfeed_plus/domain/rss_feed.dart';

class RssScreen extends StatefulWidget {
  const RssScreen({Key? key}) : super(key: key);

  @override
  _RssScreenState createState() => _RssScreenState();
}

class _RssScreenState extends State<RssScreen> with TickerProviderStateMixin {
  late Future<RssFeed> _feedFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(Uri url) async {
    if (await canLaunchUrlString(url.toString())) {
      await launchUrlString(url.toString());
    } else {
      throw Exception('Could not launch url');
    }
  }

  Future<RssFeed> _loadFeed() async {
    final response = await apiClient.get(Uri.parse('https://www.scnsrc.me/feed'));
    if (response.statusCode == 200) {
      return RssFeed.parse(response.body);
    } else {
      throw Exception('Failed to load RSS feed');
    }
  }

  Widget _getCategoryIcon(List<RssCategory>? categories) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (categories != null) {
      for (var category in categories) {
        if (category.value.contains("Movies")) {
          return Icon(Icons.movie_outlined, color: colorScheme.primary);
        } else if (category.value.contains("TV")) {
          return Icon(Icons.tv_outlined, color: colorScheme.primary);
        }
      }
    }
    return Icon(Icons.rss_feed_rounded, color: colorScheme.onSurfaceVariant);
  }

  Widget _buildFeedList(RssFeed feed, String category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredItems = feed.items!.where((item) {
      final categories = item.categories ?? [];
      return categories.any((cat) => cat.value.contains(category));
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 12.0,
        bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _getCategoryIcon(item.categories),
            ),
            title: Text(
              item.title ?? '',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: item.pubDate != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      item.pubDate.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
            trailing: Icon(Icons.arrow_forward_rounded, color: colorScheme.onSurfaceVariant, size: 18),
            onTap: () {
              if (item.link != null) {
                _launchUrl(Uri.parse(item.link!));
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'RSS Feed',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                labelColor: colorScheme.onPrimaryContainer,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: colorScheme.primaryContainer,
                ),
                tabs: const [
                  Tab(text: 'Movies'),
                  Tab(text: 'TV Shows'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(),
          scrollbars: true,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: FutureBuilder<RssFeed>(
          future: _feedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading RSS feed',
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            } else {
              final feed = snapshot.requireData;
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedList(feed, "Movies"),
                  _buildFeedList(feed, "TV"),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

