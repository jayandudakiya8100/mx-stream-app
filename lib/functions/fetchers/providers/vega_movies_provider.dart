import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:flutter/foundation.dart';
import 'package:Mirarr/moviesPage/models/movie.dart';
import 'package:Mirarr/functions/fetchers/providers/media_provider_service.dart';
import 'provider_config.dart';

/// Model for VegaMediaItem on Home shelves
class VegaMediaItem {
  final String title;
  final String posterPath;
  final String permalink;
  final String? episodeBadge;
  final double score;
  final int id;

  const VegaMediaItem({
    required this.title,
    required this.posterPath,
    required this.permalink,
    this.episodeBadge,
    this.score = 7.5,
    required this.id,
  });

  Movie toMovie() {
    return Movie(
      title: title,
      releaseDate: '',
      posterPath: posterPath,
      backdropPath: posterPath,
      overView: episodeBadge ?? '',
      id: id,
      score: score,
    );
  }
}

class VegaShelfSection {
  final String title;
  final String categoryPath;
  final List<VegaMediaItem> items;

  const VegaShelfSection({
    required this.title,
    required this.categoryPath,
    required this.items,
  });
}

class VegaHomePageData {
  final List<VegaMediaItem> hero;
  final List<VegaShelfSection> shelves;

  const VegaHomePageData({
    required this.hero,
    required this.shelves,
  });

  List<VegaMediaItem> get home => shelves.isNotEmpty ? shelves.first.items : [];
  List<VegaMediaItem> get netflix => shelves.length > 1 ? shelves[1].items : [];
  List<VegaMediaItem> get disney => shelves.length > 2 ? shelves[2].items : [];
  List<VegaMediaItem> get prime => shelves.length > 3 ? shelves[3].items : [];
}

class VegaEpisodeItem {
  final int season;
  final int episode;
  final String title;
  final String? description;
  final String? thumbnail;
  final String url;

  VegaEpisodeItem({
    required this.season,
    required this.episode,
    required this.title,
    this.description,
    this.thumbnail,
    required this.url,
  });
}

class VegaMediaDetail {
  final String title;
  final String poster;
  final String backdrop;
  final String description;
  final List<String> cast;
  final List<String> genres;
  final String rating;
  final String year;
  final bool isSeries;
  final List<VegaEpisodeItem> episodes;
  final List<StreamLink> movieStreams;

  VegaMediaDetail({
    required this.title,
    required this.poster,
    required this.backdrop,
    required this.description,
    required this.cast,
    required this.genres,
    required this.rating,
    required this.year,
    required this.isSeries,
    required this.episodes,
    required this.movieStreams,
  });
}

/// Model for a stream link result
class StreamLink {
  final String name;
  final String streamUrl;
  final String quality;

  StreamLink({
    required this.name,
    required this.streamUrl,
    required this.quality,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'streamUrl': streamUrl,
        'quality': quality,
      };
}

/// VegaMovies search response models
class VegaDocument {
  final String id;
  final String? imdbId;
  final String postTitle;
  final String permalink;
  final String postThumbnail;

  VegaDocument({
    required this.id,
    this.imdbId,
    required this.postTitle,
    required this.permalink,
    required this.postThumbnail,
  });

  factory VegaDocument.fromJson(Map<String, dynamic> json) {
    return VegaDocument(
      id: json['id']?.toString() ?? '',
      imdbId: json['imdb_id'],
      postTitle: json['post_title'] ?? '',
      permalink: json['permalink'] ?? '',
      postThumbnail: json['post_thumbnail'] ?? '',
    );
  }
}

class VegaHit {
  final VegaDocument document;

  VegaHit({required this.document});

  factory VegaHit.fromJson(Map<String, dynamic> json) {
    return VegaHit(
      document: VegaDocument.fromJson(json['document']),
    );
  }
}

class VegaSearchResponse {
  final List<VegaHit> hits;

  VegaSearchResponse({required this.hits});

  factory VegaSearchResponse.fromJson(Map<String, dynamic> json) {
    return VegaSearchResponse(
      hits: (json['hits'] as List).map((h) => VegaHit.fromJson(h)).toList(),
    );
  }
}

class VegaMoviesProvider {
  static const String _userAgent = ProviderConfig.defaultUserAgent;
  static const String _cinemetaUrl = ProviderConfig.cinemetaUrl;

  /// Fetch the latest active base URL from centralized ProviderConfig
  static Future<String> _getLatestBaseUrl([String providerKey = 'vegamovies']) async {
    return ProviderConfig.resolveBaseUrl(providerKey);
  }

  /// Scrape elements from a category page with universal anchor-image matcher
  static Future<List<VegaMediaItem>> _scrapeCategoryPage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final List<VegaMediaItem> items = [];
      final Set<String> seenPermalinks = {};

      // Collect any hero slider links on this page to prevent overlap/duplicates
      final heroLinks = document
          .querySelectorAll('.hsl-slide a, .hero-slide a, div[class*="slide"] a, #hero-slider a, .featured-slider a')
          .map((e) => e.attributes['href'] ?? '')
          .where((h) => h.isNotEmpty)
          .toSet();

      // Match all <a> links containing an <img> tag (covers all WordPress movie themes)
      final allLinks = document.querySelectorAll('a');

      for (final a in allLinks) {
        final img = a.querySelector('img');
        if (img == null) continue;

        var href = a.attributes['href'] ?? '';
        if (href.isEmpty || href == '#' || href == '/' || href.contains('/category/') || href.contains('/page/') || href.contains('/author/')) continue;
        if (heroLinks.contains(href)) continue; // Skip hero banner duplicates
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

        // Extract Season/Episode tag if in title (e.g. S01, S02, S1-S3)
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

      return items;
    } catch (_) {
      return [];
    }
  }

  /// Scrape hero banner slides from VegaMovies
  static Future<List<VegaMediaItem>> _scrapeHeroSlides(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final slides = document.querySelectorAll('.hsl-slide, .hero-slide, div[class*="slide"]');
      final List<VegaMediaItem> heroItems = [];
      final Set<String> seenHeroLinks = {};

      for (final slide in slides) {
        final a = slide.querySelector('.hsl-title a') ?? slide.querySelector('h2 a') ?? slide.querySelector('.hsl-bg a') ?? slide.querySelector('a');
        final img = slide.querySelector('.hsl-bg img') ?? slide.querySelector('img');
        final href = a?.attributes['href'] ?? '';
        final title = slide.querySelector('.hsl-title')?.text.trim() ?? a?.text.trim() ?? img?.attributes['alt'] ?? '';
        final poster = img?.attributes['src'] ?? img?.attributes['data-src'] ?? '';

        if (title.isNotEmpty && href.isNotEmpty && !seenHeroLinks.contains(href)) {
          seenHeroLinks.add(href);
          heroItems.add(
            VegaMediaItem(
              title: title.replaceAll(RegExp(r'Download\s*', caseSensitive: false), '').trim(),
              posterPath: poster,
              permalink: href,
              id: ProviderConfig.getStableMediaId(href),
            ),
          );
        }
      }

      return heroItems;
    } catch (_) {
      return [];
    }
  }

  /// Fetch all Home Screen content shelves for any provider
  static Future<VegaHomePageData> fetchHomePageContent([String provider = 'vegamovies', String? customBaseUrl]) async {
    final providerId = provider.toLowerCase();
    String baseUrl = customBaseUrl ?? await _getLatestBaseUrl(providerId);

    if (providerId == 'bollyflix') {
      final futures = await Future.wait([
        _scrapeHeroSlides(baseUrl),
        _scrapeCategoryPage('$baseUrl/page/1/'),
        _scrapeCategoryPage('$baseUrl/movies/bollywood/page/1/'),
        _scrapeCategoryPage('$baseUrl/movies/hollywood/page/1/'),
        _scrapeCategoryPage('$baseUrl/anime/page/1/'),
      ]);

      final hero = futures[0].isNotEmpty ? futures[0] : futures[1].take(6).toList();
      return VegaHomePageData(
        hero: hero,
        shelves: [
          VegaShelfSection(title: 'Latest Releases', categoryPath: '/page/1/', items: futures[1]),
          VegaShelfSection(title: 'Bollywood', categoryPath: '/movies/bollywood/page/1/', items: futures[2]),
          VegaShelfSection(title: 'Hollywood', categoryPath: '/movies/hollywood/page/1/', items: futures[3]),
          VegaShelfSection(title: 'Anime', categoryPath: '/anime/page/1/', items: futures[4]),
        ].where((s) => s.items.isNotEmpty).toList(),
      );
    }

    if (providerId == 'moviesdrive') {
      final futures = await Future.wait([
        _scrapeHeroSlides(baseUrl),
        _scrapeCategoryPage('$baseUrl/page/1/'),
        _scrapeCategoryPage('$baseUrl/category/web-series/'),
        _scrapeCategoryPage('$baseUrl/category/bollywood/'),
        _scrapeCategoryPage('$baseUrl/category/hollywood/'),
      ]);

      final hero = futures[0].isNotEmpty ? futures[0] : futures[1].take(6).toList();
      return VegaHomePageData(
        hero: hero,
        shelves: [
          VegaShelfSection(title: 'Latest Releases', categoryPath: '/page/1/', items: futures[1]),
          VegaShelfSection(title: 'Web Series', categoryPath: '/category/web-series/', items: futures[2]),
          VegaShelfSection(title: 'Bollywood', categoryPath: '/category/bollywood/', items: futures[3]),
          VegaShelfSection(title: 'Hollywood', categoryPath: '/category/hollywood/', items: futures[4]),
        ].where((s) => s.items.isNotEmpty).toList(),
      );
    }

    // Default: Scrape all VegaMovies categories dynamically
    final mirror = baseUrl.isNotEmpty ? baseUrl : await _getLatestBaseUrl(providerId);

    // Dynamic category definitions based on VegaMovies taxonomy
    final categories = [
      {'title': 'Latest Releases', 'path': '/'},
      {'title': 'Netflix Series', 'path': '/category/web-series/netflix/'},
      {'title': 'Disney Plus Hotstar', 'path': '/category/web-series/disney-plus-hotstar/'},
      {'title': 'Amazon Prime Video', 'path': '/category/web-series/amazon-prime-video/'},
      {'title': 'Korean Series', 'path': '/category/korean-series/'},
      {'title': 'Anime Series', 'path': '/category/anime-series/'},
      {'title': 'MX Original', 'path': '/category/web-series/mx-original/'},
    ];

    debugPrint('📡 [VegaMovies] Fetching Hero Banner & ${categories.length} Category Shelves from $mirror...');

    // Fetch hero banner and all categories concurrently
    final heroFuture = _scrapeHeroSlides(mirror);
    final categoryFutures = categories.map((cat) async {
      final path = cat['path']!;
      final fullUrl = path == '/' ? '$mirror/' : '$mirror$path';
      final items = await _scrapeCategoryPage(fullUrl);
      return VegaShelfSection(
        title: cat['title']!,
        categoryPath: path,
        items: items,
      );
    }).toList();

    final results = await Future.wait([
      heroFuture,
      ...categoryFutures,
    ]);

    List<VegaMediaItem> heroItems = results[0] as List<VegaMediaItem>;
    List<VegaShelfSection> shelves = results.sublist(1).cast<VegaShelfSection>();

    // Keep only non-empty shelves
    shelves = shelves.where((s) => s.items.isNotEmpty).toList();

    if (heroItems.isEmpty && shelves.isNotEmpty) {
      heroItems = shelves.first.items.take(6).toList();
    }

    debugPrint('🎉 [VegaMovies Complete] Fetched ${heroItems.length} Hero items and ${shelves.length} populated category shelves');
    for (final s in shelves) {
      debugPrint('   • [${s.title}]: ${s.items.length} items');
    }

    return VegaHomePageData(
      hero: heroItems,
      shelves: shelves,
    );
  }

  /// Fetch next page of content for pagination with clear console logging
  static Future<List<VegaMediaItem>> fetchPage({
    String provider = 'vegamovies',
    required int page,
    String? customBaseUrl,
  }) async {
    final providerId = provider.toLowerCase();
    final baseUrl = customBaseUrl ?? await _getLatestBaseUrl(providerId);
    final pageUrl = '$baseUrl/page/$page/';

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📄 [Pagination Fetch] Requesting Page #$page');
    debugPrint('🔗 [Pagination URL]: $pageUrl');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final items = await _scrapeCategoryPage(pageUrl);

    debugPrint('✅ [Pagination Success] Page #$page loaded ${items.length} new items from: $pageUrl');
    return items;
  }

  /// Scrape full media details (synopsis, cast, episodes, streaming links)
  static Future<VegaMediaDetail?> fetchMediaDetails(String pageUrl) async {
    try {
      final baseUrl = await _getLatestBaseUrl();
      var fullUrl = pageUrl;
      if (!fullUrl.startsWith('http')) {
        fullUrl = '$baseUrl/${fullUrl.startsWith('/') ? fullUrl.substring(1) : fullUrl}';
      }

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final document = parser.parse(response.body);

      var title = document.querySelector('title')?.text ?? '';
      title = title.replaceAll(RegExp(r'Download\s*', caseSensitive: false), '').split('|').first.trim();

      // Multi-selector image extraction for poster
      var posterUrl = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
          document.querySelector('meta[name="twitter:image"]')?.attributes['content'] ??
          '';

      if (posterUrl.isEmpty) {
        final imgEl = document.querySelector('.entry-content img, article img, p img, .post-thumbnail img, img[src*="uploads"], img[src*="wp-content"]');
        posterUrl = imgEl?.attributes['src'] ??
            imgEl?.attributes['data-src'] ??
            imgEl?.attributes['data-lazy-src'] ??
            imgEl?.attributes['data-cfsrc'] ??
            imgEl?.attributes['data-original'] ??
            '';
      }

      if (posterUrl.startsWith('//')) {
        posterUrl = 'https:$posterUrl';
      }

      final imdbUrl = document.querySelector('a[href*="imdb.com/title/"]')?.attributes['href'] ?? '';
      String? imdbId;
      if (imdbUrl.isNotEmpty) {
        final match = RegExp(r'tt\d+').firstMatch(imdbUrl);
        imdbId = match?.group(0);
      }

      // Accurate Series vs Movie classification (CloudStream Kotlin reference)
      final isSeries = (RegExp(r'Series[- ]SYNOPSIS|Series Info|Series synopsis', caseSensitive: false).hasMatch(document.outerHtml) ||
              fullUrl.contains('/category/web-series/') ||
              fullUrl.contains('/category/anime-series/') ||
              fullUrl.contains('/category/korean-series/')) &&
          !document.outerHtml.contains('Movie-SYNOPSIS/PLOT');

      var description = '';
      List<String> cast = [];
      List<String> genres = [];
      String rating = '7.0/10.0';
      String year = '';
      String backdrop = posterUrl;

      // 1. Try Cinemeta by IMDB ID
      final tvtype = isSeries ? 'series' : 'movie';
      if (imdbId != null && imdbId.isNotEmpty) {
        try {
          final metaRes = await http.get(Uri.parse('$_cinemetaUrl/$tvtype/$imdbId.json')).timeout(const Duration(seconds: 4));
          if (metaRes.statusCode == 200) {
            final data = json.decode(metaRes.body)['meta'];
            if (data != null) {
              title = data['name'] ?? title;
              description = data['description'] ?? '';
              if (data['cast'] is List) {
                cast = List<String>.from(data['cast']);
              }
              if (data['genre'] is List) {
                genres = List<String>.from(data['genre']);
              }
              rating = '${data['imdbRating'] ?? '7.0'}/10.0';
              year = data['year']?.toString() ?? '';
              posterUrl = data['poster'] ?? posterUrl;
              backdrop = data['background'] ?? posterUrl;
            }
          }
        } catch (_) {}
      }

      // 2. Fallback Cinemeta search by title if backdrop or description is still empty
      if (backdrop.isEmpty || description.isEmpty) {
        try {
          final cleanTitle = title.replaceAll(RegExp(r'\s*\(\d{4}\).*'), '').trim();
          final searchRes = await http.get(
            Uri.parse('https://v3-cinemeta.strem.io/catalog/$tvtype/top/search=${Uri.encodeComponent(cleanTitle)}.json'),
          ).timeout(const Duration(seconds: 4));

          if (searchRes.statusCode == 200) {
            final metas = json.decode(searchRes.body)['metas'] as List?;
            if (metas != null && metas.isNotEmpty) {
              final first = metas.first;
              if (posterUrl.isEmpty) posterUrl = first['poster'] ?? '';
              if (backdrop.isEmpty) backdrop = first['background'] ?? posterUrl;
              if (description.isEmpty) description = first['description'] ?? '';
              if (genres.isEmpty && first['genres'] is List) {
                genres = List<String>.from(first['genres']);
              }
            }
          }
        } catch (_) {}
      }

      if (description.isEmpty) {
        final descEl = document.querySelector('h3 span, p strong, p');
        description = descEl?.text.trim() ?? 'No synopsis available.';
      }

      final List<VegaEpisodeItem> episodes = [];
      final List<StreamLink> movieStreams = [];

      if (isSeries) {
        // Find episode links within main content
        final contentEl = document.querySelector('.entry-content, article, main') ?? document;
        final aTags = contentEl.querySelectorAll('a');
        int epCounter = 1;
        final Set<String> seenEpisodeUrls = {};

        for (final a in aTags) {
          final text = a.text.trim();
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty || href == '#' || seenEpisodeUrls.contains(href)) continue;

          if (text.contains('Episode') || text.contains('V-Cloud') || text.contains('Download') || text.contains('E0') || text.contains('EP')) {
            final epMatch = RegExp(r'(?:Episode|EP|E)\s*(\d+)', caseSensitive: false).firstMatch(text);
            final epNum = epMatch != null ? int.tryParse(epMatch.group(1)!) ?? epCounter : epCounter;

            seenEpisodeUrls.add(href);
            episodes.add(
              VegaEpisodeItem(
                season: 1,
                episode: epNum,
                title: 'Episode $epNum',
                description: 'Watch or download Episode $epNum in high quality.',
                thumbnail: backdrop.isNotEmpty ? backdrop : posterUrl,
                url: href,
              ),
            );
            epCounter++;
          }
        }
      } else {
        // Extract movie direct links
        movieStreams.addAll(await fetchStreams(title));
      }

      return VegaMediaDetail(
        title: title,
        poster: posterUrl,
        backdrop: backdrop.isNotEmpty ? backdrop : posterUrl,
        description: description,
        cast: cast,
        genres: genres,
        rating: rating,
        year: year,
        isSeries: isSeries,
        episodes: episodes,
        movieStreams: movieStreams,
      );
    } catch (_) {
      return null;
    }
  }

  /// Search for the movie using search.php
  static Future<String?> _searchMovie(String mainUrl, String title) async {
    final searchUrl = '$mainUrl/search.php?q=${Uri.encodeComponent(title)}';

    try {
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return null;

      final searchResponse = VegaSearchResponse.fromJson(json.decode(response.body));
      if (searchResponse.hits.isEmpty) return null;

      final firstHit = searchResponse.hits.first;
      return firstHit.document.permalink;
    } catch (_) {
      return null;
    }
  }

  /// Load the movie page and find download buttons
  /// Kotlin reference (VegaMoviesProvider.kt lines 224-234):
  ///   val buttons = document.select("a:has(button.dwd-button)")
  ///   val data = buttons.mapNotNull { button ->
  ///       val link = fixUrl(button.attr("href"))
  ///       val doc = app.get(link).document
  ///       val source = doc.select("a:contains(V-Cloud)").attr("href")
  ///       EpisodeLink(source)
  ///   }
  static Future<List<String>> _getVCloudLinks(String moviePageUrl) async {
    try {
      final response = await http.get(
        Uri.parse(moviePageUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);

      // Select "a:has(button.dwd-button)" — find <a> tags that contain a <button class="dwd-button">
      final allLinks = document.querySelectorAll('a');
      final buttons = <Element>[];
      for (final a in allLinks) {
        final btn = a.querySelector('button.dwd-button');
        if (btn != null) {
          buttons.add(a);
        }
      }

      final List<String> vcloudLinks = [];

      for (final button in buttons) {
        var link = button.attributes['href'] ?? '';
        if (link.isEmpty) continue;

        // fixUrl: make relative URLs absolute
        if (!link.startsWith('http')) {
          final uri = Uri.parse(moviePageUrl);
          link = '${uri.scheme}://${uri.host}$link';
        }

        try {
          final doc2Response = await http.get(
            Uri.parse(link),
            headers: {'User-Agent': _userAgent},
          );

          if (doc2Response.statusCode != 200) continue;

          final doc2 = parser.parse(doc2Response.body);

          // Select "a:contains(V-Cloud)" — find <a> tags whose text contains "V-Cloud"
          final aTags = doc2.querySelectorAll('a');
          for (final a in aTags) {
            final text = a.text;
            final href = a.attributes['href'] ?? '';
            if (text.toLowerCase().contains('v-cloud') && href.isNotEmpty) {
              vcloudLinks.add(href);
            }
          }
        } catch (_) {
          continue;
        }
      }

      return vcloudLinks;
    } catch (_) {
      return [];
    }
  }

  /// Main entry point: fetch streams for a movie title
  static Future<List<StreamLink>> fetchStreams(String title) async {
    // Step 1: Get latest base URL
    final mainUrl = await _getLatestBaseUrl();

    // Step 2: Search for the movie
    final movieUrl = await _searchMovie(mainUrl, title);
    if (movieUrl == null) return [];

    // Step 3: Get V-Cloud links from movie page
    // The search API returns a relative path like "/download-xxx/"
    // so we need to make it absolute by prepending the base URL
    var fullMovieUrl = movieUrl;
    if (!movieUrl.startsWith('http')) {
      fullMovieUrl = mainUrl + (movieUrl.startsWith('/') ? movieUrl : '/$movieUrl');
    }
    final vcloudLinks = await _getVCloudLinks(fullMovieUrl);
    if (vcloudLinks.isEmpty) return [];

    // Step 4: Extract final stream URLs from V-Cloud
    final List<StreamLink> allStreams = [];

    for (final vcloudUrl in vcloudLinks) {
      final streams = await VCloudExtractor.extract(vcloudUrl);
      allStreams.addAll(streams);
    }

    return allStreams;
  }
}

/// VCloud extractor — translates Extractors.kt VCloud class
class VCloudExtractor {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const String _dynamicUrlsEndpoint =
      'https://raw.githubusercontent.com/SaurabhKaperwan/Utils/refs/heads/main/urls.json';

  static String _getBaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return url;
    }
  }

  static String _base64Decode(String input) {
    try {
      return utf8.decode(base64.decode(base64.normalize(input)));
    } catch (_) {
      return '';
    }
  }

  /// Kotlin: extractDoubleAtob
  static String? _extractDoubleAtob(String html) {
    final regex = RegExp(r"""var\s+url\s*=\s*atob\s*\(\s*atob\s*\(\s*['"]([^'"]+)['"]\s*\)\s*\)""");
    final match = regex.firstMatch(html);
    if (match != null) {
      final encoded = match.group(1)!;
      return _base64Decode(_base64Decode(encoded));
    }
    return null;
  }

  /// Kotlin: extractPxlUrl
  static String? _extractPxlUrl(String html) {
    final regex = RegExp(r"""var\s+pxl\s*=\s*['"]([^'"]+)['"]""");
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Resolve redirects manually (up to 7) using GET with 1-byte range
  static Future<String?> _resolveFinalUrl(String startUrl, {String? referer}) async {
    var currentUrl = startUrl;
    for (int i = 0; i < 7; i++) {
      try {
        final request = http.Request('GET', Uri.parse(currentUrl));
        request.headers['User-Agent'] = _userAgent;
        request.headers['Range'] = 'bytes=0-0';
        if (referer != null && referer.isNotEmpty) {
          request.headers['Referer'] = referer;
        }
        request.followRedirects = false;

        final client = http.Client();
        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 6));
        client.close();

        final statusCode = streamedResponse.statusCode;
        if (statusCode >= 300 && statusCode < 400) {
          final location = streamedResponse.headers['location'];
          if (location != null && location.isNotEmpty) {
            currentUrl = location.startsWith('http')
                ? location
                : (Uri.parse(currentUrl).origin + (location.startsWith('/') ? location : '/$location'));
            continue;
          }
        }
        break;
      } catch (_) {
        break;
      }
    }
    return currentUrl;
  }

  /// Get the latest base URL for vcloud/hubcloud
  static Future<String> _getLatestBaseUrl(String baseUrl, String source) async {
    try {
      final response = await http.get(Uri.parse(_dynamicUrlsEndpoint));
      if (response.statusCode == 200) {
        final Map<String, dynamic> urls = json.decode(response.body);
        final latestUrl = urls[source];
        if (latestUrl != null && latestUrl.toString().isNotEmpty) {
          return latestUrl;
        }
      }
    } catch (_) {
      // fallback
    }
    return baseUrl;
  }

  /// Main extraction logic — follows Extractors.kt getUrl() line by line
  static Future<List<StreamLink>> extract(String url) async {
    final List<StreamLink> links = [];
    try {
      var baseUrl = _getBaseUrl(url);

      // Get latest base URL
      final source = url.contains('hubcloud') ? 'hubcloud' : 'vcloud';
      final latestBaseUrl = await _getLatestBaseUrl(baseUrl, source);

      var newUrl = url;
      if (baseUrl != latestBaseUrl) {
        newUrl = url.replaceAll(baseUrl, latestBaseUrl);
        baseUrl = latestBaseUrl;
      }

      // Fetch VCloud page
      final response = await http.get(
        Uri.parse(newUrl),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return links;

      final document = parser.parse(response.body);
      String link = '';

      if (newUrl.contains('/video/')) {
        final aTag = document.querySelector('div.vd center a');
        link = aTag?.attributes['href'] ?? '';
      } else {
        final scripts = document.querySelectorAll('script');
        String scriptContent = '';
        for (final s in scripts) {
          if (s.text.contains('var url = atob') || s.text.contains("var url = '")) {
            scriptContent = s.text;
            break;
          }
        }

        if (newUrl.contains('vcloud')) {
          link = _extractDoubleAtob(scriptContent) ?? '';
        } else {
          final match = RegExp(r"var url = '([^']*)'").firstMatch(scriptContent);
          link = match?.group(1) ?? '';
        }
      }

      if (link.isEmpty) return links;

      if (!link.startsWith('https://')) {
        link = baseUrl + link;
      }

      // Fetch the resolved page with download buttons
      final resolvedResponse = await http.get(
        Uri.parse(link),
        headers: {'User-Agent': _userAgent, 'Referer': newUrl},
      );
      if (resolvedResponse.statusCode != 200) return links;

      final resolvedDoc = parser.parse(resolvedResponse.body);
      final header = resolvedDoc.querySelector('div.card-header')?.text.trim() ?? '';
      final size = resolvedDoc.querySelector('i#size')?.text.trim() ?? '';
      final qualityText = '$header [$size]';

      // 1. Check for embedded Pixeldrain link
      final pxlUrl = _extractPxlUrl(resolvedResponse.body);
      if (pxlUrl != null && pxlUrl.isNotEmpty) {
        final pxlId = pxlUrl.split('/').last.split('?').first;
        final directPxl = 'https://pixeldrain.com/api/file/$pxlId?download';
        links.add(StreamLink(name: 'Pixeldrain [High Speed Direct]', streamUrl: directPxl, quality: qualityText));
      }

      // 2. Process download buttons
      final buttons = resolvedDoc.querySelectorAll('h2 a.btn, a.btn');

      for (final button in buttons) {
        final btnLink = button.attributes['href'] ?? '';
        final text = button.text.trim();
        if (btnLink.isEmpty || btnLink == '#') continue;

        if (text.contains('FSL Server')) {
          links.add(StreamLink(name: 'V-Cloud [FSL Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('FSLv2')) {
          links.add(StreamLink(name: 'V-Cloud [FSLv2 Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('Mega Server')) {
          links.add(StreamLink(name: 'V-Cloud [Mega Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('Download File')) {
          links.add(StreamLink(name: 'V-Cloud [Direct Download]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('BuzzServer') || text.contains('Buzz Server')) {
          try {
            final buzzResponse = await http.get(
              Uri.parse('$btnLink/download'),
              headers: {'User-Agent': _userAgent, 'Referer': btnLink},
            );
            final dlink = buzzResponse.headers['hx-redirect'] ?? '';
            if (dlink.isNotEmpty) {
              final buzzBase = _getBaseUrl(btnLink);
              final directUrl = dlink.startsWith('http') ? dlink : (buzzBase + dlink);
              links.add(StreamLink(name: 'V-Cloud [BuzzServer]', streamUrl: directUrl, quality: qualityText));
            }
          } catch (_) {}
        } else if (btnLink.contains('pixeldra')) {
          final pixelLink = _extractPxlUrl(resolvedResponse.body);
          if (pixelLink != null && pixelLink.isNotEmpty) {
            final pixelBase = _getBaseUrl(pixelLink);
            final finalURL = pixelLink.toLowerCase().contains('download')
                ? pixelLink
                : '$pixelBase/api/file/${pixelLink.split('/').last}?download';
            links.add(StreamLink(name: 'V-Cloud [Pixeldrain]', streamUrl: finalURL, quality: qualityText));
          }
        } else if (text.contains('Server : 10Gbps') || text.contains('10Gbps')) {
          final redirectUrl = await _resolveFinalUrl(btnLink, referer: link);
          if (redirectUrl != null) {
            var finalUrl = redirectUrl;
            if (finalUrl.contains('link=')) {
              finalUrl = finalUrl.split('link=').last;
            }
            links.add(StreamLink(name: 'V-Cloud [10Gbps Server]', streamUrl: finalUrl, quality: qualityText));
          }
        }
      }
    } catch (_) {
      // Return whatever links were collected so far
    }

    // Sort links so direct/fast streams appear first
    links.sort((a, b) {
      int score(StreamLink link) {
        if (link.name.contains('FSLv2') || link.streamUrl.contains('r2.cloudflarestorage.com')) return 100;
        if (link.name.contains('Pixeldrain') || link.streamUrl.contains('pixeldrain')) return 90;
        if (link.name.contains('10Gbps') || link.streamUrl.contains('googleusercontent')) return 80;
        if (link.name.contains('BuzzServer')) return 70;
        if (link.name.contains('Mega Server')) return 60;
        if (link.name.contains('Direct Download')) return 55;
        if (link.name.contains('FSL Server')) return 50;
        return 10;
      }
      return score(b).compareTo(score(a));
    });

    return links;
  }
}
