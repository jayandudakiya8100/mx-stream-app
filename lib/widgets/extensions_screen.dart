import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:mxstream/functions/fetchers/providers/provider_config.dart';
import 'package:mxstream/functions/fetchers/providers/media_provider_service.dart';

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

class ExtensionsRepoScreen extends StatelessWidget {
  const ExtensionsRepoScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExtensionsScreen(
                    repoUrl: ProviderConfig.defaultRepoUrl,
                    repoName: 'Megix Repo(Hindi & English)',
                  ),
                ),
              );
            },
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.extension, color: Colors.white70),
            ),
            title: const Text(
              'Megix Repo(Hindi & English)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text(
              'https://raw.githubusercontent.com/SaurabhKaperw...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ExtensionsScreen extends StatefulWidget {
  final String? repoUrl;
  final String? repoName;
  const ExtensionsScreen({super.key, this.repoUrl, this.repoName});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  static const String _defaultRepoUrl = ProviderConfig.defaultRepoUrl;
  static const String _pluginsUrl = ProviderConfig.pluginsEndpoint;

  bool _isLoading = true;
  late String _repoName;
  late String _repoUrl;
  List<ExtensionPlugin> _plugins = [];
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Movies', 'TV Series', 'Anime', 'Asian Dramas'];

  @override
  void initState() {
    super.initState();
    _repoUrl = widget.repoUrl ?? _defaultRepoUrl;
    _repoName = widget.repoName ?? 'Megix Repo(Hindi & English)';
    _loadExtensions();
  }

  Future<void> _loadExtensions() async {
    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse(_pluginsUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final disabled = MediaProviderService.getDisabledProviders();
        debugPrint('[Extensions] Fetched ${data.length} providers from $_pluginsUrl');
        debugPrint('[Extensions] Raw extension data: ${res.body}');
        
        final list = data.map((e) {
          final plugin = ExtensionPlugin.fromJson(e);
          plugin.isDownloaded = !disabled.contains(plugin.internalName);
          
          debugPrint('[Extensions] Installing provider: ${plugin.name} (v${plugin.version}) - Internal: ${plugin.internalName}');
          debugPrint('[Extensions] Types: ${plugin.tvTypes}, Size: ${plugin.fileSize}KB');
          
          MediaProviderService.installProvider(plugin.internalName, plugin.name, plugin.url);
          return plugin;
        }).toList();

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
      final disabled = MediaProviderService.getDisabledProviders();
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
          )..isDownloaded = !disabled.contains('Bollyflix'),
          ExtensionPlugin(
            name: 'CineStream',
            internalName: 'CineStream',
            url: '',
            version: 11,
            description: 'Movies and Series',
            language: 'hi',
            iconUrl: '',
            fileSize: 18129,
            tvTypes: ['Movie', 'TvSeries'],
          )..isDownloaded = !disabled.contains('CineStream'),
          ExtensionPlugin(
            name: 'GDIndex',
            internalName: 'GDIndex',
            url: '',
            version: 7,
            description: 'Movies and Series',
            language: 'en',
            iconUrl: '',
            fileSize: 7129,
            tvTypes: ['Movie', 'TvSeries'],
          )..isDownloaded = !disabled.contains('GDIndex'),
          ExtensionPlugin(
            name: 'MoviesDrive',
            internalName: 'MoviesDrive',
            url: '',
            version: 5,
            description: 'Movies and Series',
            language: 'hi',
            iconUrl: '',
            fileSize: 22129,
            tvTypes: ['Movie', 'TvSeries'],
          )..isDownloaded = !disabled.contains('MoviesDrive'),
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
        
        // Ensure all fallback plugins are installed
        for (final p in _plugins) {
          debugPrint('[Extensions] Fallback installing provider: ${p.name} (v${p.version})');
          MediaProviderService.installProvider(p.internalName, p.name, p.url);
        }
        
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
        title: Text(
          _repoName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          Skeletonizer(
            enabled: _isLoading,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
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
                                    '${plugin.language.toUpperCase()} • v${plugin.version} • $sizeStr',
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
                            Switch.adaptive(
                              value: plugin.isDownloaded,
                              activeColor: const Color(0xFF6366F1), // A modern indigo
                              onChanged: (bool value) async {
                                setState(() {
                                  plugin.isDownloaded = value;
                                });
                                await MediaProviderService.toggleProvider(plugin.internalName, value);
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

              // Bottom padding for status bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}
