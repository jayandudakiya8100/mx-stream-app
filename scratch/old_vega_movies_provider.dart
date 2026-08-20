import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

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
  static const String _defaultMainUrl = 'https://vegamovies.mq';
  static const String _dynamicUrlsEndpoint =
      'https://raw.githubusercontent.com/SaurabhKaperwan/Utils/refs/heads/main/urls.json';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Fetch the latest active base URL from GitHub
  static Future<String> _getLatestBaseUrl() async {
    try {
      final response = await http.get(
        Uri.parse(_dynamicUrlsEndpoint),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> urls = json.decode(response.body);
        final vegaUrl = urls['vegamovies'];
        if (vegaUrl != null && vegaUrl.toString().isNotEmpty) {
          return vegaUrl;
        }
      }
    } catch (_) {
      // Fallback to default URL
    }
    return _defaultMainUrl;
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

  /// Resolve redirects manually (up to 7)
  static Future<String?> _resolveFinalUrl(String startUrl) async {
    var currentUrl = startUrl;
    for (int i = 0; i < 7; i++) {
      try {
        final request = http.Request('HEAD', Uri.parse(currentUrl));
        request.headers['User-Agent'] = _userAgent;
        request.followRedirects = false;

        final client = http.Client();
        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 5));
        client.close();

        final statusCode = streamedResponse.statusCode;
        if (statusCode == 200 || (statusCode >= 300 && statusCode < 400)) {
          final location = streamedResponse.headers['location'];
          if (location == null || location.isEmpty) break;
          currentUrl = location;
        } else {
          return null;
        }
      } catch (_) {
        return null;
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
        // doc.selectFirst("div.vd > center > a")?.attr("href")
        final aTag = document.querySelector('div.vd center a');
        link = aTag?.attributes['href'] ?? '';
      } else {
        // Find script that contains 'var url =' (the actual URL assignment, not random URLs in code)
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
        headers: {'User-Agent': _userAgent},
      );
      if (resolvedResponse.statusCode != 200) return links;

      final resolvedDoc = parser.parse(resolvedResponse.body);
      final header = resolvedDoc.querySelector('div.card-header')?.text.trim() ?? '';
      final size = resolvedDoc.querySelector('i#size')?.text.trim() ?? '';
      final qualityText = '$header [$size]';

      // Process download buttons: document.select("h2 a.btn")
      final buttons = resolvedDoc.querySelectorAll('h2 a.btn');

      for (final button in buttons) {
        final btnLink = button.attributes['href'] ?? '';
        final text = button.text;

        if (text.contains('FSL Server')) {
          links.add(StreamLink(name: 'V-Cloud [FSL Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('FSLv2')) {
          links.add(StreamLink(name: 'V-Cloud [FSLv2 Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('Mega Server')) {
          links.add(StreamLink(name: 'V-Cloud [Mega Server]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('Download File')) {
          links.add(StreamLink(name: 'V-Cloud [Download File]', streamUrl: btnLink, quality: qualityText));
        } else if (text.contains('BuzzServer')) {
          // Follow the /download redirect
          try {
            final buzzResponse = await http.get(
              Uri.parse('$btnLink/download'),
              headers: {'User-Agent': _userAgent, 'Referer': btnLink},
            );
            final dlink = buzzResponse.headers['hx-redirect'] ?? '';
            if (dlink.isNotEmpty) {
              final buzzBase = _getBaseUrl(btnLink);
              links.add(StreamLink(name: 'V-Cloud [BuzzServer]', streamUrl: buzzBase + dlink, quality: qualityText));
            }
          } catch (_) {
            // Skip this server if it fails
          }
        } else if (btnLink.contains('pixeldra')) {
          final pixelLink = _extractPxlUrl(resolvedResponse.body);
          if (pixelLink != null && pixelLink.isNotEmpty) {
            final pixelBase = _getBaseUrl(pixelLink);
            final finalURL = pixelLink.toLowerCase().contains('download')
                ? pixelLink
                : '$pixelBase/api/file/${pixelLink.split('/').last}?download';
            links.add(StreamLink(name: 'V-Cloud [Pixeldrain]', streamUrl: finalURL, quality: qualityText));
          }
        } else if (text.contains('Server : 10Gbps')) {
          final redirectUrl = await _resolveFinalUrl(btnLink);
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

    return links;
  }
}
