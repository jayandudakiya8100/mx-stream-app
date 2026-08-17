import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/functions/fetchers/providers/provider_config.dart';
import 'package:Mirarr/models/watch_history_model.dart';

class WatchStatusManager {
  static const String boxName = 'sessionBox';
  static const String _statusPrefix = 'watch_status_';

  /// Global notifier to trigger reactive UI updates across all listening screens
  static final ValueNotifier<int> watchStatusNotifier = ValueNotifier<int>(0);

  /// 100% deterministic persistent media ID
  static int getStableMediaId(String input) {
    return ProviderConfig.getStableMediaId(input);
  }

  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'Watching':
        return Icons.play_circle_filled_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'On-Hold':
        return Icons.pause_circle_filled_rounded;
      case 'Dropped':
        return Icons.cancel_rounded;
      case 'Plan to Watch':
        return Icons.bookmark_rounded;
      case 'Favorites':
        return Icons.favorite_rounded;
      default:
        return Icons.bookmark_border_rounded;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Watching':
        return const Color(0xFF4CAF50);
      case 'Completed':
        return const Color(0xFF2196F3);
      case 'On-Hold':
        return const Color(0xFFFFB300);
      case 'Dropped':
        return const Color(0xFFE53935);
      case 'Plan to Watch':
        return const Color(0xFFAB47BC);
      case 'Favorites':
        return const Color(0xFFE91E63);
      default:
        return Colors.white70;
    }
  }

  static String getStatus(int tmdbId) {
    try {
      final box = Hive.box(boxName);
      final val = box.get('$_statusPrefix$tmdbId');
      if (val is String && val.isNotEmpty) {
        return val;
      }
    } catch (_) {}
    return 'None';
  }

  static Future<void> setStatus({
    required int tmdbId,
    required String title,
    required String status,
    String? posterPath,
    String type = 'movie',
    String? permalink,
    String? providerName,
  }) async {
    try {
      final box = Hive.box(boxName);
      final db = WatchHistoryDatabase();

      if (status == 'None') {
        // DELETE / REMOVE CRUD
        await box.delete('$_statusPrefix$tmdbId');
        await box.delete('provider_media_meta_$tmdbId');

        try {
          final existing = await db.getWatchHistoryByTmdbId(tmdbId, type);
          for (final item in existing) {
            if (item.id != null) {
              await db.deleteWatchHistoryItem(item.id!);
            }
          }
        } catch (_) {}
      } else {
        // CREATE / UPDATE CRUD
        await box.put('$_statusPrefix$tmdbId', status);

        // Persist full provider metadata so it can be restored on ShelfPage
        await box.put('provider_media_meta_$tmdbId', {
          'id': tmdbId,
          'title': title,
          'posterPath': posterPath,
          'permalink': permalink ?? '',
          'providerName': providerName ?? 'VegaMovies',
          'status': status,
          'type': type,
          'date': DateTime.now().toIso8601String(),
        });

        try {
          final existing = await db.getWatchHistoryByTmdbId(tmdbId, type);
          if (existing.isEmpty) {
            await db.insertWatchHistoryItem(
              WatchHistoryItem(
                tmdbId: tmdbId,
                title: title,
                type: type,
                posterPath: posterPath,
                watchedAt: DateTime.now(),
                notes: status,
              ),
            );
          } else {
            for (final item in existing) {
              await db.updateWatchHistoryItem(
                item.copyWith(
                  notes: status,
                  watchedAt: DateTime.now(),
                ),
              );
            }
          }
        } catch (_) {}
      }

      // Notify all screens
      watchStatusNotifier.value++;
    } catch (_) {}
  }
}

class SetWatchStatusModal extends StatelessWidget {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String type;
  final String currentStatus;
  final String? permalink;
  final String? providerName;
  final ValueChanged<String>? onStatusSelected;

  const SetWatchStatusModal({
    super.key,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.type = 'movie',
    required this.currentStatus,
    this.permalink,
    this.providerName,
    this.onStatusSelected,
  });

  static const List<Map<String, dynamic>> statusItems = [
    {
      'status': 'Watching',
      'icon': Icons.play_circle_filled_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'status': 'Completed',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF2196F3),
    },
    {
      'status': 'On-Hold',
      'icon': Icons.pause_circle_filled_rounded,
      'color': Color(0xFFFFB300),
    },
    {
      'status': 'Dropped',
      'icon': Icons.cancel_rounded,
      'color': Color(0xFFE53935),
    },
    {
      'status': 'Plan to Watch',
      'icon': Icons.bookmark_rounded,
      'color': Color(0xFFAB47BC),
    },
    {
      'status': 'Favorites',
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFE91E63),
    },
  ];

  static Future<String?> show(
    BuildContext context, {
    required int tmdbId,
    required String title,
    String? posterPath,
    String type = 'movie',
    String? initialStatus,
    String? permalink,
    String? providerName,
  }) {
    final active = initialStatus ?? WatchStatusManager.getStatus(tmdbId);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      showDragHandle: false,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      builder: (ctx) => SetWatchStatusModal(
        tmdbId: tmdbId,
        title: title,
        posterPath: posterPath,
        type: type,
        currentStatus: active,
        permalink: permalink,
        providerName: providerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Modal Title
          const Text(
            'Set Watch Status',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Status Options List
          ...statusItems.map((item) {
            final status = item['status'] as String;
            final icon = item['icon'] as IconData;
            final color = item['color'] as Color;
            final isSelected = status == currentStatus;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                // Tapping active status unselects it (sets to 'None'), otherwise selects it
                final targetStatus = isSelected ? 'None' : status;
                await WatchStatusManager.setStatus(
                  tmdbId: tmdbId,
                  title: title,
                  status: targetStatus,
                  posterPath: posterPath,
                  type: type,
                  permalink: permalink,
                  providerName: providerName,
                );
                if (context.mounted) {
                  Navigator.pop(context, targetStatus);
                }
                onStatusSelected?.call(targetStatus);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: Color(0xFF4C68FF),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
