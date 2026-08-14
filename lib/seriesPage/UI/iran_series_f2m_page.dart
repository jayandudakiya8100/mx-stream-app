import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:Mirarr/moviesPage/functions/f2m_parser.dart';
import 'package:Mirarr/seriesPage/checkers/custom_tmdb_ids_effects_series.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';

class IranSeriesF2MPage extends StatefulWidget {
  final int serieId;
  final String serieName;
  final String imdbId;
  final List<F2MSeasonGroup> f2mGroups;

  const IranSeriesF2MPage({
    super.key,
    required this.serieId,
    required this.serieName,
    required this.imdbId,
    required this.f2mGroups,
  });

  @override
  State<IranSeriesF2MPage> createState() => _IranSeriesF2MPageState();
}

class _IranSeriesF2MPageState extends State<IranSeriesF2MPage> {
  late List<F2MSeasonGroup> _groups;
  bool _isLoading = false;
  String _selectedSeasonFilter = 'All';

  @override
  void initState() {
    super.initState();
    _groups = widget.f2mGroups;
    if (_groups.isEmpty) {
      _refreshF2M();
    }
  }

  Future<void> _refreshF2M() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final fetched = await fetchF2MDownloadLinks(widget.imdbId);
      if (mounted) {
        setState(() {
          _groups = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    } catch (_) {}
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text('URL copied to clipboard'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainColor = getSeriesColor(context, widget.serieId);

    final availableSeasons = <String>['All'];
    for (final group in _groups) {
      if (group.seasonName.isNotEmpty && !availableSeasons.contains(group.seasonName)) {
        availableSeasons.add(group.seasonName);
      }
    }

    final filteredGroups = _groups.where((group) {
      if (_selectedSeasonFilter == 'All') return true;
      return group.seasonName == _selectedSeasonFilter;
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.serieName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  'F2M Downloads',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇷', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'Iran Region',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: mainColor),
            )
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: mainColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.tv_off_outlined,
                            size: 40,
                            color: mainColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No F2M Downloads Available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No F2M downloads were found for this series right now.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Season Filter Dropdown Header
                    if (availableSeasons.length > 2)
                      Padding(
                        key: const ValueKey('season_filter_dropdown_header'),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_list_rounded, size: 20, color: mainColor),
                              const SizedBox(width: 10),
                              Text(
                                'Season:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: availableSeasons.contains(_selectedSeasonFilter)
                                        ? _selectedSeasonFilter
                                        : 'All',
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down_rounded, color: mainColor),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: mainColor,
                                    ),
                                    dropdownColor: theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(14),
                                    onChanged: (String? newValue) {
                                      if (newValue != null && newValue != _selectedSeasonFilter) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _selectedSeasonFilter = newValue;
                                            });
                                          }
                                        });
                                      }
                                    },
                                    items: availableSeasons.map((season) {
                                      return DropdownMenuItem<String>(
                                        value: season,
                                        child: Text(season),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Season Dropdown Accordions
                    ...filteredGroups.map((group) {
                      return _SeasonDropdownCard(
                        key: ObjectKey(group),
                        group: group,
                        theme: theme,
                        mainColor: mainColor,
                        initiallyExpanded: false,
                        onLaunchUrl: _launchUrl,
                        onCopyUrl: _copyToClipboard,
                      );
                    }).toList(),

                    const SizedBox(key: ValueKey('bottom_spacing'), height: 24),
                  ],
                ),
    );
  }
}

class _SeasonDropdownCard extends StatefulWidget {
  final F2MSeasonGroup group;
  final ThemeData theme;
  final Color mainColor;
  final bool initiallyExpanded;
  final Future<void> Function(String url) onLaunchUrl;
  final Future<void> Function(String url) onCopyUrl;

  const _SeasonDropdownCard({
    super.key,
    required this.group,
    required this.theme,
    required this.mainColor,
    required this.initiallyExpanded,
    required this.onLaunchUrl,
    required this.onCopyUrl,
  });

  @override
  State<_SeasonDropdownCard> createState() => _SeasonDropdownCardState();
}

class _SeasonDropdownCardState extends State<_SeasonDropdownCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final theme = widget.theme;
    final mainColor = widget.mainColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Dropdown Header Button
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mainColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.video_library_rounded,
                        color: mainColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.seasonName.isNotEmpty ? group.seasonName : 'Downloads',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${group.items.length} quality ${group.items.length == 1 ? 'option' : 'options'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dropdown Content
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: group.items.map((item) {
                    return _buildF2MItemCard(
                        theme, mainColor, item, widget.onLaunchUrl, widget.onCopyUrl);
                  }).toList(),
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildF2MItemCard(
    ThemeData theme,
    Color mainColor,
    F2MDownloadItem item,
    Future<void> Function(String url) onLaunchUrl,
    Future<void> Function(String url) onCopyUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveInteractiveContainer(
        borderRadius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quality Title as Main Title
              Row(
                children: [
                  Icon(Icons.cloud_download_outlined, size: 18, color: mainColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Tag Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMetaChip(
                    theme,
                    'F2M',
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.onSurfaceVariant,
                  ),
                  ...item.extraTags.map((tag) {
                    Color tagBg = Colors.teal.withValues(alpha: 0.2);
                    Color tagText = Colors.teal;
                    if (tag.contains('Dubbed')) {
                      tagBg = Colors.amber.withValues(alpha: 0.2);
                      tagText = Colors.amber;
                    } else if (tag.contains('Sub')) {
                      tagBg = Colors.blue.withValues(alpha: 0.2);
                      tagText = Colors.blue;
                    }
                    return _buildMetaChip(theme, tag, tagBg, tagText);
                  }),
                  if (item.quality.isNotEmpty && item.quality != item.title)
                    _buildMetaChip(
                      theme,
                      item.quality,
                      Colors.blue.withValues(alpha: 0.2),
                      Colors.blue,
                    ),
                  if (item.encoder.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      item.encoder,
                      Colors.purple.withValues(alpha: 0.2),
                      Colors.purple,
                    ),
                  if (item.size.isNotEmpty)
                    _buildMetaChip(
                      theme,
                      item.size,
                      mainColor.withValues(alpha: 0.2),
                      mainColor,
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Download links
              ...item.links.map((link) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              link.label,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => onLaunchUrl(link.url),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Copy Link',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => onCopyUrl(link.url),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(
      ThemeData theme, String label, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textCol,
        ),
      ),
    );
  }
}
