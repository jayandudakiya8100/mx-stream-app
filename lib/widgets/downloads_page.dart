import 'package:flutter/material.dart';
import 'package:Mirarr/player/temp_player_sheet.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _refererController = TextEditingController();

  void _openNetworkStreamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        title: const Text(
          'Network stream',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'https://example.com/example.mp4',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _refererController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Referer (optional)',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () {
              final url = _urlController.text.trim();
              final referer = _refererController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                TempPlayerSheet.show(
                  context: context,
                  streamUrl: url,
                  title: 'Network Stream',
                  headers: referer.isNotEmpty ? {'Referer': referer} : null,
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFECEEF4),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Play',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1F1F24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _openDownloadQueueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      elevation: 0,
      backgroundColor: Colors.black,
      barrierColor: Colors.black54,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.88,
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back arrow
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Download queue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Queue Empty state
              const Expanded(
                child: Center(
                  child: Text(
                    'There are currently no queued downloads.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _refererController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = TvFocusModeManager.isTvDevice
        ? 16.0
        : (bottomPadding > 0 ? bottomPadding : 88.0);

    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        top: true,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title
                  const Text(
                    'Internal Storage',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Storage Multi-segment Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      color: const Color(0xFF333644),
                      child: Row(
                        children: [
                          // Used
                          Expanded(
                            flex: 76,
                            child: Container(color: Colors.white),
                          ),
                          // App
                          Expanded(
                            flex: 4,
                            child: Container(color: const Color(0xFF4C68FF)),
                          ),
                          // Free
                          Expanded(
                            flex: 20,
                            child: Container(color: const Color(0xFF333644)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Storage Details Legend
                  Row(
                    children: [
                      _buildLegendDot(Colors.white, 'Used • 103 GB'),
                      const SizedBox(width: 14),
                      _buildLegendDot(const Color(0xFF4C68FF), 'App • 0 B'),
                      const SizedBox(width: 14),
                      _buildLegendDot(Colors.white38, 'Free • 11 GB'),
                    ],
                  ),

                  // Center Empty State
                  const Expanded(
                    child: Center(
                      child: Text(
                        'There are currently no downloads.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Network Stream Pill Button (Above Download queue on right)
            Positioned(
              right: 20,
              bottom: bottomInset + 54,
              child: TvFocusWrapper(
                onTap: _openNetworkStreamDialog,
                borderRadius: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Network stream',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Bottom "Download queue" Handle (Centered above navigation bar)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 4,
              child: Center(
                child: GestureDetector(
                  onTap: _openDownloadQueueSheet,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        Text(
                          'Download queue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
