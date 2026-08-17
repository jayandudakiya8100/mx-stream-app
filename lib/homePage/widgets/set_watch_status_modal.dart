import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Mirarr/database/watch_history_database.dart';
import 'package:Mirarr/models/watch_history_model.dart';

class WatchStatusManager {
  static const String boxName = 'sessionBox';
  static const String _statusPrefix = 'watch_status_';

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
  }) async {
    try {
      final box = Hive.box(boxName);
      if (status == 'None') {
        await box.delete('$_statusPrefix$tmdbId');
      } else {
        await box.put('$_statusPrefix$tmdbId', status);
      }

      // Sync with WatchHistoryDatabase if marked Watching or Completed
      final db = WatchHistoryDatabase();
      if (status == 'Completed' || status == 'Watching') {
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
          await db.updateWatchHistoryItem(
            existing.first.copyWith(
              notes: status,
              watchedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (_) {}
  }
}

class SetWatchStatusModal extends StatelessWidget {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String type;
  final String currentStatus;
  final ValueChanged<String>? onStatusSelected;

  const SetWatchStatusModal({
    super.key,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.type = 'movie',
    required this.currentStatus,
    this.onStatusSelected,
  });

  static const List<String> statuses = [
    'Watching',
    'Completed',
    'On-Hold',
    'Dropped',
    'Plan to Watch',
    'None',
  ];

  static Future<String?> show(
    BuildContext context, {
    required int tmdbId,
    required String title,
    String? posterPath,
    String type = 'movie',
    String? initialStatus,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Modal Title
          Text(
            'Set watch status',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          // Options List
          ...statuses.map((status) {
            final isSelected = currentStatus.toLowerCase() == status.toLowerCase();
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await WatchStatusManager.setStatus(
                  tmdbId: tmdbId,
                  title: title,
                  status: status,
                  posterPath: posterPath,
                  type: type,
                );
                if (context.mounted) {
                  Navigator.pop(context, status);
                }
                onStatusSelected?.call(status);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
                child: Row(
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                    ] else
                      const SizedBox(width: 32),
                    Text(
                      status,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.85),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 16,
                      ),
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
