class CSManifest {
  final String name;
  final String description;
  final String iconUrl;
  final int manifestVersion;
  final List<String> pluginLists;

  CSManifest({
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.manifestVersion,
    required this.pluginLists,
  });

  factory CSManifest.fromJson(Map<String, dynamic> json) {
    return CSManifest(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      manifestVersion: json['manifestVersion'] ?? 1,
      pluginLists: List<String>.from(json['pluginLists'] ?? []),
    );
  }
}

class CSPlugin {
  final String url;
  final int status;
  final int version;
  final String name;
  final String internalName;
  final List<String> authors;
  final String description;
  final String language;
  final String iconUrl;
  final int apiVersion;
  final int fileSize;

  CSPlugin({
    required this.url,
    required this.status,
    required this.version,
    required this.name,
    required this.internalName,
    required this.authors,
    required this.description,
    required this.language,
    required this.iconUrl,
    required this.apiVersion,
    required this.fileSize,
  });

  factory CSPlugin.fromJson(Map<String, dynamic> json) {
    return CSPlugin(
      url: json['url'] ?? '',
      status: json['status'] ?? 0,
      version: json['version'] ?? 0,
      name: json['name'] ?? '',
      internalName: json['internalName'] ?? '',
      authors: List<String>.from(json['authors'] ?? []),
      description: json['description'] ?? '',
      language: json['language'] ?? 'en',
      iconUrl: json['iconUrl'] ?? '',
      apiVersion: json['apiVersion'] ?? 1,
      fileSize: json['fileSize'] ?? 0,
    );
  }
}
