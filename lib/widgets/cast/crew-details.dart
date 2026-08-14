import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:Mirarr/functions/get_base_url.dart';
import 'package:Mirarr/functions/regionprovider_class.dart';
import 'package:Mirarr/moviesPage/functions/on_tap_movie.dart';
import 'package:flutter/material.dart';
import 'package:Mirarr/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Mirarr/widgets/custom_divider.dart';
import 'package:Mirarr/widgets/image_gallery_page.dart';
import 'package:Mirarr/widgets/m3_expressive_spinner.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:provider/provider.dart';

class CrewDetailPage extends StatefulWidget {
  const CrewDetailPage({Key? key, required this.castId}) : super(key: key);
  final int castId;

  @override
  _CrewDetailPageState createState() => _CrewDetailPageState();
}

bool _showIcon = true;
final apiKey = dotenv.env['TMDB_API_KEY'];

class _CrewDetailPageState extends State<CrewDetailPage> {
  late Future<Map<String, dynamic>> _castDetailsFuture;
  late Future<List<String>> _castImagesFuture;
  late Future<List<dynamic>> _otherMoviesFuture;

  @override
  void initState() {
    super.initState();
    _castDetailsFuture = _fetchCastDetails(widget.castId);
    _castImagesFuture = _fetchCastImages(widget.castId);
    _otherMoviesFuture = _fetchOtherMovies(widget.castId);
    _startTimer();
  }

  void _startTimer() {
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _showIcon = false;
      });
    });
  }

  Future<Map<String, dynamic>> _fetchCastDetails(int castId) async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final response = await apiClient.get(
      Uri.parse('${baseUrl}person/$castId?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load cast details');
    }
  }

  Future<List<dynamic>> _fetchOtherMovies(int castId) async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final response = await apiClient.get(
      Uri.parse('${baseUrl}person/$castId/movie_credits?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> movies = decoded['crew'];

      Set<int> movieIds = {};

      List<dynamic> filteredMovies = [];

      for (var movie in movies) {
        if (movie['poster_path'] != null && movie['poster_path'] != '') {
          if (!movieIds.contains(movie['id'])) {
            filteredMovies.add(movie);
            movieIds.add(movie['id']);
          }
        }
      }
      return filteredMovies;
    } else {
      throw Exception('Failed to load other movies');
    }
  }

  Future<List<String>> _fetchCastImages(int castId) async {
    final region =
        Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final baseUrl = getBaseUrl(region);
    final response = await apiClient.get(
      Uri.parse('${baseUrl}person/$castId/images?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['profiles'];
      return data.map((image) => image['file_path'] as String).toList();
    } else {
      throw Exception('Failed to load cast images');
    }
  }

  void _openImageGallery(List<String> imageUrls) {
    Navigator.push(
      context,
      ExpressivePageRoute(
        page: ImageGalleryPage(imageUrls: imageUrls),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _castDetailsFuture,
      builder: (context, snapshot) {
        String crewName = '';
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            crewName = 'Error';
          } else if (snapshot.hasData) {
            crewName = snapshot.data!['name'];
          }
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              crewName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const M3ExpressiveSpinner()
              : snapshot.hasError
                  ? Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)))
                  : _buildContent(snapshot.data!),
        );
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> castData) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 800;

    return isMobileLayout
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    _castImagesFuture.then((imageUrls) {
                      _openImageGallery(imageUrls);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          castData['profile_path'] == null
                              ? Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  height: 360,
                                  width: double.infinity,
                                  child: Icon(Icons.person_rounded, size: 80, color: colorScheme.onSurfaceVariant),
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      '${getImageBaseUrl(region)}/t/p/w500${castData['profile_path']}',
                                  memCacheWidth: 400,
                                  maxWidthDiskCache: 500,
                                  placeholder: (context, url) => Container(
                                    height: 360,
                                    color: colorScheme.surfaceContainerHigh,
                                    child: const M3ExpressiveSpinner(),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 360,
                                    color: colorScheme.surfaceContainerHigh,
                                    child: Icon(Icons.error_outline, color: colorScheme.error),
                                  ),
                                  imageBuilder: (context, imageProvider) => Container(
                                    height: 360,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: imageProvider,
                                      ),
                                    ),
                                  ),
                                ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.black.withValues(alpha: 0.85),
                                  ],
                                  stops: const [0.3, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  castData['name']!,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                if (castData['birthday'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Born: ${castData['birthday']}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (castData['biography'] != null && castData['biography'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: colorScheme.primary,
                          collapsedIconColor: colorScheme.onSurfaceVariant,
                          title: Text(
                            'Biography',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                castData['biography'],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Crew Credits',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _buildOtherMoviesGrid(),
              ],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: () {
                      _castImagesFuture.then((imageUrls) {
                        _openImageGallery(imageUrls);
                      });
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: castData['profile_path'] == null
                              ? Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  height: 400,
                                  width: double.infinity,
                                  child: Icon(Icons.person_rounded, size: 100, color: colorScheme.onSurfaceVariant),
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      '${getImageBaseUrl(region)}/t/p/w500${castData['profile_path']}',
                                  memCacheWidth: 400,
                                  maxWidthDiskCache: 500,
                                  placeholder: (context, url) => const M3ExpressiveSpinner(),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                  imageBuilder: (context, imageProvider) => Container(
                                    height: 400,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: imageProvider,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          castData['name']!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (castData['biography'] != null && castData['biography'].toString().isNotEmpty) ...[
                          Text(
                            'Biography',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            castData['biography'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          'Crew Credits',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildOtherMoviesGrid(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildOtherMoviesGrid() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<dynamic>>(
      future: _otherMoviesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const M3ExpressiveSpinner();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading movies', style: TextStyle(color: colorScheme.error)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No movies found'));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) {
            final movie = snapshot.data![index];
            return _buildMovieItem(movie);
          },
        );
      },
    );
  }

  Widget _buildMovieItem(dynamic movie) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final region = Provider.of<RegionProvider>(context, listen: false).currentRegion;

    return TvFocusWrapper(
      borderRadius: 20.0,
      onTap: () => onTapMovie(movie['title'], movie['id'], context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceContainerHigh,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (movie['poster_path'] != null && movie['poster_path'] != '')
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: '${getImageBaseUrl(region)}/t/p/w500${movie['poster_path']}',
                    fit: BoxFit.cover,
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  movie['title'] ?? '',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

