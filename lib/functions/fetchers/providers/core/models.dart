class ProviderSearchItem {
  final String title;
  final String url;
  final String poster;
  final String type; // 'movie' or 'series'

  ProviderSearchItem({
    required this.title,
    required this.url,
    required this.poster,
    required this.type,
  });
}

class VideoSource {
  final String resolution;
  final String url;

  VideoSource({
    required this.resolution,
    required this.url,
  });
}

class EpisodeInfo {
  final int season;
  final int episode;
  final String name;
  final String? poster;
  final String? description;
  final List<VideoSource> sources;

  EpisodeInfo({
    required this.season,
    required this.episode,
    required this.name,
    this.poster,
    this.description,
    this.sources = const [],
  });
}

class ProviderMediaDetails {
  final String title;
  final String url;
  final String type;
  final String poster;
  final String background;
  final String plot;
  final int? year;
  final String rating;
  final String audioTitle;
  final List<String> audioLanguages;
  final List<String> tags;
  final List<String> cast;
  final String imdbUrl;
  final List<VideoSource> sources; // For movies
  final List<EpisodeInfo> episodes; // For series

  ProviderMediaDetails({
    required this.title,
    required this.url,
    required this.type,
    required this.poster,
    required this.background,
    required this.plot,
    this.year,
    required this.rating,
    required this.audioTitle,
    required this.audioLanguages,
    required this.tags,
    required this.cast,
    required this.imdbUrl,
    this.sources = const [],
    this.episodes = const [],
  });
}

class StreamLink {
  final String name;
  final String streamUrl;
  final String quality;
  final bool isHls;

  StreamLink({
    required this.name,
    required this.streamUrl,
    required this.quality,
    this.isHls = false,
  });
}
