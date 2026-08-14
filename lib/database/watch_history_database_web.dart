import 'dart:async';

import 'package:Mirarr/models/watch_history_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

class WatchHistoryDatabase {
  static Box? _webBox;
  static List<WatchHistoryItem>? _cachedItems;
  static Map<String, WatchHistoryItem>? _cachedByKey;

  /// Serialises writes so two overlapping imports cannot hand out the same
  /// Hive keys and overwrite each other.
  static Future<void> _writeQueue = Future.value();

  Future<Box> get webBox async {
    if (_webBox != null) return _webBox!;
    _webBox = await Hive.openBox('watch_history_box');
    _rebuildCache(_webBox!);
    return _webBox!;
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  static WatchHistoryItem? _parse(dynamic value) {
    if (value is! Map) return null;
    try {
      return WatchHistoryItem.fromMap(Map<String, dynamic>.from(value));
    } catch (e) {
      debugPrint('Dropping unreadable watch history record: $e');
      return null;
    }
  }

  void _rebuildCache(Box box) {
    final list = <WatchHistoryItem>[];
    for (final value in box.values) {
      final item = _parse(value);
      if (item != null) list.add(item);
    }
    list.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    _cachedItems = list;
    _cachedByKey = {
      for (final item in list) _itemKey(item): item,
    };
  }

  void _invalidateCache() {
    _cachedItems = null;
    _cachedByKey = null;
  }

  Future<List<WatchHistoryItem>> _ensureCache() async {
    final box = await webBox;
    if (_cachedItems == null) {
      _rebuildCache(box);
    }
    return _cachedItems!;
  }

  static String _itemKeyFromParts(
    int tmdbId,
    String type,
    int? seasonNumber,
    int? episodeNumber,
  ) =>
      '${type}_${tmdbId}_${seasonNumber}_$episodeNumber';

  static String _itemKey(WatchHistoryItem item) => _itemKeyFromParts(
        item.tmdbId,
        item.type,
        item.seasonNumber,
        item.episodeNumber,
      );

  static int _maxKey(Box box) {
    var max = 0;
    for (final key in box.keys) {
      final asInt = key is int ? key : (key is num ? key.toInt() : null);
      if (asInt != null && asInt > max) max = asInt;
    }
    return max;
  }

  Future<int> insertWatchHistoryItem(WatchHistoryItem item) {
    return _serialize(() async {
      final box = await webBox;
      await _ensureCache();
      final existing = _cachedByKey![_itemKey(item)];
      if (existing != null) {
        await _writeUpdate(item);
        return existing.id ?? 0;
      }
      final id = item.id ?? (box.isEmpty ? 1 : _maxKey(box) + 1);
      final newItem = item.copyWith(id: id);
      await box.put(newItem.id, newItem.toMap());
      _invalidateCache();
      return newItem.id!;
    });
  }

  Future<void> importWatchHistory(List<WatchHistoryItem> items) {
    return _serialize(() async {
      final box = await webBox;

      // Existing entries keyed the same way the rest of this class keys them,
      // so a re-import merges instead of duplicating.
      final Map<String, int> existingKeys = {};
      for (final entry in box.toMap().entries) {
        final keyValue = entry.key;
        final existingId = keyValue is int
            ? keyValue
            : (keyValue is num ? keyValue.toInt() : null);
        if (existingId == null) continue;
        final existing = _parse(entry.value);
        if (existing == null) continue;
        existingKeys[_itemKey(existing)] = existingId;
      }

      final Map<int, Map<String, dynamic>> itemsToPut = {};
      var nextId = box.isEmpty ? 1 : _maxKey(box) + 1;

      for (final item in items) {
        final key = _itemKey(item);
        final existingId = existingKeys[key];
        if (existingId != null) {
          itemsToPut[existingId] = item.copyWith(id: existingId).toMap();
        } else {
          final newId = nextId++;
          itemsToPut[newId] = item.copyWith(id: newId).toMap();
          existingKeys[key] = newId;
        }
      }

      if (itemsToPut.isNotEmpty) {
        await box.putAll(itemsToPut);
        _invalidateCache();
      }
    });
  }

  Future<void> updateWatchHistoryItem(WatchHistoryItem item) =>
      _serialize(() => _writeUpdate(item));

  Future<void> _writeUpdate(WatchHistoryItem item) async {
    final box = await webBox;
    await _ensureCache();
    final existing = _cachedByKey![_itemKey(item)];
    if (existing?.id == null) return;

    final keyToUpdate = existing!.id!;
    final updatedItem = WatchHistoryItem(
      id: keyToUpdate,
      tmdbId: item.tmdbId,
      title: item.title,
      type: item.type,
      posterPath: item.posterPath,
      watchedAt: item.watchedAt,
      seasonNumber: item.seasonNumber,
      episodeNumber: item.episodeNumber,
      episodeTitle: item.episodeTitle,
      userRating: item.userRating,
      notes: item.notes,
    );
    await box.put(keyToUpdate, updatedItem.toMap());
    _invalidateCache();
  }

  Future<void> deleteWatchHistoryItem(int id) {
    return _serialize(() async {
      final box = await webBox;
      await box.delete(id);
      _invalidateCache();
    });
  }

  Future<void> addShowEpisodesBatch(List<WatchHistoryItem> items) async {
    if (items.isEmpty) return;
    await importWatchHistory(items);
  }

  Future<void> deleteWatchHistoryItemsBatch(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return _serialize(() async {
      final box = await webBox;
      await box.deleteAll(ids);
      _invalidateCache();
    });
  }

  Future<List<WatchHistoryItem>> getAllWatchHistory() async {
    final list = await _ensureCache();
    return List<WatchHistoryItem>.from(list);
  }

  Future<List<WatchHistoryItem>> getWatchedMovies() async {
    final list = await _ensureCache();
    return list.where((item) => item.type == 'movie').toList();
  }

  Future<List<WatchHistoryItem>> getWatchedShows() async {
    final list = await _ensureCache();
    return list.where((item) => item.type == 'tv').toList();
  }

  Future<List<WatchHistoryItem>> getWatchHistoryByTmdbId(
      int tmdbId, String type) async {
    final list = await _ensureCache();
    return list
        .where((item) => item.tmdbId == tmdbId && item.type == type)
        .toList();
  }

  Future<bool> isWatched(int tmdbId, String type,
      {int? seasonNumber, int? episodeNumber}) async {
    await _ensureCache();
    return _cachedByKey!.containsKey(
        _itemKeyFromParts(tmdbId, type, seasonNumber, episodeNumber));
  }

  Future<List<WatchHistoryItem>> getRecentWatchHistory({int limit = 20}) async {
    final list = await _ensureCache();
    return list.take(limit).toList();
  }

  Future<Map<String, int>> getWatchStats() async {
    final list = await _ensureCache();
    final movieCount = list.where((item) => item.type == 'movie').length;
    final showCount = list.where((item) => item.type == 'tv').length;

    return {
      'movies': movieCount,
      'shows': showCount,
    };
  }

  Future<int> getWatchHistoryCount() async {
    final box = await webBox;
    return box.length;
  }

  Future<void> close() async {
    if (_webBox != null) {
      await _webBox!.close();
      _webBox = null;
    }
    _invalidateCache();
  }

  Future<int> addMovieToHistory({
    required int tmdbId,
    required String title,
    String? posterPath,
    DateTime? watchedAt,
    double? userRating,
    String? notes,
  }) async {
    final item = WatchHistoryItem(
      tmdbId: tmdbId,
      title: title,
      type: 'movie',
      posterPath: posterPath,
      watchedAt: watchedAt ?? DateTime.now(),
      userRating: userRating,
      notes: notes,
    );
    return await insertWatchHistoryItem(item);
  }

  Future<int> addShowToHistory({
    required int tmdbId,
    required String title,
    String? posterPath,
    DateTime? watchedAt,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    double? userRating,
    String? notes,
  }) async {
    final item = WatchHistoryItem(
      tmdbId: tmdbId,
      title: title,
      type: 'tv',
      posterPath: posterPath,
      watchedAt: watchedAt ?? DateTime.now(),
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      userRating: userRating,
      notes: notes,
    );
    return await insertWatchHistoryItem(item);
  }
}
