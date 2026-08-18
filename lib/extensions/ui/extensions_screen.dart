import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/extension_models.dart';
import '../services/extension_service.dart';
import 'package:Mirarr/functions/fetchers/providers/media_provider_service.dart';

class ExtensionsScreen extends StatefulWidget {
  final String repoUrl;
  
  const ExtensionsScreen({super.key, required this.repoUrl});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  CSManifest? _manifest;
  List<CSPlugin> _plugins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRepo();
  }

  Future<void> _fetchRepo() async {
    setState(() => _isLoading = true);
    final manifest = await ExtensionService.fetchManifest(widget.repoUrl);
    if (manifest != null && manifest.pluginLists.isNotEmpty) {
      final plugins = await ExtensionService.fetchPlugins(manifest.pluginLists.first);
      setState(() {
        _manifest = manifest;
        _plugins = plugins;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          _manifest?.name ?? 'Repository',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plugins.isEmpty
              ? const Center(
                  child: Text('No plugins found', style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  itemCount: _plugins.length,
                  itemBuilder: (context, index) {
                    final plugin = _plugins[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: plugin.iconUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: plugin.iconUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const Icon(Icons.extension),
                              ),
                            )
                          : const Icon(Icons.extension, size: 48, color: Colors.white70),
                      title: Text(
                        plugin.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${plugin.language.toUpperCase()} • v${plugin.version} • ${(plugin.fileSize! / 1024).toStringAsFixed(0)} kB',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plugin.description,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white70),
                        onPressed: () async {
                          await MediaProviderService.installProvider(
                            plugin.internalName,
                            plugin.name,
                            plugin.url,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Installed ${plugin.name}')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
