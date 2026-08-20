import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const CustomVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late final Player player;
  late final VideoController controller;

  // Custom Seek State
  DateTime? _lastTapTime;
  int _consecutiveTaps = 0;
  bool _isRightSide = true;
  Timer? _seekDebounceTimer;
  Timer? _feedbackTimer;
  Duration? _accumulatedTarget;
  
  String _feedbackText = "";
  bool _showFeedback = false;

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    player = Player();
    controller = VideoController(player);
    player.open(Media(widget.videoUrl));
    player.play();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _seekDebounceTimer?.cancel();
    _feedbackTimer?.cancel();
    _exitFullscreen();
    player.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final size = MediaQuery.of(context).size;
    
    // Ignore taps on top 10% and bottom 15%
    if (event.localPosition.dy < size.height * 0.10 || event.localPosition.dy > size.height * 0.85) {
      _consecutiveTaps = 0;
      return;
    }

    // Ignore taps in the middle 30% of the screen (35% to 65%)
    // This protects the center Play/Pause button from accidental double-taps!
    if (event.localPosition.dx > size.width * 0.35 && event.localPosition.dx < size.width * 0.65) {
      _consecutiveTaps = 0;
      return;
    }

    final isRight = event.localPosition.dx > size.width / 2;
    final now = DateTime.now();

    // Relaxed threshold for more comfortable tapping
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 600) {
      if (isRight == _isRightSide) {
        _consecutiveTaps++;
      } else {
        _consecutiveTaps = 2;
        _isRightSide = isRight;
      }
    } else {
      _consecutiveTaps = 1;
      _isRightSide = isRight;
    }

    _lastTapTime = now;

    if (_consecutiveTaps >= 2) {
      final skipVisual = (_consecutiveTaps - 1) * 10;
      
      setState(() {
        _feedbackText = "$skipVisual seconds";
        _showFeedback = true;
      });

      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showFeedback = false;
          });
        }
      });

      // Accumulate the target position for flawless stacking
      if (_accumulatedTarget == null) {
        _accumulatedTarget = player.state.position;
      }
      
      final offset = _isRightSide ? const Duration(seconds: 10) : const Duration(seconds: -10);
      _accumulatedTarget = _accumulatedTarget! + offset;
      
      // Clamp bounds
      if (player.state.duration.inMilliseconds > 0) {
         if (_accumulatedTarget! < Duration.zero) _accumulatedTarget = Duration.zero;
         if (_accumulatedTarget! > player.state.duration) _accumulatedTarget = player.state.duration;
      }

      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_accumulatedTarget != null) {
           player.seek(_accumulatedTarget!);
           _accumulatedTarget = null;
        }
        _consecutiveTaps = 0;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) {
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  Widget _buildIndicator(IconData icon, double value) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x88000000),
        borderRadius: BorderRadius.circular(64.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12.0),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: Colors.white, fontSize: 16.0),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = MaterialVideoControlsThemeData(
      volumeGesture: true,
      brightnessGesture: true,
      seekOnDoubleTap: false, // We handle double tap manually for consistent behavior!
      bottomButtonBarMargin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
      
      // Hide default seek bar using transparent colors instead of negative margins
      seekBarMargin: EdgeInsets.zero,
      seekBarThumbColor: Colors.transparent,
      seekBarPositionColor: Colors.transparent,
      seekBarBufferColor: Colors.transparent,
      
      topButtonBar: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      
      bottomButtonBar: [
        Expanded(
          child: SizedBox(
            height: 56, // Strict height to prevent Flutter layout overflow!
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. TIMES ROW
                SizedBox(
                  height: 14,
                  child: StreamBuilder<Duration>(
                    stream: player.stream.position,
                    initialData: player.state.position,
                    builder: (context, positionSnap) {
                      return StreamBuilder<Duration>(
                        stream: player.stream.duration,
                        initialData: player.state.duration,
                        builder: (context, durationSnap) {
                          final position = positionSnap.data ?? Duration.zero;
                          final duration = durationSnap.data ?? Duration.zero;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.0),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.0),
                                ),
                              ],
                            ),
                          );
                        }
                      );
                    }
                  ),
                ),
                
                // 2. CUSTOM SEEK BAR ROW
                SizedBox(
                  height: 14,
                  child: StreamBuilder<Duration>(
                    stream: player.stream.position,
                    initialData: player.state.position,
                    builder: (context, positionSnap) {
                      return StreamBuilder<Duration>(
                        stream: player.stream.duration,
                        initialData: player.state.duration,
                        builder: (context, durationSnap) {
                          final position = positionSnap.data ?? Duration.zero;
                          final duration = durationSnap.data ?? Duration.zero;
                          double max = duration.inMilliseconds.toDouble();
                          if (max <= 0) max = 1.0;
                          double val = position.inMilliseconds.toDouble();
                          if (val < 0) val = 0;
                          if (val > max) val = max;
                          
                          return SliderTheme(
                            data: const SliderThemeData(
                              activeTrackColor: Colors.deepOrange,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: Colors.deepOrange,
                              trackHeight: 2.0,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5.0),
                              overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0), // Disable overlay to save space
                            ),
                            child: Slider(
                              value: val,
                              max: max,
                              onChanged: (newVal) {
                                player.seek(Duration(milliseconds: newVal.toInt()));
                              },
                            ),
                          );
                        }
                      );
                    }
                  ),
                ),
                
                // 3. OPTIONS AND PLAY ROW
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Option 1 & 2
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.airplay, color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                        
                        // Center Play/Pause (Scaled native button to avoid built-in padding overflow)
                        const SizedBox(
                          height: 28,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: MaterialPlayOrPauseButton(iconSize: 48),
                          ),
                        ),
                        
                        // Option 3 & 4
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.picture_in_picture_alt_outlined, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      
      volumeIndicatorBuilder: (context, volume) {
        final icon = volume == 0.0 ? Icons.volume_off : (volume < 0.5 ? Icons.volume_down : Icons.volume_up);
        return _buildIndicator(icon, volume);
      },
      brightnessIndicatorBuilder: (context, brightness) {
        final icon = brightness < 0.3 ? Icons.brightness_low : (brightness < 0.7 ? Icons.brightness_medium : Icons.brightness_high);
        return _buildIndicator(icon, brightness);
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Listener(
          onPointerDown: _onPointerDown,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: MaterialVideoControlsTheme(
                  normal: themeData,
                  fullscreen: themeData,
                  child: Video(
                    controller: controller,
                    controls: AdaptiveVideoControls,
                  ),
                ),
              ),
              
              // Visual Feedback for Custom Seek
              if (_showFeedback)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: _isRightSide ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.35,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isRightSide 
                                ? [Colors.transparent, Colors.black54]
                                : [Colors.black54, Colors.transparent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isRightSide ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _feedbackText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
