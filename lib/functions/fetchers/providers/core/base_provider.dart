import 'models.dart';

abstract class BaseProvider {
  String get name;
  String get lang;

  /// Get Home Page & Category Feeds
  Future<List<ProviderSearchItem>> getMainPage({String category = 'home', int page = 1});

  /// Search Endpoint
  Future<List<ProviderSearchItem>> search(String query, {int page = 1});

  /// Load Details & Scrape Stream Links
  Future<ProviderMediaDetails?> loadDetails(String url, {bool skipSources = false});

  /// Extract Final Stream Links from a Video Source URL
  Future<List<StreamLink>> extractStream(String url);
}
