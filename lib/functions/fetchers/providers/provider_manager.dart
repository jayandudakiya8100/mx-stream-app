import 'core/base_provider.dart';
import 'VegaMovies/vega_movies_provider.dart';

class ProviderManager {
  static final Map<String, BaseProvider> _providers = {
    'VegaMovies': VegaMoviesProviderImpl(),
  };

  static BaseProvider? getProvider(String name) {
    for (var key in _providers.keys) {
      if (key.toLowerCase() == name.toLowerCase()) {
        return _providers[key];
      }
    }
    return null;
  }

  static List<String> get availableProviders => _providers.keys.toList();
}
