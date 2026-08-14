import 'dart:collection';

const int _seasonsApiCacheLimit = 50;

/// In-flight / completed seasons API calls, insertion-ordered for LRU eviction.
final LinkedHashMap<String, Future<dynamic>> seasonsApiCache =
    LinkedHashMap<String, Future<dynamic>>();

void clearSeasonsApiCache() {
  seasonsApiCache.clear();
}

/// Memoizes [apiCall] by [key]. Concurrent callers share the same Future.
///
/// Failed futures are removed so the next call can retry. Successful entries
/// are kept, moved to the most-recently-used end, and capped at ~50.
Future<T> cachedSeasonsApiCall<T>(
    String key, Future<T> Function() apiCall) {
  final existing = seasonsApiCache.remove(key);
  if (existing != null) {
    seasonsApiCache[key] = existing;
    return existing as Future<T>;
  }

  late final Future<T> future;
  future = () async {
    try {
      return await apiCall();
    } catch (e) {
      if (identical(seasonsApiCache[key], future)) {
        seasonsApiCache.remove(key);
      }
      rethrow;
    }
  }();

  seasonsApiCache[key] = future;
  _evictIfNeeded();
  return future;
}

void _evictIfNeeded() {
  while (seasonsApiCache.length > _seasonsApiCacheLimit) {
    seasonsApiCache.remove(seasonsApiCache.keys.first);
  }
}
