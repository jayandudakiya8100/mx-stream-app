import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class PlayerGesturesLayer extends StatefulWidget {
  final Player player;
  final bool isLocked;
  final VoidCallback onTap;
  final ValueChanged<Duration> onSeekRelative;
  final Color accentColor;

  const PlayerGesturesLayer({
    super.key,
    required this.player,
    required this.isLocked,
    required this.onTap,
    required this.onSeekRelative,
    required this.accentColor,
  });

  @override
  State<PlayerGesturesLayer> createState() => _PlayerGesturesLayerState();
}

class _PlayerGesturesLayerState extends State<PlayerGesturesLayer>
    with TickerProviderStateMixin {
  // Double tap state
  bool _showLeftSeekRipple = false;
  bool _showRightSeekRipple = false;
  int _leftSeekSeconds = 0;
  int _rightSeekSeconds = 0;
  Timer? _leftSeekTimer;
  Timer? _rightSeekTimer;


  void _onDoubleTapLeft() {
    if (widget.isLocked) return;

    _leftSeekTimer?.cancel();
    setState(() {
      _showLeftSeekRipple = true;
      _leftSeekSeconds += 10;
    });

    widget.onSeekRelative(const Duration(seconds: -10));

    _leftSeekTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _showLeftSeekRipple = false;
          _leftSeekSeconds = 0;
        });
      }
    });
  }

  void _onDoubleTapRight() {
    if (widget.isLocked) return;

    _rightSeekTimer?.cancel();
    setState(() {
      _showRightSeekRipple = true;
      _rightSeekSeconds += 10;
    });

    widget.onSeekRelative(const Duration(seconds: 10));

    _rightSeekTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _showRightSeekRipple = false;
          _rightSeekSeconds = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _leftSeekTimer?.cancel();
    _rightSeekTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: const SizedBox.expand(),
      );
    }

    return Stack(
      children: [
        // Gesture Detector regions
        Row(
          children: [
            // Left Half (Rewind double tap + Brightness drag)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onDoubleTap: _onDoubleTapLeft,
                child: const SizedBox.expand(),
              ),
            ),
            // Center (Single tap overlay toggle)
            SizedBox(
              width: 80,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: const SizedBox.expand(),
              ),
            ),
            // Right Half (Forward double tap + Volume drag)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onDoubleTap: _onDoubleTapRight,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // Left Seek Indicator (-10s, -20s, ...)
        if (_showLeftSeekRipple)
          Positioned(
            left: 40,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showLeftSeekRipple ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_10, color: widget.accentColor, size: 36),
                      const SizedBox(height: 4),
                      Text(
                        '-${_leftSeekSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Right Seek Indicator (+10s, +20s, ...)
        if (_showRightSeekRipple)
          Positioned(
            right: 40,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showRightSeekRipple ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_10, color: widget.accentColor, size: 36),
                      const SizedBox(height: 4),
                      Text(
                        '+${_rightSeekSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
