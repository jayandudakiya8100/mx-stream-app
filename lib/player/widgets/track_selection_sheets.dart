import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:Mirarr/player/models/player_models.dart';

class TrackSelectionSheets {
  static void showAudioTracksModal({
    required BuildContext context,
    required Player player,
    required Color accentColor,
  }) {
    final audioTracks = player.state.tracks.audio;
    final currentTrack = player.state.track.audio;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.audiotrack, color: accentColor, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Audio Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                if (audioTracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Default audio track active (no additional streams found)',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: audioTracks.length,
                      itemBuilder: (context, index) {
                        final track = audioTracks[index];
                        final isSelected = track.id == currentTrack.id;
                        final title = _formatAudioTrackName(track, index);

                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? accentColor : Colors.white38,
                            size: 20,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? accentColor : Colors.white,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: track.channels != null
                              ? Text(
                                  'Channels: ${track.channels} ${track.bitrate != null ? '• ${(track.bitrate! / 1000).round()} kbps' : ''}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                )
                              : null,
                          onTap: () {
                            player.setAudioTrack(track);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showSubtitleTracksModal({
    required BuildContext context,
    required Player player,
    required Color accentColor,
  }) {
    final subtitleTracks = player.state.tracks.subtitle;
    final currentTrack = player.state.track.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.subtitles, color: accentColor, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: Icon(
                    currentTrack.id == 'no' || currentTrack.id == 'auto' && subtitleTracks.isEmpty
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: currentTrack.id == 'no' ? accentColor : Colors.white38,
                    size: 20,
                  ),
                  title: Text(
                    'Off / Disabled',
                    style: TextStyle(
                      color: currentTrack.id == 'no' ? accentColor : Colors.white,
                      fontSize: 14,
                      fontWeight: currentTrack.id == 'no' ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    player.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.pop(ctx);
                  },
                ),
                if (subtitleTracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'No embedded subtitle tracks detected in this stream.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: subtitleTracks.length,
                      itemBuilder: (context, index) {
                        final track = subtitleTracks[index];
                        final isSelected = track.id == currentTrack.id;
                        final title = _formatSubtitleTrackName(track, index);

                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? accentColor : Colors.white38,
                            size: 20,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? accentColor : Colors.white,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            player.setSubtitleTrack(track);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showAspectRatioModal({
    required BuildContext context,
    required PlayerAspectRatio currentRatio,
    required ValueChanged<PlayerAspectRatio> onRatioSelected,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.aspect_ratio, color: accentColor, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Aspect Ratio / Scaling',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                ...PlayerAspectRatio.values.map((ratio) {
                  final isSelected = ratio == currentRatio;
                  return ListTile(
                    leading: Icon(
                      ratio.icon,
                      color: isSelected ? accentColor : Colors.white60,
                      size: 22,
                    ),
                    title: Text(
                      ratio.label,
                      style: TextStyle(
                        color: isSelected ? accentColor : Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: accentColor, size: 20)
                        : null,
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

  static void showPlaybackSpeedModal({
    required BuildContext context,
    required double currentSpeed,
    required ValueChanged<double> onSpeedSelected,
    required Color accentColor,
  }) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: accentColor, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Playback Speed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: speeds.map((speed) {
                    final isSelected = (speed - currentSpeed).abs() < 0.05;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        onSpeedSelected(speed);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? accentColor : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: isSelected ? accentColor : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatAudioTrackName(AudioTrack track, int index) {
    final title = track.title;
    final lang = track.language;
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return 'Audio Track ${index + 1} ($lang)';
    return 'Audio Track ${index + 1}';
  }

  static String _formatSubtitleTrackName(SubtitleTrack track, int index) {
    final title = track.title;
    final lang = track.language;
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return 'Subtitle ${index + 1} ($lang)';
    return 'Subtitle ${index + 1}';
  }
}
