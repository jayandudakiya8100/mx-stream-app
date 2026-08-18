import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'provider_config.dart';
import 'media_provider_service.dart';
import 'core/models.dart';
import 'provider_manager.dart';

/// Represents search results returned by a single provider
class ProviderSearchResultSection {
  final String providerId;
  final String providerName;
  final List<ProviderSearchItem> items;
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
    List<ProviderSearchItem>? items,
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

  static Future<List<ProviderSearchItem>> searchProvider(
    String providerId,
    String query, {
    int page = 1,
  }) async {
    final provider = ProviderManager.getProvider(providerId);
    if (provider != null) {
      return await provider.search(query);
    }
    return [];
  }

  static Stream<ProviderSearchResultSection> searchAllProvidersStream(
    String query, {
    List<String>? selectedProviders,
  }) async* {
    yield* const Stream.empty();
  }
}
