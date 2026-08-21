import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:mxstream/functions/fetchers/providers/provider_config.dart';
import 'package:mxstream/functions/fetchers/providers/media_provider_service.dart';

class NewExtensionPlugin {
  final String name;
  final String internalName;
  final String url;
  final int version;
  final String description;
  final String language;
  final String iconUrl;
  final int fileSize;
  final List<String> tvTypes;
  final List<String> authors;
  final bool isLiveURL;
  String? liveURL;
  bool isDownloaded;

  NewExtensionPlugin({
    required this.name,
    required this.internalName,
    required this.url,
    required this.version,
    required this.description,
    required this.language,
    required this.iconUrl,
    required this.fileSize,
    required this.tvTypes,
    required this.authors,
    this.isLiveURL = false,
    this.liveURL,
    this.isDownloaded = true,
  });

  factory NewExtensionPlugin.fromJson(Map<String, dynamic> json) {
    return NewExtensionPlugin(
      name: json['name']?.toString() ?? '',
      internalName: json['internalName']?.toString() ?? json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      version: json['version'] is int ? json['version'] : int.tryParse(json['version']?.toString() ?? '1') ?? 1,
      description: json['description']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en',
      iconUrl: json['iconUrl']?.toString() ?? '',
      fileSize: json['fileSize'] is int ? json['fileSize'] : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
      tvTypes: (json['tvTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      authors: (json['authors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isLiveURL: json['isLiveURL'] == true,
      liveURL: json['liveURL']?.toString(), // Handled in merging step
      isDownloaded: true,
    );
  }
}

class NewExtensionsRepoScreen extends StatelessWidget {
  const NewExtensionsRepoScreen({super.key});

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
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: const [],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewExtensionsScreen(
                    repoUrl: ProviderConfig.defaultRepoUrl,
                    repoName: 'Megix Repo(Hindi & English)',
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: Colors.white12,
              backgroundImage: const NetworkImage('https://wsrv.nl/?url=https://avatars.githubusercontent.com/u/91174352&mask=circle'),
              child: Container(),
            ),
            title: const Text(
              'Megix Repo(Hindi & English)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
            ),
            subtitle: const Text(
              'https://raw.githubusercontent.com/SaurabhKaperw...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF141414),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extensions',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatDot(Colors.white, 'Downloaded: 7'),
                const SizedBox(width: 12),
                _buildStatDot(const Color(0xFF6366F1), 'Disabled: 0'),
                const SizedBox(width: 12),
                _buildStatDot(Colors.white54, 'Not downloaded: 0'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class NewExtensionsScreen extends StatefulWidget {
  final String? repoUrl;
  final String? repoName;
  const NewExtensionsScreen({super.key, this.repoUrl, this.repoName});

  @override
  State<NewExtensionsScreen> createState() => _NewExtensionsScreenState();
}

class _NewExtensionsScreenState extends State<NewExtensionsScreen> {
  static const String _defaultRepoUrl = ProviderConfig.defaultRepoUrl;
  static const String _urlsEndpoint = ProviderConfig.urlsEndpoint;

  bool _isLoading = true;
  late String _repoName;
  late String _repoUrl;
  List<NewExtensionPlugin> _plugins = [];

  @override
  void initState() {
    super.initState();
    _repoUrl = widget.repoUrl ?? _defaultRepoUrl;
    _repoName = widget.repoName ?? 'Megix Repo(Hindi & English)';
    _loadExtensionsProperFlow();
  }

  Future<void> _loadExtensionsProperFlow() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch CS.json
      final csRes = await http.get(Uri.parse(_repoUrl)).timeout(const Duration(seconds: 8));
      if (csRes.statusCode == 200) {
        final csData = json.decode(csRes.body);
        final List<dynamic> pluginLists = csData['pluginLists'] ?? [];
        if (pluginLists.isNotEmpty) {
          final pluginsUrl = pluginLists.first.toString();
          
          // 2. Fetch plugins.json
          final pluginsRes = await http.get(Uri.parse(pluginsUrl)).timeout(const Duration(seconds: 8));
          if (pluginsRes.statusCode == 200) {
            final List<dynamic> pluginsData = json.decode(pluginsRes.body);
            
            // 3. Fetch urls.json
            Map<String, dynamic> urlsMap = {};
            try {
              final urlsRes = await http.get(Uri.parse(_urlsEndpoint)).timeout(const Duration(seconds: 8));
              if (urlsRes.statusCode == 200) {
                urlsMap = json.decode(urlsRes.body);
              }
            } catch (e) {
              debugPrint('Error fetching urls.json: $e');
            }

            final disabled = MediaProviderService.getDisabledProviders();
            
            final list = pluginsData.map((e) {
              final plugin = NewExtensionPlugin.fromJson(e);
              plugin.isDownloaded = !disabled.contains(plugin.internalName);
              
              // Map liveURL
              final key = plugin.internalName.toLowerCase();
              if (urlsMap.containsKey(key)) {
                plugin.liveURL = urlsMap[key]?.toString();
              }
              
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
        }
      }
    } catch (e) {
      debugPrint('Error loading extensions flow: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProviderBottomSheet(NewExtensionPlugin plugin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white12,
                      image: plugin.iconUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(plugin.iconUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: plugin.iconUrl.isEmpty
                        ? Center(child: Text(plugin.name[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      plugin.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Description', plugin.description.isNotEmpty ? plugin.description : 'No description'),
              _buildInfoRow('Authors', plugin.authors.join(', ')),
              _buildInfoRow('Version', plugin.version.toString()),
              _buildInfoRow('Status', 'Ok'),
              _buildInfoRow('Size', '${(plugin.fileSize / 1024).toStringAsFixed(2)} kB'),
              _buildInfoRow('Supported', plugin.tvTypes.join(', ')),
              _buildInfoRow('Language', plugin.language == 'hi' ? '🇮🇳 Hindi' : (plugin.language == 'en' ? '🇬🇧 English' : plugin.language)),
              if (plugin.liveURL != null)
                _buildInfoRow('Live URL', plugin.liveURL!),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

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
        title: Text(
          _repoName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [],
      ),
      body: Skeletonizer(
        enabled: _isLoading,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: _isLoading ? 5 : _plugins.length,
          itemBuilder: (context, index) {
            if (_isLoading) {
              return _buildDummyItem();
            }
            final plugin = _plugins[index];
            return ListTile(
              onTap: () => _showProviderBottomSheet(plugin),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white12,
                  image: plugin.iconUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(plugin.iconUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: plugin.iconUrl.isEmpty
                    ? Center(child: Text(plugin.name[0], style: const TextStyle(color: Colors.white)))
                    : null,
              ),
              title: Text(
                plugin.name,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(plugin.language == 'hi' ? '🇮🇳' : (plugin.language == 'en' ? '🇬🇧' : ''), style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${plugin.language == 'hi' ? 'Hindi' : 'English'} v${plugin.version} ${(plugin.fileSize / 1024).toStringAsFixed(0)} kB',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plugin.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDummyItem() {
    return ListTile(
      leading: Container(width: 40, height: 40, color: Colors.white),
      title: Container(width: 100, height: 16, color: Colors.white),
      subtitle: Container(width: 200, height: 12, color: Colors.white),
    );
  }
}
