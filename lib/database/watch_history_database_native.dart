import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:mxstream/models/watch_history_model.dart';

const String _databaseName = 'watch_history.db';
const String _tableName = 'watch_history';
const int _schemaVersion = 1;

/// Thrown when the database isolate cannot fulfil a request.
class WatchHistoryDatabaseException implements Exception {
  WatchHistoryDatabaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Watch history storage backed by sqlite3.
///
/// `package:sqlite3` is a synchronous FFI binding, so every statement is run on
/// a dedicated isolate that owns the only connection to the file. A single
/// owner also serialises every read and write, which keeps the file consistent
/// while the settings screen imports or restores a database.
class WatchHistoryDatabase {
  static _DatabaseIsolate? _isolate;
  static Future<_DatabaseIsolate>? _connecting;

  static Future<_DatabaseIsolate> _connect() {
    final connected = _isolate;
    if (connected != null) {
      if (!connected.isStopped) return Future.value(connected);
      // The isolate was closed or died, so the next call starts a new one.
      _isolate = null;
    }
    return _connecting ??= _spawn();
  }

  static Future<_DatabaseIsolate> _spawn() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      // Android has no writable default temp directory, so sqlite has to be
      // told where to put spill files for large sorts.
      final temporaryDirectory =
          Platform.isAndroid ? await getTemporaryDirectory() : null;

      final isolate = await _DatabaseIsolate.spawn(
        join(documentsDirectory.path, _databaseName),
        temporaryDirectory?.path,
      );
      _isolate = isolate;
      return isolate;
    } finally {
      _connecting = null;
    }
  }

  static Future<Object?> _request(_Operation operation,
      [List<Object?> arguments = const []]) async {
    final isolate = await _connect();
    return isolate.send(operation, arguments);
  }

  Future<int> insertWatchHistoryItem(WatchHistoryItem item) async {
    return await _request(_Operation.insert, [item]) as int;
  }

  Future<void> importWatchHistory(List<WatchHistoryItem> items) async {
    await _request(_Operation.import, [items]);
  }

  Future<void> updateWatchHistoryItem(WatchHistoryItem item) async {
    await _request(_Operation.update, [item]);
  }

  Future<void> deleteWatchHistoryItem(int id) async {
    await _request(_Operation.delete, [id]);
  }

  /// Inserts (or updates) many show episodes in one isolate round-trip.
  ///
  /// Uses a single `BEGIN`/`COMMIT` and one prepared INSERT statement so marking
  /// a long-running series does not pay per-episode IPC and prepare overhead.
  Future<void> addShowEpisodesBatch(List<WatchHistoryItem> items) async {
    if (items.isEmpty) return;
    await _request(_Operation.insertBatch, [items]);
  }

  /// Deletes many watch-history rows in one isolate round-trip.
  Future<void> deleteWatchHistoryItemsBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    await _request(_Operation.deleteBatch, [ids]);
  }

  Future<List<WatchHistoryItem>> getAllWatchHistory() async {
    return _items(await _request(_Operation.getAll));
  }

  Future<List<WatchHistoryItem>> getWatchedMovies() async {
    return _items(await _request(_Operation.getByType, ['movie']));
  }

  Future<List<WatchHistoryItem>> getWatchedShows() async {
    return _items(await _request(_Operation.getByType, ['tv']));
  }

  Future<List<WatchHistoryItem>> getWatchHistoryByTmdbId(
      int tmdbId, String type) async {
    return _items(await _request(_Operation.getByTmdbId, [tmdbId, type]));
  }

  Future<bool> isWatched(int tmdbId, String type,
      {int? seasonNumber, int? episodeNumber}) async {
    return await _request(_Operation.isWatched,
        [tmdbId, type, seasonNumber, episodeNumber]) as bool;
  }

  Future<List<WatchHistoryItem>> getRecentWatchHistory({int limit = 20}) async {
    return _items(await _request(_Operation.getRecent, [limit]));
  }

  Future<Map<String, int>> getWatchStats() async {
    final stats = await _request(_Operation.getStats) as Map;
    return stats.cast<String, int>();
  }

  Future<int> getWatchHistoryCount() async {
    return await _request(_Operation.getCount) as int;
  }

  Future<void> close() async {
    final connecting = _connecting;
    if (_isolate == null && connecting != null) {
      // Let an in-flight spawn settle so it cannot reopen the file behind our
      // back. A spawn that failed leaves nothing to close.
      try {
        await connecting;
      } catch (_) {}
    }

    final isolate = _isolate;
    _isolate = null;
    await isolate?.close();
  }

  Future<int> addMovieToHistory({
    required int tmdbId,
    required String title,
    String? posterPath,
    DateTime? watchedAt,
    double? userRating,
    String? notes,
  }) {
    return insertWatchHistoryItem(WatchHistoryItem(
      tmdbId: tmdbId,
      title: title,
      type: 'movie',
      posterPath: posterPath,
      watchedAt: watchedAt ?? DateTime.now(),
      userRating: userRating,
      notes: notes,
    ));
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
  }) {
    return insertWatchHistoryItem(WatchHistoryItem(
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
    ));
  }

  static List<WatchHistoryItem> _items(Object? response) {
    // A plain growable copy: callers sort and filter what they get back.
    return List<WatchHistoryItem>.from(response as List);
  }
}

// --------------------------------------------------------------------------
// Messages exchanged with the database isolate.
// --------------------------------------------------------------------------

enum _Operation {
  insert,
  insertBatch,
  import,
  update,
  delete,
  deleteBatch,
  getAll,
  getByType,
  getByTmdbId,
  isWatched,
  getRecent,
  getStats,
  getCount,
  close,
}

class _IsolateSetup {
  const _IsolateSetup(
      this.responses, this.databasePath, this.temporaryDirectory);

  final SendPort responses;
  final String databasePath;
  final String? temporaryDirectory;
}

class _Request {
  const _Request(this.id, this.operation, this.arguments);

  final int id;
  final _Operation operation;
  final List<Object?> arguments;
}

class _Response {
  const _Response(this.id, this.result, this.error);

  final int id;
  final Object? result;
  final String? error;
}

class _StartupFailure {
  const _StartupFailure(this.message);

  final String message;
}

// --------------------------------------------------------------------------
// Main isolate side: a request/response channel to the database isolate.
// --------------------------------------------------------------------------

class _DatabaseIsolate {
  _DatabaseIsolate._(this._responses);

  final ReceivePort _responses;
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Map<int, Completer<Object?>> _inFlight = {};

  Isolate? _isolate;
  SendPort? _commands;
  int _nextRequestId = 0;
  bool _stopped = false;

  bool get isStopped => _stopped;

  static Future<_DatabaseIsolate> spawn(
      String databasePath, String? temporaryDirectory) async {
    final channel = _DatabaseIsolate._(ReceivePort());
    channel._responses.listen(channel._onMessage);

    try {
      channel._isolate = await Isolate.spawn(
        _databaseIsolateMain,
        _IsolateSetup(
            channel._responses.sendPort, databasePath, temporaryDirectory),
        debugName: 'watch-history-db',
        onExit: channel._responses.sendPort,
        onError: channel._responses.sendPort,
      );
      channel._commands = await channel._ready.future;
    } catch (_) {
      channel._isolate?.kill(priority: Isolate.immediate);
      channel._responses.close();
      rethrow;
    }

    return channel;
  }

  Future<Object?> send(_Operation operation, List<Object?> arguments) {
    final commands = _commands;
    if (_stopped || commands == null) {
      return Future.error(
          WatchHistoryDatabaseException('The watch history database is closed'));
    }

    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _inFlight[id] = completer;
    commands.send(_Request(id, operation, arguments));
    return completer.future;
  }

  /// Disposes the connection and stops the isolate. The returned future only
  /// completes once the file handle is released, so callers may safely
  /// overwrite the database file afterwards.
  Future<void> close() async {
    if (_stopped) return;
    try {
      await send(_Operation.close, const []);
    } catch (_) {
      // Every failure here means the isolate died, which already released the
      // file, so the caller has nothing left to wait for.
    } finally {
      _stop('The watch history database is closed');
    }
  }

  void _onMessage(dynamic message) {
    if (!_ready.isCompleted) {
      if (message is SendPort) {
        _ready.complete(message);
      } else {
        _ready.completeError(
            WatchHistoryDatabaseException(_describeFailure(message)));
      }
      return;
    }

    if (message is _Response) {
      final completer = _inFlight.remove(message.id);
      if (completer == null) return;
      final error = message.error;
      if (error != null) {
        completer.completeError(WatchHistoryDatabaseException(error));
      } else {
        completer.complete(message.result);
      }
      return;
    }

    // `null` comes from onExit, a list from onError: either way the isolate is
    // gone and a later call has to spawn a fresh one.
    _stop(_describeFailure(message));
  }

  void _stop(String reason) {
    if (_stopped) return;
    _stopped = true;
    _responses.close();

    final pending = _inFlight.values.toList();
    _inFlight.clear();
    for (final completer in pending) {
      completer.completeError(WatchHistoryDatabaseException(reason));
    }
  }

  static String _describeFailure(Object? message) {
    if (message is _StartupFailure) return message.message;
    if (message is List && message.isNotEmpty) return '${message.first}';
    return 'The watch history database stopped unexpectedly';
  }
}

// --------------------------------------------------------------------------
// Database isolate side: owns the only sqlite3 connection.
// --------------------------------------------------------------------------

void _databaseIsolateMain(_IsolateSetup setup) {
  final Database database;
  try {
    database = _openDatabase(setup.databasePath, setup.temporaryDirectory);
  } catch (error) {
    setup.responses.send(_StartupFailure(error.toString()));
    return;
  }

  final commands = ReceivePort();
  commands.listen((message) {
    final request = message as _Request;

    if (request.operation == _Operation.close) {
      database.dispose();
      commands.close();
      setup.responses.send(_Response(request.id, null, null));
      return;
    }

    try {
      setup.responses
          .send(_Response(request.id, _runRequest(database, request), null));
    } catch (error) {
      setup.responses.send(_Response(request.id, null, error.toString()));
    }
  });

  setup.responses.send(commands.sendPort);
}

Database _openDatabase(String databasePath, String? temporaryDirectory) {
  if (temporaryDirectory != null) {
    sqlite3.tempDirectory = temporaryDirectory;
  }

  final database = sqlite3.open(databasePath);
  // The app copies the raw file around when exporting and restoring backups,
  // so the journal mode is deliberately left at the default: a single `.db`
  // file always holds the complete database.
  database.execute('PRAGMA busy_timeout = 5000');
  _migrate(database);
  return database;
}

void _migrate(Database db) {
  // Databases created before schema versioning report version 0 while already
  // holding the table, so the DDL below stays `IF NOT EXISTS` and the table
  // check keeps a restored backup from skipping it.
  if (db.userVersion >= _schemaVersion && _hasWatchHistoryTable(db)) return;

  db.execute('''
    CREATE TABLE IF NOT EXISTS $_tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tmdb_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('movie', 'tv')),
      poster_path TEXT,
      watched_at INTEGER NOT NULL,
      season_number INTEGER,
      episode_number INTEGER,
      episode_title TEXT,
      user_rating REAL,
      notes TEXT,
      UNIQUE(tmdb_id, type, season_number, episode_number)
    )
  ''');

  db.execute(
      'CREATE INDEX IF NOT EXISTS idx_watched_at ON $_tableName (watched_at DESC)');
  db.execute('CREATE INDEX IF NOT EXISTS idx_type ON $_tableName (type)');
  db.execute('CREATE INDEX IF NOT EXISTS idx_tmdb_id ON $_tableName (tmdb_id)');

  db.userVersion = _schemaVersion;
}

bool _hasWatchHistoryTable(Database db) {
  final result = db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
    [_tableName],
  );
  return result.isNotEmpty;
}

Object? _runRequest(Database db, _Request request) {
  final arguments = request.arguments;

  switch (request.operation) {
    case _Operation.insert:
      return _insertItem(db, arguments[0] as WatchHistoryItem);

    case _Operation.insertBatch:
      _insertItemsBatch(db, (arguments[0] as List).cast<WatchHistoryItem>());
      return null;

    case _Operation.import:
      _importItems(db, (arguments[0] as List).cast<WatchHistoryItem>());
      return null;

    case _Operation.update:
      _updateItem(db, arguments[0] as WatchHistoryItem);
      return null;

    case _Operation.delete:
      db.execute('DELETE FROM $_tableName WHERE id = ?', [arguments[0]]);
      return null;

    case _Operation.deleteBatch:
      _deleteItemsBatch(db, (arguments[0] as List).cast<int>());
      return null;

    case _Operation.getAll:
      return _selectItems(
          db, 'SELECT * FROM $_tableName ORDER BY watched_at DESC');

    case _Operation.getByType:
      return _selectItems(
        db,
        'SELECT * FROM $_tableName WHERE type = ? ORDER BY watched_at DESC',
        [arguments[0]],
      );

    case _Operation.getByTmdbId:
      return _selectItems(
        db,
        '''
        SELECT * FROM $_tableName
        WHERE tmdb_id = ? AND type = ?
        ORDER BY watched_at DESC
        ''',
        [arguments[0], arguments[1]],
      );

    case _Operation.isWatched:
      return _existingId(
            db,
            arguments[0] as int,
            arguments[1] as String,
            arguments[2] as int?,
            arguments[3] as int?,
          ) !=
          null;

    case _Operation.getRecent:
      return _selectItems(
        db,
        'SELECT * FROM $_tableName ORDER BY watched_at DESC LIMIT ?',
        [arguments[0]],
      );

    case _Operation.getStats:
      final counts = db.select('''
        SELECT type, COUNT(*) as count FROM $_tableName
        WHERE type IN ('movie', 'tv')
        GROUP BY type
      ''');
      final stats = {'movies': 0, 'shows': 0};
      for (final row in counts) {
        final key = row['type'] == 'movie' ? 'movies' : 'shows';
        stats[key] = row['count'] as int;
      }
      return stats;

    case _Operation.getCount:
      final row = db.select('SELECT COUNT(*) as count FROM $_tableName').first;
      return row['count'] as int;

    case _Operation.close:
      throw StateError('Handled by the isolate message loop');
  }
}

List<WatchHistoryItem> _selectItems(Database db, String sql,
    [List<Object?> parameters = const []]) {
  return db.select(sql, parameters).map(WatchHistoryItem.fromMap).toList();
}

int _insertItem(Database db, WatchHistoryItem item) {
  final existing = _existingId(
      db, item.tmdbId, item.type, item.seasonNumber, item.episodeNumber);
  if (existing != null) {
    _updateItem(db, item);
    return existing;
  }

  final statement = db.prepare('''
    INSERT INTO $_tableName (
      tmdb_id, title, type, poster_path, watched_at,
      season_number, episode_number, episode_title, user_rating, notes
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');

  try {
    statement.execute([
      item.tmdbId,
      item.title,
      item.type,
      item.posterPath,
      item.watchedAt.millisecondsSinceEpoch,
      item.seasonNumber,
      item.episodeNumber,
      item.episodeTitle,
      item.userRating,
      item.notes,
    ]);
  } on SqliteException catch (error) {
    if (!error.toString().contains('UNIQUE constraint failed')) rethrow;
    _updateItem(db, item);
    return _existingId(
            db, item.tmdbId, item.type, item.seasonNumber, item.episodeNumber) ??
        0;
  } finally {
    statement.dispose();
  }

  return db.lastInsertRowId;
}

void _importItems(Database db, List<WatchHistoryItem> items) {
  db.execute('BEGIN TRANSACTION');
  try {
    for (final item in items) {
      _insertItem(db, item);
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _insertItemsBatch(Database db, List<WatchHistoryItem> items) {
  db.execute('BEGIN TRANSACTION');
  final statement = db.prepare('''
    INSERT INTO $_tableName (
      tmdb_id, title, type, poster_path, watched_at,
      season_number, episode_number, episode_title, user_rating, notes
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');
  try {
    for (final item in items) {
      final existing = _existingId(
          db, item.tmdbId, item.type, item.seasonNumber, item.episodeNumber);
      if (existing != null) {
        _updateItem(db, item);
        continue;
      }

      try {
        statement.execute([
          item.tmdbId,
          item.title,
          item.type,
          item.posterPath,
          item.watchedAt.millisecondsSinceEpoch,
          item.seasonNumber,
          item.episodeNumber,
          item.episodeTitle,
          item.userRating,
          item.notes,
        ]);
      } on SqliteException catch (error) {
        if (!error.toString().contains('UNIQUE constraint failed')) rethrow;
        _updateItem(db, item);
      }
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.dispose();
  }
}

void _deleteItemsBatch(Database db, List<int> ids) {
  db.execute('BEGIN TRANSACTION');
  final statement = db.prepare('DELETE FROM $_tableName WHERE id = ?');
  try {
    for (final id in ids) {
      statement.execute([id]);
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.dispose();
  }
}

void _updateItem(Database db, WatchHistoryItem item) {
  db.execute('''
    UPDATE $_tableName SET
      title = ?, poster_path = ?, watched_at = ?,
      episode_title = ?, user_rating = ?, notes = ?
    WHERE tmdb_id = ? AND type = ? AND
          COALESCE(season_number, -1) = COALESCE(?, -1) AND
          COALESCE(episode_number, -1) = COALESCE(?, -1)
  ''', [
    item.title,
    item.posterPath,
    item.watchedAt.millisecondsSinceEpoch,
    item.episodeTitle,
    item.userRating,
    item.notes,
    item.tmdbId,
    item.type,
    item.seasonNumber,
    item.episodeNumber,
  ]);
}

int? _existingId(Database db, int tmdbId, String type, int? seasonNumber,
    int? episodeNumber) {
  final result = db.select('''
    SELECT id FROM $_tableName
    WHERE tmdb_id = ? AND type = ? AND
          COALESCE(season_number, -1) = COALESCE(?, -1) AND
          COALESCE(episode_number, -1) = COALESCE(?, -1)
    LIMIT 1
  ''', [tmdbId, type, seasonNumber, episodeNumber]);

  if (result.isEmpty) return null;
  return result.first['id'] as int;
}
