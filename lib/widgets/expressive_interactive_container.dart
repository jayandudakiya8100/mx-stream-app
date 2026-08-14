import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Mirarr/utils/expressive_motion.dart';

/// Reusable Material 3 Expressive Interactive Container (`ExpressiveTouch`).
/// Ultra-high performance (120 FPS lock-tight) tactile press scale-down,
/// spring overshoot on release, optional shape morphing, hover scale, and haptics.
class ExpressiveInteractiveContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double hoverScale;
  final double borderRadius;
  final double? pressedBorderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final bool enableHaptics;
  final bool enableHover;
  final ExpressiveSpeed speed;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;

  const ExpressiveInteractiveContainer({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.hoverScale = 1.02,
    this.borderRadius = 28.0,
    this.pressedBorderRadius,
    this.splashColor,
    this.highlightColor,
    this.enableHaptics = true,
    this.enableHover = true,
    this.speed = ExpressiveSpeed.defaultSpeed,
    this.padding,
    this.margin,
    this.decoration,
  });

  @override
  State<ExpressiveInteractiveContainer> createState() =>
      _ExpressiveInteractiveContainerState();
}

typedef ExpressiveTouch = ExpressiveInteractiveContainer;

class _ExpressiveInteractiveContainerState
    extends State<ExpressiveInteractiveContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Animation<double>? _radiusAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.speed.duration,
    );

    _updateAnimations();
  }

  @override
  void didUpdateWidget(ExpressiveInteractiveContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed ||
        oldWidget.pressedScale != widget.pressedScale ||
        oldWidget.hoverScale != widget.hoverScale ||
        oldWidget.borderRadius != widget.borderRadius ||
        oldWidget.pressedBorderRadius != widget.pressedBorderRadius) {
      _controller.duration = widget.speed.duration;
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    final Curve spatialCurve = ExpressiveMotion.getSpatialCurve(widget.speed);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: spatialCurve,
        reverseCurve: spatialCurve,
      ),
    );

    if (widget.pressedBorderRadius != null &&
        widget.pressedBorderRadius != widget.borderRadius) {
      _radiusAnimation = Tween<double>(
        begin: widget.borderRadius,
        end: widget.pressedBorderRadius!,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: spatialCurve,
          reverseCurve: spatialCurve,
        ),
      );
    } else {
      _radiusAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _isPressed = true;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _onHoverChanged(bool isHovered) {
    if (!widget.enableHover) return;
    if (_isHovered != isHovered) {
      setState(() {
        _isHovered = isHovered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.onTap != null || widget.onLongPress != null;

    Widget coreChild = widget.child;
    if (widget.padding != null || widget.margin != null || widget.decoration != null) {
      coreChild = Container(
        padding: widget.padding,
        margin: widget.margin,
        decoration: widget.decoration,
        child: coreChild,
      );
    }

    final theme = Theme.of(context);
    final effectiveSplash =
        widget.splashColor ?? theme.colorScheme.primary.withValues(alpha: 0.12);
    final effectiveHighlight = widget.highlightColor ??
        theme.colorScheme.primary.withValues(alpha: 0.06);

    Widget interactiveContent;
    if (isInteractive) {
      if (_radiusAnimation != null) {
        interactiveContent = AnimatedBuilder(
          animation: _radiusAnimation!,
          child: coreChild,
          builder: (context, child) {
            final double currentRadius = _radiusAnimation!.value;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(currentRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                borderRadius: BorderRadius.circular(currentRadius),
                splashColor: effectiveSplash,
                highlightColor: effectiveHighlight,
                child: child,
              ),
            );
          },
        );
      } else {
        interactiveContent = Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          clipBehavior: Clip.none,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: effectiveSplash,
            highlightColor: effectiveHighlight,
            child: coreChild,
          ),
        );
      }
    } else {
      interactiveContent = coreChild;
    }

    Widget transformedContent = AnimatedBuilder(
      animation: _controller,
      child: interactiveContent,
      builder: (context, child) {
        final double currentScale =
            _isHovered && !_isPressed ? widget.hoverScale : _scaleAnimation.value;
        if (currentScale == 1.0) return child!;
        return Transform.scale(
          scale: currentScale,
          alignment: Alignment.center,
          child: child,
        );
      },
    );

    if (isInteractive && widget.enableHover) {
      return MouseRegion(
        onEnter: (_) => _onHoverChanged(true),
        onExit: (_) => _onHoverChanged(false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: transformedContent,
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: transformedContent,
    );
  }
}
