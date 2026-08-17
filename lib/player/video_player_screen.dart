import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:Mirarr/functions/fetchers/providers/vega_movies_provider.dart';
import 'package:Mirarr/player/models/player_models.dart';
import 'package:Mirarr/player/widgets/player_controls_overlay.dart';
import 'package:Mirarr/player/widgets/player_gestures_layer.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String? mediaHeader;
  final String? quality;
  final Color? accentColor;
  final Map<String, String>? headers;
  final List<StreamLink> availableStreams;

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.mediaHeader,
    this.quality,
    this.accentColor,
    this.headers,
    this.availableStreams = const [],
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  // Stream state
  late String _activeStreamUrl;
  String? _activeMediaHeader;

  // Controls UI state
  bool _areControlsVisible = true;
  bool _isLocked = false;
  PlayerAspectRatio _aspectRatio = PlayerAspectRatio.fit;
  Timer? _hideControlsTimer;
  String? _errorMessage;
  bool _isResolvingStream = true;
  DeviceOrientation _currentOrientation = DeviceOrientation.landscapeLeft;

  @override
  void initState() {
    super.initState();
    _activeStreamUrl = widget.streamUrl;
    _activeMediaHeader = widget.mediaHeader;

    // 1. Enter Immersive Horizontal (Landscape) Mode by default
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();

    // 2. Initialize MediaKit Player
    _player = Player(
      configuration: const PlayerConfiguration(
        pitch: true,
      ),
    );

    _controller = VideoController(_player);

    // 3. Listen to errors
    _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isResolvingStream = false;
        });
      }
    });

    // 4. Resolve and Open Stream Media
    _startPlayback(_activeStreamUrl);

    // 5. Start auto-hide timer
    _resetHideControlsTimer();
  }

  void _toggleRotation() {
    setState(() {
      _currentOrientation = (_currentOrientation == DeviceOrientation.landscapeLeft)
          ? DeviceOrientation.landscapeRight
          : DeviceOrientation.landscapeLeft;
    });
    SystemChrome.setPreferredOrientations([_currentOrientation]);
  }

  Future<void> _startPlayback(String streamUrlToPlay, {String? newHeader}) async {
    setState(() {
      _isResolvingStream = true;
      _errorMessage = null;
      _activeStreamUrl = streamUrlToPlay;
      if (newHeader != null) {
        _activeMediaHeader = newHeader;
      }
    });

    try {
      await _player.stop();

      Map<String, String>? headersToPass = widget.headers;
      final isPresigned = streamUrlToPlay.contains('X-Amz-') ||
          streamUrlToPlay.contains('r2.cloudflarestorage.com') ||
          streamUrlToPlay.contains('googleusercontent.com');

      if (!isPresigned && headersToPass == null) {
        headersToPass = {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
      }

      await _player.open(
        Media(
          streamUrlToPlay,
          httpHeaders: headersToPass,
        ),
        play: true,
      );

      if (mounted) {
        setState(() {
          _isResolvingStream = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolvingStream = false;
          _errorMessage = 'Could not initialize stream: $e';
        });
      }
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_isLocked && _areControlsVisible) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _areControlsVisible) {
          setState(() {
            _areControlsVisible = false;
          });
        }
      });
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _resetHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _areControlsVisible = true;
    });
    _resetHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _player.dispose();
    WakelockPlus.disable();

    // Restore orientations and system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = widget.accentColor ?? const Color(0xFF4C68FF);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Native Video Surface
          _buildVideoView(),

          // 2. Gesture Handling Layer (Brightness, Volume, Seek, Double Tap)
          if (!_isLocked)
            PlayerGesturesLayer(
              player: _player,
              isLocked: _isLocked,
              accentColor: effectiveAccent,
              onTap: _toggleControlsVisibility,
              onSeekRelative: (delta) {
                final pos = _player.state.position;
                _player.seek(pos + delta);
              },
            ),

          // 3. Error Message Overlay
          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _startPlayback(_activeStreamUrl),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Controls Overlay (Top Bar, Center Play, Progress, Bottom 5 Action Buttons)
          PlayerControlsOverlay(
            player: _player,
            title: widget.title,
            mediaHeader: _activeMediaHeader ?? widget.mediaHeader,
            quality: widget.quality,
            isVisible: _areControlsVisible,
            isLocked: _isLocked,
            currentAspectRatio: _aspectRatio,
            accentColor: effectiveAccent,
            availableStreams: widget.availableStreams,
            currentStreamUrl: _activeStreamUrl,
            onSelectStream: (stream) {
              final header = stream.name.isNotEmpty
                  ? stream.name
                  : '${widget.title} [${stream.quality}]';
              _startPlayback(stream.streamUrl, newHeader: header);
            },
            onToggleLock: _toggleLock,
            onRotate: _toggleRotation,
            onAspectRatioChanged: (ratio) {
              setState(() => _aspectRatio = ratio);
            },
            onUserInteraction: _resetHideControlsTimer,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView() {
    switch (_aspectRatio) {
      case PlayerAspectRatio.fit:
        return SizedBox.expand(
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          ),
        );
      case PlayerAspectRatio.stretch:
        return SizedBox.expand(
          child: Video(
            controller: _controller,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case PlayerAspectRatio.zoom:
        return SizedBox.expand(
          child: Video(
            controller: _controller,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),
        );
      case PlayerAspectRatio.sixteenNine:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(
              controller: _controller,
              fit: BoxFit.cover,
              controls: NoVideoControls,
            ),
          ),
        );
      case PlayerAspectRatio.fourThree:
        return Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Video(
              controller: _controller,
              fit: BoxFit.cover,
              controls: NoVideoControls,
            ),
          ),
        );
    }
  }
}
