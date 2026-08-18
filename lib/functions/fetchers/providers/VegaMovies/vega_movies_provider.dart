import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';
import '../core/models.dart';
import '../core/base_provider.dart';
import '../provider_config.dart';
import 'extractors/vcloud_extractor.dart';

class VegaMoviesProviderImpl extends BaseProvider {
  @override
  String get name => 'VegaMovies';
  @override
  String get lang => 'hi';
  
  final String defaultMainUrl = 'https://vegamovies.mq';
  final String cinemetaUrl = 'https://v3-cinemeta.strem.io/meta';
  
  String? _activeBaseUrl;

  Future<String> getBaseUrl() async {
    if (_activeBaseUrl != null) return _activeBaseUrl!;
    
    try {
      final url = await ProviderConfig.resolveBaseUrl('vegamovies');
      if (url.isNotEmpty) {
        _activeBaseUrl = url;
        return _activeBaseUrl!;
      }
    } catch (_) {}
    
    _activeBaseUrl = defaultMainUrl;
    return _activeBaseUrl!;
  }

  @override
  Future<List<ProviderSearchItem>> getMainPage({String category = 'home', int page = 1}) async {
    final baseUrl = await getBaseUrl();
    final routes = {
      'home': '/page/$page/',
      'netflix': '/category/web-series/netflix/page/$page/',
      'hotstar': '/category/web-series/disney-plus-hotstar/page/$page/',
      'prime': '/category/web-series/amazon-prime-video/page/$page/',
      'anime': '/category/anime-series/page/$page/',
    };

    final targetUrl = '$baseUrl${routes[category] ?? routes['home']}';
    
    try {
      debugPrint('[VegaMovies] Fetching target URL: $targetUrl');
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {'User-Agent': ProviderConfig.defaultUserAgent},
      ).timeout(const Duration(seconds: 8));
      
      debugPrint('[VegaMovies] Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[VegaMovies] Error: HTML response was not 200 ok');
      }

      final document = parser.parse(response.body);
      
      final results = <ProviderSearchItem>[];
      final elements = document.querySelectorAll('div.movies-grid > a');
      debugPrint('[VegaMovies] Found ${elements.length} elements matching div.movies-grid > a');
      
      for (var el in elements) {
        final href = el.attributes['href'] ?? '';
        final img = el.querySelector('img');
        if (img == null) continue;
        
        final rawTitle = img.attributes['alt'] ?? '';
        final title = rawTitle.replaceFirst(RegExp(r'^Download\s+', caseSensitive: false), '').trim();
        
        String poster = img.attributes['src'] ?? '';
        if (!poster.contains('https:')) {
          poster = img.attributes['data-src'] ?? poster;
        }
        
        if (title.isNotEmpty && href.isNotEmpty) {
          final type = RegExp(r'season|series|s0', caseSensitive: false).hasMatch(title) ? 'series' : 'movie';
          results.add(ProviderSearchItem(title: title, url: href, poster: poster, type: type));
        }
      }
      debugPrint('[VegaMovies] Successfully parsed ${results.length} items from $category');
      return results;
    } catch (e) {
      debugPrint('[VegaMovies] getMainPage error: $e');
      return [];
    }
  }

  @override
  Future<List<ProviderSearchItem>> search(String query, {int page = 1}) async {
    try {
      final baseUrl = await getBaseUrl();
      final searchUrl = '$baseUrl/search.php?q=${Uri.encodeComponent(query)}&page=$page';
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': ProviderConfig.defaultUserAgent},
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode != 200) return [];
      
      final data = json.decode(response.body);
      if (data == null || data['hits'] == null) return [];
      
      final hits = data['hits'] as List;
      return hits.map((hit) {
        final doc = hit['document'] ?? {};
        final rawTitle = doc['post_title'] ?? '';
        final title = rawTitle.replaceFirst(RegExp(r'^Download\s+', caseSensitive: false), '').trim();
        final type = RegExp(r'season|series|s0', caseSensitive: false).hasMatch(title) ? 'series' : 'movie';
        
        return ProviderSearchItem(
          title: title,
          url: doc['permalink'] ?? '',
          poster: doc['post_thumbnail'] ?? '',
          type: type,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<StreamLink>> extractStream(String url) async {
    return VCloudExtractor.extractVCloudStream(url);
  }

  @override
  Future<ProviderMediaDetails?> loadDetails(String url, {bool skipSources = false}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': ProviderConfig.defaultUserAgent},
      ).timeout(const Duration(seconds: 10));
      final document = parser.parse(response.body);

      var title = document.querySelector('title')?.text.replaceFirst(RegExp(r'^Download\s+', caseSensitive: false), '').trim() ?? '';
      final posterUrl = document.querySelector('p > img')?.attributes['src'] ?? '';
      
      String imdbUrl = '';
      final imdbLinkElement = document.querySelector('a[href*="imdb"]');
      if (imdbLinkElement != null) {
        imdbUrl = imdbLinkElement.attributes['href'] ?? '';
      }
      
      String imdbId = '';
      if (imdbUrl.contains('title/')) {
        final parts = imdbUrl.split('title/');
        if (parts.length > 1) {
          imdbId = parts[1].split('/')[0];
        }
      }

      final pageText = document.querySelector('main')?.text ?? '';
      final isSeries = RegExp(r'Series-SYNOPSIS\/PLOT|Series Info|Series synopsis\/PLOT', caseSensitive: false).hasMatch(pageText);
      final tvtype = isSeries ? 'series' : 'movie';

      final audioInfo = _extractAudioInfo(pageText, title, url);
      
      String description = '';
      final synopsisHeader = document.querySelectorAll('h3').where((e) => e.text.contains('SYNOPSIS')).firstOrNull;
      if (synopsisHeader != null) {
        final nextEl = synopsisHeader.nextElementSibling;
        if (nextEl != null) {
          description = nextEl.text.trim();
        }
      }

      List<String> cast = [];
      List<String> genre = [];
      String imdbRating = '';
      String year = '';
      String background = posterUrl;
      List<dynamic> cinemetaEpisodes = [];

      if (imdbId.isNotEmpty) {
        try {
          final metaRes = await http.get(Uri.parse('$cinemetaUrl/$tvtype/$imdbId.json')).timeout(const Duration(seconds: 5));
          if (metaRes.statusCode == 200) {
            final metaData = json.decode(metaRes.body);
            final meta = metaData['meta'];
            if (meta != null) {
              description = meta['description'] ?? description;
              if (meta['cast'] != null) cast = List<String>.from(meta['cast']);
              title = meta['name'] ?? title;
              if (meta['genre'] != null) genre = List<String>.from(meta['genre']);
              imdbRating = meta['imdbRating'] ?? '';
              year = meta['year']?.toString() ?? '';
              cinemetaEpisodes = meta['videos'] ?? [];
            }
          }
        } catch (_) {}
      }

      if (tvtype == 'series') {
        final Map<String, List<VideoSource>> episodesMap = {};

        if (!skipSources) {
          final hTags = document.querySelectorAll('main > h3, main > h5').where((el) {
            final text = el.text;
            return RegExp(r'(4K|[0-9]*0p)', caseSensitive: false).hasMatch(text) && !RegExp(r'Zip', caseSensitive: false).hasMatch(text);
          }).toList();

          for (var tag in hTags) {
            final tagHtml = tag.outerHtml;
            final tagText = tag.text;

            String resolution = '720p';
            if (tagText.contains('480p')) resolution = '480p';
            else if (tagText.contains('1080p')) resolution = '1080p';
            else if (tagText.contains('2160p') || tagText.contains('4K')) resolution = '2160p 4K';

            final seasonMatch = RegExp(r'(?:Season |S)(\d+)', caseSensitive: false).firstMatch(tagHtml);
            final realSeason = seasonMatch != null ? int.parse(seasonMatch.group(1)!) : 1;

            final pTag = tag.nextElementSibling;
            final aTags = pTag?.localName == 'p' ? pTag?.querySelectorAll('a') : tag.querySelectorAll('a');
            
            if (aTags == null) continue;

            var unilinks = aTags.where((el) => RegExp(r'V-Cloud|Episode|Download', caseSensitive: false).hasMatch(el.text)).toList();
            if (unilinks.isEmpty) {
              unilinks = aTags.where((el) => RegExp(r'G-Direct', caseSensitive: false).hasMatch(el.text)).toList();
            }

            final unilink = unilinks.firstOrNull;
            if (unilink == null) continue;

            final eurl = unilink.attributes['href'];
            if (eurl != null) {
              try {
                final doc2 = await http.get(Uri.parse(eurl)).timeout(const Duration(seconds: 10));
                final $2 = parser.parse(doc2.body);

                final vcloudLinks = <String>[];
                $2.querySelectorAll('p > a').forEach((el) {
                  final href = el.attributes['href'] ?? '';
                  if (href.toLowerCase().contains('vcloud')) {
                    vcloudLinks.add(href);
                  }
                });

                for (int epIdx = 0; epIdx < vcloudLinks.length; epIdx++) {
                  final epNum = epIdx + 1;
                  final key = '$realSeason-$epNum';
                  
                  final existing = episodesMap[key] ?? [];
                  if (!existing.any((s) => s.resolution == resolution)) {
                    existing.add(VideoSource(resolution: resolution, url: vcloudLinks[epIdx]));
                  }
                  episodesMap[key] = existing;
                }
              } catch (_) {}
            }
          }
        }

        final List<EpisodeInfo> formattedEpisodes = [];
        if (skipSources) {
          for (var v in cinemetaEpisodes) {
            formattedEpisodes.add(EpisodeInfo(
              season: v['season'],
              episode: v['episode'],
              name: v['name'] ?? v['title'] ?? 'Episode ${v['episode']}',
              poster: v['thumbnail'],
              description: v['overview'],
              sources: [],
            ));
          }
        } else {
          episodesMap.forEach((key, sources) {
            final parts = key.split('-');
            final s = int.parse(parts[0]);
            final e = int.parse(parts[1]);
            
            final metaEp = cinemetaEpisodes.where((v) => v['season'] == s && v['episode'] == e).firstOrNull;
            
            formattedEpisodes.add(EpisodeInfo(
              season: s,
              episode: e,
              name: metaEp?['name'] ?? metaEp?['title'] ?? 'Episode $e',
              poster: metaEp?['thumbnail'],
              description: metaEp?['overview'],
              sources: sources,
            ));
          });
        }

        return ProviderMediaDetails(
          title: title,
          url: url,
          type: 'series',
          poster: posterUrl,
          background: background,
          plot: description,
          year: int.tryParse(year),
          rating: imdbRating,
          audioTitle: audioInfo['audioTitle']!,
          audioLanguages: (audioInfo['audioLanguages'] as List).cast<String>(),
          tags: genre,
          cast: cast,
          imdbUrl: imdbUrl,
          episodes: formattedEpisodes,
        );

      } else {
        // Movies Logic
        final List<VideoSource> movieSources = [];
        
        if (!skipSources) {
          String currentRes = '720p';
          final elements = document.querySelector('main')?.querySelectorAll('h3, h4, h5, p, a') ?? [];
          
          final List<Map<String, String>> buttonLinks = [];

          for (var el in elements) {
            final tag = el.localName?.toLowerCase() ?? '';
            final text = el.text;

            if (tag != 'a' && RegExp(r'(4K|[0-9]{3,4}p)', caseSensitive: false).hasMatch(text)) {
              if (text.contains('480p')) currentRes = '480p';
              else if (text.contains('1080p')) currentRes = '1080p';
              else if (text.contains('2160p') || text.contains('4K')) currentRes = '2160p 4K';
              else if (text.contains('720p')) currentRes = '720p';
            }

            if (tag == 'a' && el.querySelector('button.dwd-button') != null) {
              final link = el.attributes['href'];
              if (link != null) {
                buttonLinks.add({'link': link, 'resolution': currentRes});
              }
            }
          }

          for (var item in buttonLinks) {
            if (movieSources.any((s) => s.resolution == item['resolution'])) continue;

            try {
              final doc = await http.get(Uri.parse(item['link']!)).timeout(const Duration(seconds: 10));
              final btnDoc = parser.parse(doc.body);
              final sourceLink = btnDoc.querySelectorAll('a').where((a) => a.text.contains('V-Cloud')).firstOrNull?.attributes['href'];
              
              if (sourceLink != null) {
                movieSources.add(VideoSource(resolution: item['resolution']!, url: sourceLink));
              }
            } catch (_) {}
          }
        }

        return ProviderMediaDetails(
          title: title,
          url: url,
          type: 'movie',
          poster: posterUrl,
          background: background,
          plot: description,
          year: int.tryParse(year),
          rating: imdbRating,
          audioTitle: audioInfo['audioTitle']!,
          audioLanguages: (audioInfo['audioLanguages'] as List).cast<String>(),
          tags: genre,
          cast: cast,
          imdbUrl: imdbUrl,
          sources: movieSources,
        );
      }

    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _extractAudioInfo(String bodyText, String title, String url) {
    String audioTitle = 'Original Audio';
    final match = RegExp(r'(?:Language|Audio)\s*:\s*([^\n\r<]+)', caseSensitive: false).firstMatch(bodyText);
    
    if (match != null && match.group(1) != null) {
      audioTitle = match.group(1)!.trim();
    } else {
      final combined = '$title $url'.toLowerCase();
      if (combined.contains('dual-audio') || combined.contains('hindi-dubbed')) {
        audioTitle = 'Dual Audio [Hindi + English]';
      } else if (combined.contains('multi-audio')) {
        audioTitle = 'Multi Audio';
      } else if (combined.contains('hindi')) {
        audioTitle = 'Hindi';
      }
    }

    final List<String> audioLanguages = [];
    final upper = audioTitle.toUpperCase();
    if (upper.contains('HINDI') || upper.contains('HIN')) audioLanguages.add('Hindi');
    if (upper.contains('ENGLISH') || upper.contains('ENG')) audioLanguages.add('English');
    if (upper.contains('TELUGU') || upper.contains('TEL')) audioLanguages.add('Telugu');
    if (upper.contains('TAMIL') || upper.contains('TAM')) audioLanguages.add('Tamil');

    return {
      'audioTitle': audioTitle,
      'audioLanguages': audioLanguages.isNotEmpty ? audioLanguages : ['Original Audio'],
    };
  }
}
