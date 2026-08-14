import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive Loading Spinner
/// Features dynamic morphing dual-arcs, gradient sweeps, and breathing scale pulses.
class M3ExpressiveSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? secondaryColor;

  const M3ExpressiveSpinner({
    super.key,
    this.size = 48.0,
    this.color,
    this.secondaryColor,
  });

  @override
  State<M3ExpressiveSpinner> createState() => _M3ExpressiveSpinnerState();
}

class _M3ExpressiveSpinnerState extends State<M3ExpressiveSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;
    final secondaryColor = widget.secondaryColor ?? theme.colorScheme.tertiary;
    final trackColor = theme.colorScheme.surfaceContainerHigh;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        child: Container(
          width: widget.size + 16,
          height: widget.size + 16,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: trackColor.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _M3ExpressiveSpinnerPainter(
                progressListenable: _controller,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                trackColor: primaryColor.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        builder: (context, child) {
          final value = _controller.value;
          final scale = 0.92 + (0.08 * math.sin(value * 2 * math.pi));
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
      ),
    );
  }
}

class _M3ExpressiveSpinnerPainter extends CustomPainter {
  final Animation<double> progressListenable;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  // Cached paints keyed on radius — avoid SweepGradient.createShader every frame.
  double? _cachedRadius;
  Paint? _cachedPrimaryPaint;
  final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  final Paint _dotPaint = Paint()..style = PaintingStyle.fill;

  _M3ExpressiveSpinnerPainter({
    required this.progressListenable,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  }) : super(repaint: progressListenable);

  void _ensurePaints(Offset center, double radius) {
    if (_cachedRadius == radius && _cachedPrimaryPaint != null) return;
    _cachedRadius = radius;
    _trackPaint.color = trackColor;
    _dotPaint.color = secondaryColor;
    _cachedPrimaryPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.2),
          primaryColor,
          secondaryColor,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    final progress = progressListenable.value;

    _ensurePaints(center, radius);

    // 1. Draw Track
    canvas.drawCircle(center, radius, _trackPaint);

    // 2. Main Morphing Primary Arc — rotate canvas instead of rebuilding shader
    final rotationAngle = progress * 2 * math.pi;
    const startAngle = 0.0;
    final sweepAngle =
        (math.pi * 0.8) + (math.pi * 0.4 * math.sin(progress * 2 * math.pi));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      _cachedPrimaryPaint!,
    );
    canvas.restore();

    // 3. Counter-rotating Secondary Accent Dot
    final dotAngle = -rotationAngle * 1.5;
    final dotRadius = radius - 7;
    final dotOffset = Offset(
      center.dx + dotRadius * math.cos(dotAngle),
      center.dy + dotRadius * math.sin(dotAngle),
    );
    canvas.drawCircle(dotOffset, 3.0, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant _M3ExpressiveSpinnerPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.trackColor != trackColor;
  }
}
