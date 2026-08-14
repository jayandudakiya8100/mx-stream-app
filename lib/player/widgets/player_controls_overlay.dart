import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:Mirarr/player/models/player_models.dart';
import 'package:Mirarr/player/widgets/track_selection_sheets.dart';

class PlayerControlsOverlay extends StatefulWidget {
  final Player player;
  final String title;
  final String? quality;
  final bool isVisible;
  final bool isLocked;
  final PlayerAspectRatio currentAspectRatio;
  final Color accentColor;
  final VoidCallback onToggleLock;
  final ValueChanged<PlayerAspectRatio> onAspectRatioChanged;
  final VoidCallback onUserInteraction;

  const PlayerControlsOverlay({
    super.key,
    required this.player,
    required this.title,
    this.quality,
    required this.isVisible,
    required this.isLocked,
    required this.currentAspectRatio,
    required this.accentColor,
    required this.onToggleLock,
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
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
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
              icon: const Icon(Icons.lock, size: 26),
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
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.85),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),

          // Title & Quality
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.quality != null && widget.quality!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: widget.accentColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        widget.quality!,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Audio Selector
          IconButton(
            icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
            tooltip: 'Audio Tracks',
            onPressed: () {
              widget.onUserInteraction();
              TrackSelectionSheets.showAudioTracksModal(
                context: context,
                player: widget.player,
                accentColor: widget.accentColor,
              );
            },
          ),

          // Subtitles Selector
          IconButton(
            icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
            tooltip: 'Subtitles',
            onPressed: () {
              widget.onUserInteraction();
              TrackSelectionSheets.showSubtitleTracksModal(
                context: context,
                player: widget.player,
                accentColor: widget.accentColor,
              );
            },
          ),

          // Aspect Ratio Switcher
          IconButton(
            icon: Icon(widget.currentAspectRatio.icon, color: Colors.white),
            tooltip: widget.currentAspectRatio.label,
            onPressed: () {
              widget.onUserInteraction();
              TrackSelectionSheets.showAspectRatioModal(
                context: context,
                currentRatio: widget.currentAspectRatio,
                onRatioSelected: widget.onAspectRatioChanged,
                accentColor: widget.accentColor,
              );
            },
          ),

          // Playback Speed
          StreamBuilder<double>(
            stream: widget.player.stream.rate,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? 1.0;
              return TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(40, 36),
                ),
                onPressed: () {
                  widget.onUserInteraction();
                  TrackSelectionSheets.showPlaybackSpeedModal(
                    context: context,
                    currentSpeed: speed,
                    onSpeedSelected: (newSpeed) => widget.player.setRate(newSpeed),
                    accentColor: widget.accentColor,
                  );
                },
                child: Text(
                  '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2)}x',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),

          // Lock Button
          IconButton(
            icon: const Icon(Icons.lock_open_outlined, color: Colors.white),
            tooltip: 'Lock Screen',
            onPressed: widget.onToggleLock,
          ),
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
                IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  tooltip: 'Rewind 10s',
                  onPressed: () {
                    widget.onUserInteraction();
                    final pos = widget.player.state.position;
                    widget.player.seek(pos - const Duration(seconds: 10));
                  },
                ),
                const SizedBox(width: 36),

                // Center Play / Pause / Spinner
                if (isBuffering)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: widget.accentColor,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: IconButton(
                      iconSize: 52,
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      tooltip: isPlaying ? 'Pause' : 'Play',
                      onPressed: () {
                        widget.onUserInteraction();
                        widget.player.playOrPause();
                      },
                    ),
                  ),
                const SizedBox(width: 36),

                // Skip Forward 10s
                IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  tooltip: 'Forward 10s',
                  onPressed: () {
                    widget.onUserInteraction();
                    final pos = widget.player.state.position;
                    widget.player.seek(pos + const Duration(seconds: 10));
                  },
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time Slider
                  Row(
                    children: [
                      Text(
                        _formatDuration(_isDraggingSlider
                            ? Duration(milliseconds: _sliderDragValue.round())
                            : position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: widget.accentColor,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: widget.accentColor,
                            overlayColor: widget.accentColor.withValues(alpha: 0.2),
                            disabledThumbColor: Colors.white24,
                            disabledActiveTrackColor: Colors.white12,
                          ),
                          child: Slider(
                            min: 0.0,
                            max: maxDurationMs > 0 ? maxDurationMs : 1.0,
                            value: maxDurationMs > 0 ? sliderValue.clamp(0.0, maxDurationMs) : 0.0,
                            onChangeStart: maxDurationMs > 0
                                ? (val) {
                                    widget.onUserInteraction();
                                    setState(() {
                                      _isDraggingSlider = true;
                                      _sliderDragValue = val;
                                    });
                                  }
                                : null,
                            onChanged: maxDurationMs > 0
                                ? (val) {
                                    widget.onUserInteraction();
                                    setState(() {
                                      _sliderDragValue = val;
                                    });
                                  }
                                : null,
                            onChangeEnd: maxDurationMs > 0
                                ? (val) {
                                    widget.onUserInteraction();
                                    setState(() {
                                      _isDraggingSlider = false;
                                    });
                                    widget.player.seek(Duration(milliseconds: val.round()));
                                  }
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
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
}
