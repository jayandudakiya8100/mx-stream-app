import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Preset motion speeds for Material 3 Expressive System
enum ExpressiveSpeed {
  /// Fast interactions (~150-250ms)
  fast,

  /// Default interactions (~300-400ms)
  defaultSpeed,

  /// Slow / heroic transitions (~500ms+)
  slow,
}

/// Helper extension to get duration for each speed preset
extension ExpressiveSpeedDuration on ExpressiveSpeed {
  Duration get duration {
    switch (this) {
      case ExpressiveSpeed.fast:
        return const Duration(milliseconds: 200);
      case ExpressiveSpeed.defaultSpeed:
        return const Duration(milliseconds: 350);
      case ExpressiveSpeed.slow:
        return const Duration(milliseconds: 550);
    }
  }
}

/// Fast O(1) Precomputed Spring Curve driven by [SpringSimulation]
class SpringCurve extends Curve {
  final SpringDescription description;
  final double velocity;
  final List<double> _table = List<double>.filled(101, 0.0);

  SpringCurve({
    required this.description,
    this.velocity = 0.0,
  }) {
    final sim = SpringSimulation(description, 0.0, 1.0, velocity);
    for (int i = 0; i <= 100; i++) {
      final double t = i / 100.0;
      _table[i] = sim.x(t).clamp(-0.5, 1.5);
    }
  }

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final double indexD = t * 100.0;
    final int index = indexD.floor();
    final double fraction = indexD - index;
    if (index >= 100) return _table[100];
    return _table[index] + (_table[index + 1] - _table[index]) * fraction;
  }
}

/// Material 3 Expressive Motion Presets & Helper Utilities
class ExpressiveMotion {
  // Spatial Springs: Position, scale, size, corner morphing
  // High responsiveness with subtle overshoot/bounce on release (Damping ratio ~0.75, Stiffness ~350)
  static const SpringDescription spatialSpring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
    damping: 14.0, // Damping ratio ≈ 14 / (2 * sqrt(350)) ≈ 0.748 (subtle bounce)
  );

  // Effects Springs: Opacity, color shifts, blur transitions
  // Smooth transitions without overshoot/bounce (Critically damped: Damping ratio = 1.0, Stiffness ~350)
  static const SpringDescription effectsSpring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
    damping: 37.4, // Damping ratio ≈ 37.4 / (2 * sqrt(350)) ≈ 1.0 (no overshoot)
  );

  /// Pre-built Spatial Spring Curves
  static final Curve spatialFast = SpringCurve(description: spatialSpring, velocity: 0.5);
  static final Curve spatialDefault = SpringCurve(description: spatialSpring, velocity: 0.0);
  static final Curve spatialSlow = SpringCurve(description: spatialSpring, velocity: -0.2);

  /// Pre-built Effects Spring Curves
  static final Curve effectsFast = SpringCurve(description: effectsSpring, velocity: 0.0);
  static final Curve effectsDefault = SpringCurve(description: effectsSpring, velocity: 0.0);
  static final Curve effectsSlow = SpringCurve(description: effectsSpring, velocity: 0.0);

  /// Get appropriate spatial curve for given speed
  static Curve getSpatialCurve(ExpressiveSpeed speed) {
    switch (speed) {
      case ExpressiveSpeed.fast:
        return spatialFast;
      case ExpressiveSpeed.defaultSpeed:
        return spatialDefault;
      case ExpressiveSpeed.slow:
        return spatialSlow;
    }
  }

  /// Get appropriate effects curve for given speed
  static Curve getEffectsCurve(ExpressiveSpeed speed) {
    switch (speed) {
      case ExpressiveSpeed.fast:
        return effectsFast;
      case ExpressiveSpeed.defaultSpeed:
        return effectsDefault;
      case ExpressiveSpeed.slow:
        return effectsSlow;
    }
  }
}
