import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:mxstream/services/api_client.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:mxstream/functions/fetchers/fetch_serie_details.dart';
import 'package:mxstream/functions/get_base_url.dart';
import 'package:mxstream/functions/regionprovider_class.dart';
import 'package:mxstream/seriesPage/models/serie.dart';
import 'package:mxstream/seriesPage/serieDetailPage.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/m3_expressive_spinner.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';

class WatchlistCalendarScreen extends StatefulWidget {
  const WatchlistCalendarScreen({Key? key}) : super(key: key);

  @override
  State<WatchlistCalendarScreen> createState() => _WatchlistCalendarScreenState();
}

class _WatchlistCalendarScreenState extends State<WatchlistCalendarScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Serie> _watchlistSeries = [];

  @override
  void initState() {
    super.initState();
    _fetchWatchlistAndDetails();
  }

  Future<void> _fetchWatchlistAndDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final openbox = Hive.box('sessionBox');
      final String? accountId = openbox.get('accountId');
      final String? sessionData = openbox.get('sessionData');
      final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
      final apiKey = dotenv.env['TMDB_API_KEY'];
      final baseUrl = getBaseUrl(region);

      if (accountId == null || sessionData == null || apiKey == null) {
        throw Exception('User session or API Key not found');
      }

      // Fetch all pages of TV watchlist
      final response = await apiClient.get(
        Uri.parse('${baseUrl}account/$accountId/watchlist/tv?api_key=$apiKey&session_id=$sessionData&page=1'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load watchlist series');
      }

      final Map<String, dynamic> decoded = json.decode(response.body);
      final int totalPages = decoded['total_pages'] ?? 1;
      final List<Serie> basicSeries = [];
      void addResults(List<dynamic> results) {
        for (var result in results) {
          basicSeries.add(Serie(
            name: result['name'],
            posterPath: result['poster_path'] ?? '',
            overView: result['overview'] ?? '',
            id: result['id'],
            score: (result['vote_average'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      addResults(decoded['results'] as List<dynamic>? ?? []);

      if (totalPages > 1) {
        const pageConcurrency = 4;
        for (var start = 2; start <= totalPages; start += pageConcurrency) {
          final end = start + pageConcurrency - 1 > totalPages
              ? totalPages
              : start + pageConcurrency - 1;
          final pages = List.generate(end - start + 1, (i) => start + i);
          final pageBodies = await Future.wait(pages.map((page) async {
            final pageResponse = await apiClient.get(
              Uri.parse('${baseUrl}account/$accountId/watchlist/tv?api_key=$apiKey&session_id=$sessionData&page=$page'),
            );
            if (pageResponse.statusCode != 200) {
              throw Exception('Failed to load watchlist series');
            }
            return json.decode(pageResponse.body)['results'] as List<dynamic>? ?? [];
          }));
          for (final results in pageBodies) {
            addResults(results);
          }
        }
      }

      if (!mounted) return;

      // Fetch details for all series in parallel (fault tolerant)
      final List<Future<Map<String, dynamic>>> detailFutures = basicSeries.map((serie) async {
        try {
          return await fetchSerieDetails(serie.id, region);
        } catch (e) {
          // If details fetch fails for one show, return empty map to prevent breaking the whole screen
          return <String, dynamic>{};
        }
      }).toList();

      final List<Map<String, dynamic>> allSerieDetails = await Future.wait(detailFutures);

      final List<Serie> detailedSeries = [];
      for (var i = 0; i < basicSeries.length; i++) {
        final serie = basicSeries[i];
        final serieDetails = allSerieDetails[i];

        if (serieDetails.isEmpty) {
          // Keep basic serie if details failed
          detailedSeries.add(serie);
          continue;
        }

        final nextEpisode = serieDetails['next_episode_to_air'];
        final String? nextAirDate = nextEpisode?['air_date'];
        final int? nextEpisodeSeasonNumber = nextEpisode?['season_number'];
        final int? nextEpisodeEpisodeNumber = nextEpisode?['episode_number'];
        final String? nextEpisodeName = nextEpisode?['name'];

        final serieLatestAir = serieDetails['last_air_date'];
        final serieLastEpisodeSeasonNumber = serieDetails['last_episode_to_air']?['season_number'];
        final serieLastEpisodeEpisodeNumber = serieDetails['last_episode_to_air']?['episode_number'];

        detailedSeries.add(Serie(
          name: serie.name,
          posterPath: serie.posterPath,
          overView: serie.overView,
          id: serie.id,
          score: serie.score,
          backdropPath: serieDetails['backdrop_path'] ?? serie.backdropPath,
          lastAirDate: serieLatestAir,
          lastEpisodeSeasonNumber: serieLastEpisodeSeasonNumber,
          lastEpisodeEpisodeNumber: serieLastEpisodeEpisodeNumber,
          nextAirDate: nextAirDate,
          nextEpisodeSeasonNumber: nextEpisodeSeasonNumber,
          nextEpisodeEpisodeNumber: nextEpisodeEpisodeNumber,
          nextEpisodeName: nextEpisodeName,
        ));
      }

      if (!mounted) return;

      setState(() {
        _watchlistSeries = detailedSeries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String friendlyMessage = 'Something went wrong. Please try again.';
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Connection failed')) {
        friendlyMessage = 'Network connection error. Please check your internet connection and try again.';
      } else if (errStr.contains('User session') || errStr.contains('API Key')) {
        friendlyMessage = 'Authentication or session error. Please log in again.';
      } else {
        friendlyMessage = errStr.replaceAll('Exception: ', '');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = friendlyMessage;
      });
    }
  }

  DateTime? _parseAirDate(String? airDateStr) {
    if (airDateStr == null || airDateStr.isEmpty) return null;
    try {
      final parts = airDateStr.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  Widget _buildUpcomingListView(BuildContext context, String region) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Filter and sort future episodes
    final upcomingSeries = _watchlistSeries.where((s) {
      final airDate = _parseAirDate(s.nextAirDate);
      if (airDate == null) return false;
      return !airDate.isBefore(today);
    }).toList();

    // Sort ascending
    upcomingSeries.sort((a, b) {
      final dateA = _parseAirDate(a.nextAirDate)!;
      final dateB = _parseAirDate(b.nextAirDate)!;
      return dateA.compareTo(dateB);
    });

    if (upcomingSeries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tv_off, color: Theme.of(context).primaryColor.withValues(alpha: 0.4), size: 48),
              const SizedBox(height: 12),
              const Text(
                'No future episodes scheduled in your watchlist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    // Group shows by air date
    final Map<String, List<Serie>> grouped = {};
    for (var s in upcomingSeries) {
      final dateStr = s.nextAirDate!;
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(s);
    }

    final sortedDates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: TvFocusModeManager.isTvDevice ? 16.0 : BottomBar.getHeight(context),
      ),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateStr = sortedDates[dateIndex];
        final date = _parseAirDate(dateStr)!;
        final list = grouped[dateStr]!;

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        final String formattedDate = DateFormat('EEEE, MMM d, yyyy').format(date);
        final int difference = date.difference(today).inDays;
        final bool isDateToday = difference == 0;
        final bool isDateTomorrow = difference == 1;

        String remainingText = '';
        Color badgeBgColor;
        Color badgeFgColor;

        if (isDateToday) {
          remainingText = 'Today';
          badgeBgColor = colorScheme.primaryContainer;
          badgeFgColor = colorScheme.onPrimaryContainer;
        } else if (isDateTomorrow) {
          remainingText = 'Tomorrow';
          badgeBgColor = colorScheme.secondaryContainer;
          badgeFgColor = colorScheme.onSecondaryContainer;
        } else {
          remainingText = 'In $difference days';
          badgeBgColor = colorScheme.surfaceContainerHigh;
          badgeFgColor = colorScheme.onSurfaceVariant;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDateToday ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDateToday) ...[
                          Icon(Icons.today_rounded, size: 13, color: badgeFgColor),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          remainingText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: badgeFgColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...list.map((serie) => _buildEpisodeTile(context, serie, region)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEpisodeTile(BuildContext context, Serie serie, String region) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayEpisodeCode = serie.nextEpisodeSeasonNumber != null && serie.nextEpisodeEpisodeNumber != null
        ? 'S${serie.nextEpisodeSeasonNumber.toString().padLeft(2, '0')}E${serie.nextEpisodeEpisodeNumber.toString().padLeft(2, '0')}'
        : '';
    final episodeName = serie.nextEpisodeName != null && serie.nextEpisodeName!.isNotEmpty
        ? ' - "${serie.nextEpisodeName}"'
        : '';

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: serie.posterPath.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: '${getImageBaseUrl(region)}/t/p/w185${serie.posterPath}',
                  width: 48,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHigh),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.tv_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                  ),
                )
              : Container(
                  color: colorScheme.surfaceContainerHigh,
                  width: 48,
                  height: 72,
                  child: Icon(Icons.tv_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                ),
        ),
        title: Text(
          serie.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '$displayEpisodeCode$episodeName',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_rounded, color: colorScheme.onSurfaceVariant, size: 18),
        onTap: () {
          Navigator.push(
            context,
            ExpressivePageRoute(
              page: SerieDetailPage(serieName: serie.name, serieId: serie.id),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context).currentRegion;

    Widget body;
    if (_isLoading) {
      body = const M3ExpressiveSpinner();
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _fetchWatchlistAndDetails,
              ),
            ],
          ),
        ),
      );
    } else {
      body = _buildUpcomingListView(context, region);
    }

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
          'Upcoming Episodes',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: body,
    );
  }

}
