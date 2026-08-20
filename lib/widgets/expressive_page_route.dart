import 'package:flutter/material.dart';
import 'package:mxstream/utils/expressive_motion.dart';

/// Custom Material 3 Expressive Page Transition Route.
/// Fast, lock-tight 120 FPS page transition utilizing Spatial Spring scale morphing
/// and Effects Spring fade transitions.
class ExpressivePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final ExpressiveSpeed speed;

  ExpressivePageRoute({
    required this.page,
    this.speed = ExpressiveSpeed.defaultSpeed,
    super.settings,
  }) : super(
          transitionDuration: speed.duration,
          reverseTransitionDuration: speed.duration,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(
                CurveTween(curve: ExpressiveMotion.getEffectsCurve(speed)),
              ),
              child: ScaleTransition(
                scale: animation.drive(
                  Tween(begin: 0.94, end: 1.0).chain(
                    CurveTween(curve: ExpressiveMotion.getSpatialCurve(speed)),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}
