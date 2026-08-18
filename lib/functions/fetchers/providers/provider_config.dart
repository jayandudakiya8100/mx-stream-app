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
  static const String defaultActiveProvider = '';

  // ---------------------------------------------------------------------------
  // 3. Reference Static Provider URLs (Retained in code, not actively forced)
  // ---------------------------------------------------------------------------
  static const Map<String, String> defaultProviderUrls = {};

  // ---------------------------------------------------------------------------
  // 4. Reference Static Providers List
  // ---------------------------------------------------------------------------
  static const List<Map<String, String>> defaultProvidersList = [];

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
      final response = await http.get(Uri.parse(urlsEndpoint));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final result = <String, String>{};
        data.forEach((key, value) {
          result[key.toLowerCase()] = value.toString();
        });
        return result;
      }
    } catch (e) {
      debugPrint('Error fetching dynamic urls: $e');
    }
    return {};
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
