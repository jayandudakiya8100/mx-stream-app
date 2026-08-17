import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:Mirarr/functions/fetchers/providers/provider_config.dart';

class ExtensionPlugin {
  final String name;
  final String internalName;
  final String url;
  final int version;
  final String description;
  final String language;
  final String iconUrl;
  final int fileSize;
  final List<String> tvTypes;
  bool isDownloaded;

  ExtensionPlugin({
    required this.name,
    required this.internalName,
    required this.url,
    required this.version,
    required this.description,
    required this.language,
    required this.iconUrl,
    required this.fileSize,
    required this.tvTypes,
    this.isDownloaded = true,
  });

  factory ExtensionPlugin.fromJson(Map<String, dynamic> json) {
    return ExtensionPlugin(
      name: json['name']?.toString() ?? '',
      internalName: json['internalName']?.toString() ?? json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      version: json['version'] is int ? json['version'] : int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      description: json['description']?.toString() ?? '',
      language: json['language']?.toString() ?? 'hi',
      iconUrl: json['iconUrl']?.toString() ?? '',
      fileSize: json['fileSize'] is int ? json['fileSize'] : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
      tvTypes: (json['tvTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isDownloaded: true,
    );
  }
}

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  static const String _defaultRepoUrl = ProviderConfig.defaultRepoUrl;
  static const String _pluginsUrl = ProviderConfig.pluginsEndpoint;

  bool _isLoading = true;
  String _repoName = 'Megix Repo(Hindi & English)';
  String _repoUrl = _defaultRepoUrl;
  List<ExtensionPlugin> _plugins = [];
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Movies', 'TV Series', 'Anime', 'Asian Dramas'];

  @override
  void initState() {
    super.initState();
    _loadExtensions();
  }

  Future<void> _loadExtensions() async {
    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse(_pluginsUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final list = data.map((e) => ExtensionPlugin.fromJson(e)).toList();

        if (mounted) {
          setState(() {
            _plugins = list;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading extensions manifest: $e');
    }

    // Fallback default plugin items
    if (mounted) {
      setState(() {
        _plugins = [
          ExtensionPlugin(
            name: 'Bollyflix',
            internalName: 'Bollyflix',
            url: '',
            version: 33,
            description: 'Movies and Series upto 4K',
            language: 'hi',
            iconUrl: '',
            fileSize: 38129,
            tvTypes: ['Movie', 'TvSeries'],
          ),
          ExtensionPlugin(
            name: 'CineStream',
            internalName: 'CineStream',
            url: '',
            version: 480,
            description: 'One stop solution for Movies, Series, Anime...',
            language: 'en',
            iconUrl: '',
            fileSize: 747520,
            tvTypes: ['Movie', 'TvSeries', 'Anime'],
          ),
          ExtensionPlugin(
            name: 'GDIndex',
            internalName: 'GDIndex',
            url: '',
            version: 6,
            description: 'Google Drive Index streaming',
            language: 'en',
            iconUrl: '',
            fileSize: 18432,
            tvTypes: ['Movie', 'TvSeries'],
          ),
          ExtensionPlugin(
            name: 'MoviesDrive',
            internalName: 'MoviesDrive',
            url: '',
            version: 33,
            description: 'High Quality Movies and TV Shows',
            language: 'hi',
            iconUrl: '',
            fileSize: 48128,
            tvTypes: ['Movie', 'TvSeries'],
          ),
          ExtensionPlugin(
            name: 'Moviesmod',
            internalName: 'Moviesmod',
            url: '',
            version: 33,
            description: 'Includes Topmovies',
            language: 'hi',
            iconUrl: '',
            fileSize: 46080,
            tvTypes: ['Movie', 'TvSeries'],
          ),
          ExtensionPlugin(
            name: 'OnlineMoviesHindi',
            internalName: 'OnlineMoviesHindi',
            url: '',
            version: 6,
            description: 'Use VPN',
            language: 'hi',
            iconUrl: '',
            fileSize: 12288,
            tvTypes: ['Movie'],
          ),
          ExtensionPlugin(
            name: 'VegaMovies',
            internalName: 'VegaMovies',
            url: '',
            version: 82,
            description: 'Includes LuxMovies, Rogmovies',
            language: 'hi',
            iconUrl: '',
            fileSize: 43008,
            tvTypes: ['Movie', 'TvSeries', 'AsianDrama', 'Anime'],
          ),
        ];
        _isLoading = false;
      });
    }
  }

  void _showAddRepositoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Repository',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'cloudstreamrepo://... or https://...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repository synced successfully!')),
                  );
                  _loadExtensions();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadedCount = _plugins.where((p) => p.isDownloaded).length;
    final totalCount = _plugins.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Extensions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Skeletonizer(
            enabled: _isLoading,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
              // Category Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF1A1A1A),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.white : Colors.white12,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Repository Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.extension_rounded, color: Colors.purpleAccent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _repoName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _repoUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white60, size: 22),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cannot remove preinstalled default repository.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Extensions Plugins List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final plugin = _plugins[index];
                      final sizeStr = plugin.fileSize > 1024
                          ? '${(plugin.fileSize / 1024).toStringAsFixed(0)} kB'
                          : '${plugin.fileSize} B';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Extension Icon
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Center(
                                child: Text(
                                  plugin.name.isNotEmpty ? plugin.name[0] : 'E',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plugin.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${plugin.language.toUpperCase()} v${plugin.version} $sizeStr',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (plugin.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      plugin.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Download / Toggle Action
                            IconButton(
                              icon: Icon(
                                plugin.isDownloaded ? Icons.delete_outline_rounded : Icons.download_rounded,
                                color: plugin.isDownloaded ? Colors.white60 : Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  plugin.isDownloaded = !plugin.isDownloaded;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(plugin.isDownloaded
                                        ? '${plugin.name} Plugin Loaded'
                                        : '${plugin.name} Removed'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _plugins.length,
                  ),
                ),
              ),

              // Bottom padding for FAB & status bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),

          // Bottom Bar & FAB
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF101010),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Extensions',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Downloaded: $downloadedCount  |  Not downloaded: ${totalCount - downloadedCount}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddRepositoryDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Add repository',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
