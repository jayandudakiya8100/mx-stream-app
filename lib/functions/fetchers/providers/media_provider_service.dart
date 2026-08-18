import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'provider_config.dart';

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

  /// Initial minimal fallback providers before network load
  static List<MediaProviderItem> get defaultProviders => [];

  /// Get provider URL dynamically from cache or resolver
  static Future<String> getProviderUrl(String providerName) =>
      ProviderConfig.resolveBaseUrl(providerName);

  /// Get currently selected provider name (defaults to ProviderConfig.defaultActiveProvider)
  static String getSelectedProvider() {
    try {
      if (Hive.isBoxOpen(_sessionBoxName)) {
        final box = Hive.box(_sessionBoxName);
        final saved = box.get(_providerKey) as String?;
        if (saved != null && saved.isNotEmpty) {
          return saved;
        }
      }
    } catch (_) {}
    return ProviderConfig.defaultActiveProvider;
  }

  /// Set and persist selected provider
  static Future<void> setSelectedProvider(String providerName) async {
    try {
      final box = Hive.isBoxOpen(_sessionBoxName)
          ? Hive.box(_sessionBoxName)
          : await Hive.openBox(_sessionBoxName);
      await box.put(_providerKey, providerName);
    } catch (e) {
      // ignore error
    }
  }

  /// Helper to format provider key nicely (e.g. 'vegamovies' -> 'VegaMovies')
  static String _formatDisplayName(String key) {
    if (key.isEmpty) return key;
    final lower = key.toLowerCase();
    const knownNames = <String, String>{};
    if (knownNames.containsKey(lower)) {
      return knownNames[lower]!;
    }
    return key[0].toUpperCase() + key.substring(1);
  }

  /// Fetch installed providers dynamically from Hive
  static Future<List<MediaProviderItem>> fetchProviders() async {
    return _loadCachedProviders();
  }
  
  /// Install a new provider from the repository
  static Future<void> installProvider(String id, String name, String url) async {
    try {
      if (!Hive.isBoxOpen(_sessionBoxName)) {
        await Hive.openBox(_sessionBoxName);
      }
      List<MediaProviderItem> installed = _loadCachedProviders();
      // Check if already installed
      if (!installed.any((p) => p.id == id)) {
        installed.add(MediaProviderItem(id: id, name: name, url: url));
        _cacheProviders(installed);
      }
    } catch (e) {
      debugPrint('Failed to install provider: $e');
    }
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
