@TestOn('vm')
library;

import 'dart:io';

import 'package:Mirarr/database/watch_history_database_web.dart';
import 'package:Mirarr/models/watch_history_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The web database keeps its Hive box and caches in statics, so these tests
/// exercise the same code paths the browser build uses, backed by a temporary
/// directory instead of IndexedDB.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mirarr_hive');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  WatchHistoryItem movie(int tmdbId) => WatchHistoryItem(
        id: tmdbId,
        tmdbId: tmdbId,
        title: 'Movie $tmdbId',
        type: 'movie',
        watchedAt: DateTime.fromMillisecondsSinceEpoch(1000 + tmdbId),
      );

  WatchHistoryItem episode(int tmdbId, int season, int number) =>
      WatchHistoryItem(
        id: tmdbId * 100 + number,
        tmdbId: tmdbId,
        title: 'Show $tmdbId',
        type: 'tv',
        seasonNumber: season,
        episodeNumber: number,
        watchedAt: DateTime.fromMillisecondsSinceEpoch(2000 + number),
      );

  final movies = [movie(11), movie(12), movie(13)];
  final episodes = [episode(21, 1, 1), episode(21, 1, 2), episode(22, 1, 1)];

  test('importing movies then shows keeps both sets', () async {
    final db = WatchHistoryDatabase();
    await db.importWatchHistory(movies);
    await db.importWatchHistory(episodes);

    expect((await db.getWatchedMovies()).length, movies.length);
    expect((await db.getWatchedShows()).length, episodes.length);
    await db.close();
  });

  test('overlapping imports do not reuse each other\'s keys', () async {
    final db = WatchHistoryDatabase();
    await Future.wait([
      db.importWatchHistory(movies),
      db.importWatchHistory(episodes),
    ]);

    expect((await db.getWatchedMovies()).length, movies.length);
    expect((await db.getWatchedShows()).length, episodes.length);
    await db.close();
  });

  test('re-importing the same file merges instead of duplicating', () async {
    final db = WatchHistoryDatabase();
    await db.importWatchHistory(movies);
    await db.importWatchHistory(movies);

    expect((await db.getWatchedMovies()).length, movies.length);
    await db.close();
  });

  test('an unreadable record does not break the rest of the history',
      () async {
    final db = WatchHistoryDatabase();
    await db.importWatchHistory(movies);
    await db.close();

    final box = await Hive.openBox('watch_history_box');
    await box.put(999, {'id': 999, 'title': 'broken'});
    await box.close();

    final reopened = WatchHistoryDatabase();
    expect((await reopened.getWatchedMovies()).length, movies.length);
    await reopened.close();
  });
}
