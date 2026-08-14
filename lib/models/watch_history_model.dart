class WatchHistoryItem {
  final int? id;
  final int tmdbId;
  final String title;
  final String type; // 'movie' or 'tv'
  final String? posterPath;
  final DateTime watchedAt;
  final int? seasonNumber; // For TV shows
  final int? episodeNumber; // For TV shows
  final String? episodeTitle; // For TV shows
  final double? userRating; // Optional user rating
  final String? notes; // Optional user notes

  WatchHistoryItem({
    this.id,
    required this.tmdbId,
    required this.title,
    required this.type,
    this.posterPath,
    required this.watchedAt,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.userRating,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tmdb_id': tmdbId,
      'title': title,
      'type': type,
      'poster_path': posterPath,
      'watched_at': watchedAt.millisecondsSinceEpoch,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'episode_title': episodeTitle,
      'user_rating': userRating,
      'notes': notes,
    };
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory WatchHistoryItem.fromMap(Map<String, dynamic> map) {
    final watchedAtMs = _asInt(map['watched_at']);
    if (watchedAtMs == null) {
      throw ArgumentError('watch history item missing watched_at');
    }
    final tmdbId = _asInt(map['tmdb_id']);
    if (tmdbId == null) {
      throw ArgumentError('watch history item missing tmdb_id');
    }
    final title = map['title'];
    final type = map['type'];
    if (title is! String || type is! String) {
      throw ArgumentError('watch history item missing title/type');
    }

    return WatchHistoryItem(
      id: _asInt(map['id']),
      tmdbId: tmdbId,
      title: title,
      type: type,
      posterPath: map['poster_path'] as String?,
      watchedAt: DateTime.fromMillisecondsSinceEpoch(watchedAtMs),
      seasonNumber: _asInt(map['season_number']),
      episodeNumber: _asInt(map['episode_number']),
      episodeTitle: map['episode_title'] as String?,
      // Hive/web JSON often round-trips whole ratings as int.
      userRating: _asDouble(map['user_rating']),
      notes: map['notes'] as String?,
    );
  }

  WatchHistoryItem copyWith({
    int? id,
    int? tmdbId,
    String? title,
    String? type,
    String? posterPath,
    DateTime? watchedAt,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    double? userRating,
    String? notes,
  }) {
    return WatchHistoryItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      type: type ?? this.type,
      posterPath: posterPath ?? this.posterPath,
      watchedAt: watchedAt ?? this.watchedAt,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      userRating: userRating ?? this.userRating,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'WatchHistoryItem{id: $id, tmdbId: $tmdbId, title: $title, type: $type, watchedAt: $watchedAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchHistoryItem &&
        other.id == id &&
        other.tmdbId == tmdbId &&
        other.type == type &&
        other.seasonNumber == seasonNumber &&
        other.episodeNumber == episodeNumber;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        tmdbId.hashCode ^
        type.hashCode ^
        seasonNumber.hashCode ^
        episodeNumber.hashCode;
  }
} 