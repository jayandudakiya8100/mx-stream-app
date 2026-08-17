import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class MediaProviderItem {
  final String id;
  final String name;
  final String? url;

  const MediaProviderItem({
    required this.id,
    required this.name,
    this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
      };

  factory MediaProviderItem.fromJson(Map<String, dynamic> json) =>
      MediaProviderItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        url: json['url'] as String?,
      );
}

class MediaProviderService {
  static const String _sessionBoxName = 'sessionBox';
  static const String _providerKey = 'selected_media_provider';
  static const String _cachedProvidersKey = 'cached_media_providers';

  static const String _urlsEndpoint =
      'https://raw.githubusercontent.com/SaurabhKaperwan/Utils/refs/heads/main/urls.json';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // Default base providers
  static const List<MediaProviderItem> defaultProviders = [
    MediaProviderItem(id: 'none', name: 'None'),
    MediaProviderItem(id: 'random', name: 'Random'),
  ];

  /// Get currently selected provider name (defaults to 'None')
  static String getSelectedProvider() {
    try {
      final box = Hive.box(_sessionBoxName);
      final saved = box.get(_providerKey) as String?;
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
    } catch (_) {}
    return 'None';
  }

  /// Set and persist selected provider
  static Future<void> setSelectedProvider(String providerName) async {
    try {
      final box = Hive.box(_sessionBoxName);
      await box.put(_providerKey, providerName);
    } catch (e) {
      debugPrint('Error saving selected provider: $e');
    }
  }

  /// Fetch providers dynamically from remote source with local cache fallback
  static Future<List<MediaProviderItem>> fetchProviders() async {
    List<MediaProviderItem> list = _loadCachedProviders();
    if (list.isEmpty) {
      list = List.from(defaultProviders);
    }

    try {
      final response = await http.get(
        Uri.parse(_urlsEndpoint),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> remoteData = json.decode(response.body);
        final List<MediaProviderItem> result = [
          const MediaProviderItem(id: 'none', name: 'None'),
          const MediaProviderItem(id: 'random', name: 'Random'),
        ];

        for (final entry in remoteData.entries) {
          final key = entry.key.trim();
          final url = entry.value.toString();
          result.add(
            MediaProviderItem(
              id: key.toLowerCase(),
              name: key,
              url: url,
            ),
          );
        }

        _cacheProviders(result);
        return result;
      }
    } catch (e) {
      debugPrint('Error fetching dynamic providers: $e');
    }

    return list;
  }

  static List<MediaProviderItem> _loadCachedProviders() {
    try {
      final box = Hive.box(_sessionBoxName);
      final raw = box.get(_cachedProvidersKey);
      if (raw != null && raw is List) {
        return raw.map((item) {
          if (item is Map) {
            return MediaProviderItem.fromJson(Map<String, dynamic>.from(item));
          }
          return MediaProviderItem(id: item.toString(), name: item.toString());
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static void _cacheProviders(List<MediaProviderItem> providers) {
    try {
      final box = Hive.box(_sessionBoxName);
      box.put(
        _cachedProvidersKey,
        providers.map((p) => p.toJson()).toList(),
      );
    } catch (_) {}
  }
}
