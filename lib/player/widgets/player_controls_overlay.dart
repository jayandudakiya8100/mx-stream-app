import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:Mirarr/functions/fetchers/providers/vega_movies_provider.dart';
import 'package:Mirarr/player/models/player_models.dart';
import 'package:Mirarr/player/widgets/track_selection_sheets.dart';

class PlayerControlsOverlay extends StatefulWidget {
  final Player player;
  final String title;
  final String? mediaHeader;
  final String? quality;
  final bool isVisible;
  final bool isLocked;
  final PlayerAspectRatio currentAspectRatio;
  final Color accentColor;
  final List<StreamLink> availableStreams;
  final String currentStreamUrl;
  final ValueChanged<StreamLink> onSelectStream;
  final VoidCallback onToggleLock;
  final VoidCallback onRotate;
  final ValueChanged<PlayerAspectRatio> onAspectRatioChanged;
  final VoidCallback onUserInteraction;

  const PlayerControlsOverlay({
    super.key,
    required this.player,
    required this.title,
    this.mediaHeader,
    this.quality,
    required this.isVisible,
    required this.isLocked,
    required this.currentAspectRatio,
    required this.accentColor,
    this.availableStreams = const [],
    required this.currentStreamUrl,
    required this.onSelectStream,
    required this.onToggleLock,
    required this.onRotate,
    required this.onAspectRatioChanged,
    required this.onUserInteraction,
  });

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
  bool _isDraggingSlider = false;
  double _sliderDragValue = 0.0;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.75),
                foregroundColor: widget.accentColor,
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.lock_rounded, size: 26),
              tooltip: 'Unlock Screen',
              onPressed: widget.onToggleLock,
            ),
          ),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.25, 0.75, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopBar(context),
                _buildCenterControls(context),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final headerText = widget.mediaHeader ?? widget.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),

          // Title & Details matching video player screen.jpeg
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  headerText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance back button
        ],
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.player.stream.buffering,
      builder: (context, bufferingSnapshot) {
        final isBuffering = bufferingSnapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: widget.player.stream.playing,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Skip Backward 10s
                GestureDetector(
                  onTap: () async {
                    widget.onUserInteraction();
                    final pos = widget.player.state.position;
                    await widget.player.seek(pos - const Duration(seconds: 10));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.transparent,
                    child: const Icon(
                      Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(width: 60),

                // Center Play / Pause / Spinner
                if (isBuffering)
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: widget.accentColor,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      widget.onUserInteraction();
                      widget.player.playOrPause();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.transparent,
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 58,
                      ),
                    ),
                  ),
                const SizedBox(width: 60),

                // Skip Forward 10s
                GestureDetector(
                  onTap: () async {
                    widget.onUserInteraction();
                    final pos = widget.player.state.position;
                    await widget.player.seek(pos + const Duration(seconds: 10));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.transparent,
                    child: const Icon(
                      Icons.forward_10_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final maxDurationMs = duration.inMilliseconds.toDouble();
            final currentPositionMs = position.inMilliseconds.toDouble();

            final sliderValue = _isDraggingSlider
                ? _sliderDragValue
                : (maxDurationMs > 0 ? currentPositionMs.clamp(0.0, maxDurationMs) : 0.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time Slider Row
                  Row(
                    children: [
                      Text(
                        _formatDuration(_isDraggingSlider
                            ? Duration(milliseconds: _sliderDragValue.round())
                            : position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: const Color(0xFF4C68FF),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFF4C68FF),
                            overlayColor: const Color(0xFF4C68FF).withValues(alpha: 0.25),
                          ),
                          child: Slider(
                            min: 0.0,
                            max: maxDurationMs > 0 ? maxDurationMs : 1.0,
                            value: maxDurationMs > 0 ? sliderValue.clamp(0.0, maxDurationMs) : 0.0,
                            onChangeStart: (value) {
                              widget.onUserInteraction();
                              setState(() {
                                _isDraggingSlider = true;
                                _sliderDragValue = value;
                              });
                            },
                            onChanged: (value) {
                              widget.onUserInteraction();
                              setState(() {
                                _sliderDragValue = value;
                              });
                            },
                            onChangeEnd: (value) async {
                              widget.onUserInteraction();
                              setState(() {
                                _isDraggingSlider = false;
                              });
                              await widget.player.seek(Duration(milliseconds: value.round()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 5 Bottom Action Buttons matching video player screen.jpeg
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Lock
                      _buildBottomActionButton(
                        icon: Icons.lock_outline_rounded,
                        label: 'Lock',
                        onTap: () {
                          widget.onUserInteraction();
                          widget.onToggleLock();
                        },
                      ),

                      // 2. Rotate
                      _buildBottomActionButton(
                        icon: Icons.screen_rotation_rounded,
                        label: 'Rotate',
                        onTap: () {
                          widget.onUserInteraction();
                          widget.onRotate();
                        },
                      ),

                      // 3. Resize
                      _buildBottomActionButton(
                        icon: Icons.aspect_ratio_rounded,
                        label: 'Resize',
                        onTap: () {
                          widget.onUserInteraction();
                          TrackSelectionSheets.showAspectRatioModal(
                            context: context,
                            currentRatio: widget.currentAspectRatio,
                            onRatioSelected: widget.onAspectRatioChanged,
                            accentColor: widget.accentColor,
                          );
                        },
                      ),

                      // 4. Source
                      _buildBottomActionButton(
                        icon: Icons.view_headline_rounded,
                        label: 'Source',
                        onTap: () {
                          widget.onUserInteraction();
                          TrackSelectionSheets.showSourcesAndSubtitlesModal(
                            context: context,
                            player: widget.player,
                            availableStreams: widget.availableStreams,
                            currentStreamUrl: widget.currentStreamUrl,
                            onSelectStream: widget.onSelectStream,
                            accentColor: widget.accentColor,
                          );
                        },
                      ),

                      // 5. Tracks
                      _buildBottomActionButton(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Tracks',
                        onTap: () {
                          widget.onUserInteraction();
                          TrackSelectionSheets.showAudioTracksModal(
                            context: context,
                            player: widget.player,
                            accentColor: widget.accentColor,
                          );
                        },
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

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
