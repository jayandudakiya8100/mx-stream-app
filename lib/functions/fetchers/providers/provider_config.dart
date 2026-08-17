import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Centralized configuration file containing provider endpoints, repository links,
/// and reference static URL definitions across the application.
class ProviderConfig {
  // ---------------------------------------------------------------------------
  // 1. Remote Endpoints & Repositories (Active Dynamic Source)
  // ---------------------------------------------------------------------------

  /// Dynamic live domain resolver endpoint from GitHub
  static const String urlsEndpoint =
      'https://raw.githubusercontent.com/SaurabhKaperwan/Utils/refs/heads/main/urls.json';

  /// CloudStream / CSX extensions & plugins catalogue
  static const String pluginsEndpoint =
      'https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/plugins.json';

  /// Default Megix Repository definition (CS.json)
  static const String defaultRepoUrl =
      'https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/CS.json';

  /// Cinemeta API for IMDb metadata enrichment (synopsis, cast, genres)
  static const String cinemetaUrl = 'https://v3-cinemeta.strem.io/meta';

  /// Standard Desktop User-Agent for requests
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // ---------------------------------------------------------------------------
  // 2. Default Active Provider Selection
  // ---------------------------------------------------------------------------
  static const String defaultActiveProvider = 'VegaMovies';

  // ---------------------------------------------------------------------------
  // 3. Reference Static Provider URLs (Retained in code, not actively forced)
  // ---------------------------------------------------------------------------
  static const Map<String, String> defaultProviderUrls = {
    'vegamovies': 'https://new1.vegamovies.futbol',
    'bollyflix': 'https://bollyflix.free',
    'moviesdrive': 'https://new2.moviesdrive.christmas',
    'moviesmod': 'https://moviesmod.zone',
    'uhdmovies': 'https://uhdmovies.autos',
    '4khdhub': 'https://4khdhub.one',
    'hdmovie2': 'https://hdmovie2a.bar',
    'movies4u': 'https://new3.movies4u.clinic',
    'rogmovies': 'https://new1.rogmovies.click',
    'multimovies': 'https://multimovies.makeup',
    'nfmirror': 'https://tv.imgcdn.kim/newtv',
    'skymovies': 'https://skymovieshd.forex',
    'topmovies': 'https://moviesleech.rest',
    'gdflix': 'https://new3.gdflix.io',
    'hubcloud': 'https://hubcloud.cx',
    'toonstream': 'https://toon-stream.site',
    'zinkmovies': 'https://zinkmovies.org',
    'vcloud': 'https://vcloud.fit',
    'dudefilms': 'https://dudefilms.casa',
    'm4ufree': 'https://ww4.m4ufree.lat',
    'animedao': 'https://anidao.to',
    'mlsbd': 'https://mlsbd.co',
    'fibwatch': 'https://fibwatch.art',
    'hindmoviez': 'https://hindmovie.icu',
    'rtally': 'https://rtally.link',
  };

  // ---------------------------------------------------------------------------
  // 4. Reference Static Providers List
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> defaultProvidersList = [
    {'id': 'none', 'name': 'None', 'url': ''},
    {'id': 'random', 'name': 'Random', 'url': ''},
    {'id': 'vegamovies', 'name': 'VegaMovies', 'url': 'https://new1.vegamovies.futbol'},
    {'id': 'bollyflix', 'name': 'Bollyflix', 'url': 'https://bollyflix.free'},
    {'id': 'moviesdrive', 'name': 'MoviesDrive', 'url': 'https://new2.moviesdrive.christmas'},
    {'id': 'moviesmod', 'name': 'Moviesmod', 'url': 'https://moviesmod.zone'},
    {'id': 'uhdmovies', 'name': 'UHDMovies', 'url': 'https://uhdmovies.autos'},
    {'id': '4khdhub', 'name': '4kHDHub', 'url': 'https://4khdhub.one'},
  ];

  // ---------------------------------------------------------------------------
  // 5. Dynamic URL Cache & Resolver (Active Live Mechanism)
  // ---------------------------------------------------------------------------
  static final Map<String, String> _resolvedBaseUrlCache = {};

  /// Get reference static provider URL
  static String? getStaticProviderUrl(String providerName) {
    final key = providerName.toLowerCase();
    return defaultProviderUrls[key];
  }

  /// Fetch the entire live dynamic URLs dictionary from urls.json
  static Future<Map<String, String>> fetchDynamicUrls() async {
    try {
      final response = await http.get(
        Uri.parse(urlsEndpoint),
        headers: {'User-Agent': defaultUserAgent},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, String> result = {};
        for (final entry in data.entries) {
          final key = entry.key.trim().toLowerCase();
          final val = entry.value.toString().replaceAll(RegExp(r'/$'), '');
          result[key] = val;
          _resolvedBaseUrlCache[key] = val;
        }
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ [ProviderConfig] Error fetching dynamic urls.json: $e');
    }
    return _resolvedBaseUrlCache;
  }

  /// Dynamically resolve live base URL for a provider from urls.json with cache
  static Future<String> resolveBaseUrl(String providerKey) async {
    final key = providerKey.toLowerCase();
    if (_resolvedBaseUrlCache.containsKey(key)) {
      return _resolvedBaseUrlCache[key]!;
    }

    final urls = await fetchDynamicUrls();
    final url = urls[key];
    if (url != null && url.isNotEmpty) {
      return url;
    }

    return getStaticProviderUrl(key) ?? '';
  }

  /// 100% deterministic integer ID from string, persistent across app restarts
  static int getStableMediaId(String input) {
    if (input.isEmpty) return 0;
    int hash = 0x811c9dc5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }
}
