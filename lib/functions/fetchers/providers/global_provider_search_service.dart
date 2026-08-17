import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'provider_config.dart';
import 'media_provider_service.dart';
import 'vega_movies_provider.dart';

/// Represents search results returned by a single provider
class ProviderSearchResultSection {
  final String providerId;
  final String providerName;
  final List<VegaMediaItem> items;
  final bool isLoading;
  final String? error;

  const ProviderSearchResultSection({
    required this.providerId,
    required this.providerName,
    required this.items,
    this.isLoading = false,
    this.error,
  });

  ProviderSearchResultSection copyWith({
    String? providerId,
    String? providerName,
    List<VegaMediaItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return ProviderSearchResultSection(
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Global multi-provider search engine matching CloudStream search architecture
class GlobalProviderSearchService {
  static const String _userAgent = ProviderConfig.defaultUserAgent;

  /// Search a single provider by ID and query
  static Future<List<VegaMediaItem>> searchProvider(
    String providerId,
    String query, {
    int page = 1,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final id = providerId.toLowerCase();
    final baseUrl = await ProviderConfig.resolveBaseUrl(id);
    if (baseUrl.isEmpty) return [];

    try {
      // 1. Try search.php (Typesense / Meilisearch / JSON engine used by VegaMovies, MoviesDrive, Moviesmod, UHDMovies)
      try {
        final searchPhpUrl = '$baseUrl/search.php?q=${Uri.encodeComponent(cleanQuery)}&page=$page';
        final response = await http.get(
          Uri.parse(searchPhpUrl),
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
          final Map<String, dynamic> jsonMap = json.decode(response.body);
          if (jsonMap.containsKey('hits') && jsonMap['hits'] is List) {
            final List hits = jsonMap['hits'];
            final List<VegaMediaItem> items = [];

            for (final hit in hits) {
              if (hit is Map && hit.containsKey('document')) {
                final doc = hit['document'];
                final rawTitle = (doc['post_title'] ?? doc['postTitle'] ?? doc['title'] ?? '').toString();
                final rawThumb = (doc['post_thumbnail'] ?? doc['postThumbnail'] ?? doc['poster'] ?? '').toString();
                var permalink = (doc['permalink'] ?? doc['url'] ?? '').toString();

                if (permalink.isNotEmpty && !permalink.startsWith('http')) {
                  if (permalink.startsWith('/')) {
                    permalink = '$baseUrl$permalink';
                  } else {
                    permalink = '$baseUrl/$permalink';
                  }
                }

                if (rawTitle.isNotEmpty && permalink.isNotEmpty) {
                  final title = rawTitle
                      .replaceAll(RegExp(r'Download\s*', caseSensitive: false), '')
                      .replaceAll(RegExp(r'\s*\(\d{4}\).*'), '')
                      .split('|').first
                      .trim();

                  final seasonMatch = RegExp(r'(S\d{1,2}(?:\s*-\s*S\d{1,2}|E\d{1,2})?)', caseSensitive: false).firstMatch(rawTitle);
                  final episodeBadge = seasonMatch?.group(1)?.toUpperCase();

                  items.add(
                    VegaMediaItem(
                      title: title,
                      posterPath: rawThumb,
                      permalink: permalink,
                      episodeBadge: episodeBadge,
                      id: ProviderConfig.getStableMediaId(permalink),
                    ),
                  );
                }
              }
            }

            if (items.isNotEmpty) {
              return items;
            }
          }
        }
      } catch (_) {}

      // 2. Fallback: WordPress standard search URL (/?s=query or /search/query/page/1/)
      final searchUrls = [
        '$baseUrl/?s=${Uri.encodeComponent(cleanQuery)}',
        '$baseUrl/search/${Uri.encodeComponent(cleanQuery)}/page/$page/',
      ];

      for (final sUrl in searchUrls) {
        try {
          final response = await http.get(
            Uri.parse(sUrl),
            headers: {'User-Agent': _userAgent},
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final document = parser.parse(response.body);
            final allLinks = document.querySelectorAll('a');
            final List<VegaMediaItem> items = [];
            final Set<String> seenPermalinks = {};

            for (final a in allLinks) {
              final img = a.querySelector('img');
              if (img == null) continue;

              var href = a.attributes['href'] ?? '';
              if (href.isEmpty || href == '#' || href == '/' || href == baseUrl || href == '$baseUrl/') continue;
              if (href.contains('/category/') || href.contains('/page/') || href.contains('/author/') || href.contains('/feed/')) continue;
              if (seenPermalinks.contains(href)) continue;

              var alt = img.attributes['alt'] ?? a.attributes['title'] ?? a.text.trim();
              var title = alt
                  .replaceAll(RegExp(r'Download\s*', caseSensitive: false), '')
                  .replaceAll(RegExp(r'\s*\(\d{4}\).*'), '')
                  .split('|').first
                  .trim();
              if (title.isEmpty || title.length < 2 || title.toLowerCase().contains('official') || title.toLowerCase().contains('telegram')) continue;

              var posterUrl = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
              if (posterUrl.isEmpty || !posterUrl.startsWith('http')) {
                posterUrl = img.attributes['data-lazy-src'] ?? img.attributes['data-src'] ?? '';
              }
              if (posterUrl.startsWith('//')) {
                posterUrl = 'https:$posterUrl';
              }
              if (posterUrl.isEmpty || posterUrl.contains('logo') || posterUrl.contains('icon')) continue;

              seenPermalinks.add(href);

              final seasonMatch = RegExp(r'(S\d{1,2}(?:\s*-\s*S\d{1,2}|E\d{1,2})?)', caseSensitive: false).firstMatch(alt);
              final episodeBadge = seasonMatch?.group(1)?.toUpperCase();
              final id = ProviderConfig.getStableMediaId(href);

              items.add(
                VegaMediaItem(
                  title: title,
                  posterPath: posterUrl,
                  permalink: href,
                  episodeBadge: episodeBadge,
                  id: id,
                ),
              );
            }

            if (items.isNotEmpty) {
              return items;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [GlobalSearch] Error searching provider $providerId: $e');
    }

    return [];
  }

  /// Concurrently search all providers and yield results dynamically per provider
  static Stream<ProviderSearchResultSection> searchAllProvidersStream(
    String query, {
    List<String>? selectedProviders,
  }) async* {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // Get live dynamic providers list
    final providers = await MediaProviderService.fetchProviders();
    final targetProviders = providers.where((p) {
      final id = p.id.toLowerCase();
      if (id == 'none' || id == 'random') return false;
      if (selectedProviders != null && selectedProviders.isNotEmpty) {
        return selectedProviders.contains(id);
      }
      return true;
    }).toList();

    // Stream controller to emit each provider's result as soon as ready
    final controller = StreamController<ProviderSearchResultSection>();
    int pendingCount = targetProviders.length;

    if (pendingCount == 0) {
      controller.close();
      return;
    }

    for (final provider in targetProviders) {
      // Fire search concurrently
      searchProvider(provider.id, cleanQuery).then((items) {
        if (!controller.isClosed) {
          controller.add(
            ProviderSearchResultSection(
              providerId: provider.id,
              providerName: provider.name,
              items: items,
              isLoading: false,
            ),
          );
        }
      }).catchError((err) {
        if (!controller.isClosed) {
          controller.add(
            ProviderSearchResultSection(
              providerId: provider.id,
              providerName: provider.name,
              items: [],
              isLoading: false,
              error: err.toString(),
            ),
          );
        }
      }).whenComplete(() {
        pendingCount--;
        if (pendingCount == 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    yield* controller.stream;
  }
}
