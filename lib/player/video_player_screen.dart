import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:Mirarr/player/models/player_models.dart';
import 'package:Mirarr/player/widgets/player_controls_overlay.dart';
import 'package:Mirarr/player/widgets/player_gestures_layer.dart';

import 'package:http/http.dart' as http;

class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String? quality;
  final Color? accentColor;
  final Map<String, String>? headers;

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.quality,
    this.accentColor,
    this.headers,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  // Controls UI state
  bool _areControlsVisible = true;
  bool _isLocked = false;
  PlayerAspectRatio _aspectRatio = PlayerAspectRatio.fit;
  Timer? _hideControlsTimer;
  String? _errorMessage;
  bool _isResolvingStream = true;

  @override
  void initState() {
    super.initState();

    // 1. Enter Immersive Landscape Mode & Keep Screen Awake
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    WakelockPlus.enable();

    // 2. Initialize MediaKit Player with deep buffer tuning for 4K
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024, // 64MB buffer for 4K streams
        pitch: true,
      ),
    );

    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // 3. Listen to errors
    _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });
      }
    });

    // 4. Resolve and Open Stream Media
    _startPlayback();

    // 5. Start auto-hide timer
    _resetHideControlsTimer();
  }

  Future<void> _startPlayback() async {
    setState(() {
      _isResolvingStream = true;
      _errorMessage = null;
    });

    try {
      final directUrl = await _resolveFinalUrl(widget.streamUrl);
      if (!mounted) return;

      setState(() {
        _isResolvingStream = false;
      });

      // Avoid passing custom User-Agent to signed AWS/Cloudflare R2 URLs
      // because extra headers cause S3 signature verification to fail.
      Map<String, String>? headersToPass = widget.headers;
      if (headersToPass == null) {
        final isPresigned = directUrl.contains('X-Amz-') ||
            directUrl.contains('r2.cloudflarestorage.com') ||
            directUrl.contains('r2.dev');
        if (!isPresigned) {
          headersToPass = {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          };
        }
      }

      await _player.open(
        Media(
          directUrl,
          httpHeaders: headersToPass,
        ),
        play: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolvingStream = false;
          _errorMessage = 'Could not initialize stream: $e';
        });
      }
    }
  }

  Future<String> _resolveFinalUrl(String startUrl, {int maxRedirects = 7}) async {
    var currentUrl = startUrl;
    for (int i = 0; i < maxRedirects; i++) {
      try {
        final client = http.Client();
        final request = http.Request('HEAD', Uri.parse(currentUrl))
          ..followRedirects = false
          ..headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

        final streamed = await client.send(request).timeout(const Duration(seconds: 4));
        client.close();

        if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
          final location = streamed.headers['location'];
          if (location != null && location.isNotEmpty) {
            currentUrl = location.startsWith('http')
                ? location
                : Uri.parse(currentUrl).resolve(location).toString();
            continue;
          }
        }
        break;
      } catch (_) {
        break;
      }
    }
    return currentUrl;
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_areControlsVisible || _isLocked) return;

    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) {
        setState(() {
          _areControlsVisible = false;
        });
      }
    });
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

    // Restore System UI and Orientations
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();

    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Main Video Layer with Aspect Ratio
          Center(
            child: _buildVideoWithAspectRatio(),
          ),

          // 2. Gestures Layer (Double Tap 10s Seek, Tap Toggle)
          PlayerGesturesLayer(
            player: _player,
            isLocked: _isLocked,
            accentColor: accent,
            onTap: _toggleControlsVisibility,
            onSeekRelative: (offset) {
              _resetHideControlsTimer();
              final current = _player.state.position;
              _player.seek(current + offset);
            },
          ),

          // 3. Controls Overlay (Top bar, Center Play/Pause, Bottom Seekbar, Lock)
          PlayerControlsOverlay(
            player: _player,
            title: widget.title,
            quality: widget.quality,
            isVisible: _areControlsVisible,
            isLocked: _isLocked,
            currentAspectRatio: _aspectRatio,
            accentColor: accent,
            onToggleLock: _toggleLock,
            onAspectRatioChanged: (ratio) {
              setState(() {
                _aspectRatio = ratio;
              });
            },
            onUserInteraction: _resetHideControlsTimer,
          ),

          // 4. Loading / Resolving Overlay
          if (_isResolvingStream)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: accent),
                    const SizedBox(height: 16),
                    const Text(
                      'Connecting to video stream...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Error State Overlay
          if (_errorMessage != null)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      'Playback Error',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                            _player.open(
                              Media(widget.streamUrl, httpHeaders: widget.headers),
                              play: true,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Exit Player'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoWithAspectRatio() {
    switch (_aspectRatio) {
      case PlayerAspectRatio.fit:
        return Video(
          controller: _controller,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        );
      case PlayerAspectRatio.zoom:
        return Video(
          controller: _controller,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        );
      case PlayerAspectRatio.stretch:
        return Video(
          controller: _controller,
          fit: BoxFit.fill,
          controls: NoVideoControls,
        );
      case PlayerAspectRatio.sixteenNine:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(
            controller: _controller,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case PlayerAspectRatio.fourThree:
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: Video(
            controller: _controller,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
    }
  }
}
