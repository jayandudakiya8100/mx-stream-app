import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:Mirarr/functions/fetchers/providers/vega_movies_provider.dart';
import 'package:Mirarr/player/models/player_models.dart';

class TrackSelectionSheets {
  /// Audio Tracks Selection Modal matching docs/UI/audio trek modal.jpeg
  static void showAudioTracksModal({
    required BuildContext context,
    required Player player,
    required Color accentColor,
  }) {
    final audioTracks = player.state.tracks.audio;
    final currentTrack = player.state.track.audio;
    AudioTrack? selectedTrack = currentTrack;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Audio tracks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Track List
                  Expanded(
                    child: audioTracks.isEmpty
                        ? const Center(
                            child: Text(
                              'Default audio track active',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            itemCount: audioTracks.length,
                            itemBuilder: (context, index) {
                              final track = audioTracks[index];
                              final isSelected = selectedTrack?.id == track.id;
                              final trackName = _formatAudioTrackName(track, index);

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedTrack = track;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          trackName,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action Buttons (Apply / Cancel)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedTrack != null) {
                            player.setAudioTrack(selectedTrack!);
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Sources & Subtitles 2-Column Modal matching docs/UI/sources list.jpeg
  static void showSourcesAndSubtitlesModal({
    required BuildContext context,
    required Player player,
    required List<StreamLink> availableStreams,
    required String currentStreamUrl,
    required ValueChanged<StreamLink> onSelectStream,
    required Color accentColor,
  }) {
    final subtitleTracks = player.state.tracks.subtitle;
    final currentSub = player.state.track.subtitle;

    StreamLink? selectedStream = availableStreams.firstWhere(
      (s) => s.streamUrl == currentStreamUrl,
      orElse: () => availableStreams.isNotEmpty
          ? availableStreams.first
          : StreamLink(name: 'Default', streamUrl: currentStreamUrl, quality: '1080p'),
    );
    SubtitleTrack? selectedSub = currentSub;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D10),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: SOURCES
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Sources',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Profile 1',
                                    style: TextStyle(color: Colors.white60, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.settings_outlined, color: Colors.white60, size: 16),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: availableStreams.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Current active source stream',
                                          style: TextStyle(color: Colors.white54, fontSize: 13),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: availableStreams.length,
                                        itemBuilder: (context, index) {
                                          final s = availableStreams[index];
                                          final isSelected = selectedStream?.streamUrl == s.streamUrl;

                                          final sourceTitle = s.name.isNotEmpty
                                              ? s.name
                                              : 'Server ${index + 1} (${s.quality})';

                                          return InkWell(
                                            onTap: () {
                                              setModalState(() {
                                                selectedStream = s;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    child: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                            color: Colors.white,
                                                            size: 18,
                                                          )
                                                        : const SizedBox.shrink(),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          sourceTitle,
                                                          style: TextStyle(
                                                            color: isSelected ? Colors.white : Colors.white70,
                                                            fontSize: 13,
                                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                        if (s.quality.isNotEmpty)
                                                          Text(
                                                            s.quality,
                                                            style: const TextStyle(
                                                              color: Colors.white54,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),
                        Container(width: 1, color: Colors.white12),
                        const SizedBox(width: 24),

                        // Right Column: SUBTITLES
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Subtitles',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    'Auto',
                                    style: TextStyle(color: Colors.white60, fontSize: 13),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.settings_outlined, color: Colors.white60, size: 16),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: ListView(
                                  children: [
                                    // No Subtitles option
                                    InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          selectedSub = SubtitleTrack.no();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              child: selectedSub?.id == 'no' || selectedSub == null
                                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                                  : const SizedBox.shrink(),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'No Subtitles',
                                              style: TextStyle(color: Colors.white70, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Dynamic Subtitle Tracks
                                    ...subtitleTracks.map((sub) {
                                      final isSelected = selectedSub?.id == sub.id;
                                      final name = _formatSubtitleTrackName(sub);

                                      return InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            selectedSub = sub;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                child: isSelected
                                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                                    : const SizedBox.shrink(),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.white70,
                                                    fontSize: 14,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),

                                    const SizedBox(height: 12),
                                    // Extra Subtitle Loaders matching screenshot
                                    _buildSubtitleActionRow(Icons.add, 'Load from file', () {}),
                                    _buildSubtitleActionRow(Icons.add, 'Load from Internet', () {}),
                                    _buildSubtitleActionRow(Icons.add, 'Load first available', () {}),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Bar (Apply / Cancel)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedSub != null) {
                            player.setSubtitleTrack(selectedSub!);
                          }
                          if (selectedStream != null) {
                            onSelectStream(selectedStream!);
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSubtitleActionRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resize / Aspect Ratio Modal
  static void showAspectRatioModal({
    required BuildContext context,
    required PlayerAspectRatio currentRatio,
    required ValueChanged<PlayerAspectRatio> onRatioSelected,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aspect Ratio / Screen Fit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ...PlayerAspectRatio.values.map((ratio) {
                  final isSelected = ratio == currentRatio;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isSelected ? accentColor : Colors.white38,
                    ),
                    title: Text(
                      ratio.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      onRatioSelected(ratio);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatAudioTrackName(AudioTrack track, int index) {
    final title = track.title?.trim() ?? '';
    final lang = track.language?.trim().toUpperCase() ?? '';
    final channels = track.channels != null ? '${track.channels}' : '5.1';
    final codec = track.codec?.toUpperCase() ?? 'E-AC3';

    if (title.isNotEmpty) return title;
    if (lang.isNotEmpty) return '$lang • $channels • $codec';
    return 'Track ${index + 1} • $channels • $codec';
  }

  static String _formatSubtitleTrackName(SubtitleTrack track) {
    final title = track.title?.trim() ?? '';
    final lang = track.language?.trim() ?? '';
    if (title.isNotEmpty) return title;
    if (lang.isNotEmpty) return lang;
    return 'Track ${track.id}';
  }
}
