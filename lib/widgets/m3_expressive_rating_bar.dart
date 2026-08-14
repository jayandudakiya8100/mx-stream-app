import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';

/// Material 3 Expressive Rating Bar Widget.
/// Features interactive drag/tap gestures, haptic feedback on step changes,
/// spring scale animation on selection, score badge header, and full/half star rendering.
/// Dispatches live [onRatingUpdate] during drag gestures for local state updates,
/// and [onRatingEnd] exclusively when the gesture completes (finger/mouse release) for API calls.
class ExpressiveRatingBar extends StatefulWidget {
  final double initialRating;
  final double minRating;
  final double maxRating;
  final int itemCount;
  final bool allowHalfRating;
  final double itemSize;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onRatingUpdate;
  final ValueChanged<double>? onRatingEnd;
  final bool showScoreBadge;

  const ExpressiveRatingBar({
    super.key,
    this.initialRating = 5.0,
    this.minRating = 1.0,
    this.maxRating = 10.0,
    this.itemCount = 10,
    this.allowHalfRating = true,
    this.itemSize = 30.0,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.white24,
    this.onRatingUpdate,
    this.onRatingEnd,
    this.showScoreBadge = true,
  });

  @override
  State<ExpressiveRatingBar> createState() => _ExpressiveRatingBarState();
}

class _ExpressiveRatingBarState extends State<ExpressiveRatingBar> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating.clamp(widget.minRating, widget.maxRating);
  }

  @override
  void didUpdateWidget(ExpressiveRatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _currentRating = widget.initialRating.clamp(widget.minRating, widget.maxRating);
    }
  }

  void _updateRatingFromOffset(Offset localPosition, double totalWidth) {
    if (totalWidth <= 0) return;
    final double stepValue = widget.maxRating / widget.itemCount;
    final double rawValue = (localPosition.dx / totalWidth) * widget.maxRating;
    
    double calculatedRating;
    if (widget.allowHalfRating) {
      final double halfStep = stepValue / 2.0;
      calculatedRating = (rawValue / halfStep).round() * halfStep;
    } else {
      calculatedRating = (rawValue / stepValue).round() * stepValue;
    }

    calculatedRating = calculatedRating.clamp(widget.minRating, widget.maxRating);

    if ((_currentRating - calculatedRating).abs() >= (widget.allowHalfRating ? 0.49 : 0.99)) {
      HapticFeedback.selectionClick();
    }

    if (_currentRating != calculatedRating) {
      setState(() {
        _currentRating = calculatedRating;
      });
      widget.onRatingUpdate?.call(_currentRating);
    }
  }

  void _notifyRatingEnd() {
    final callback = widget.onRatingEnd ?? widget.onRatingUpdate;
    callback?.call(_currentRating);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double stepValue = widget.maxRating / widget.itemCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showScoreBadge) ...[
          AnimatedContainer(
            duration: ExpressiveSpeed.fast.duration,
            curve: ExpressiveMotion.spatialFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: widget.activeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.activeColor.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: widget.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentRating.toStringAsFixed(widget.allowHalfRating ? 1 : 0),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: widget.activeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' / ${widget.maxRating.toInt()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;

            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                _updateRatingFromOffset(details.localPosition, availableWidth);
              },
              onHorizontalDragEnd: (details) {
                _notifyRatingEnd();
              },
              onTapDown: (details) {
                _updateRatingFromOffset(details.localPosition, availableWidth);
              },
              onTapUp: (details) {
                _notifyRatingEnd();
              },
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.itemCount, (index) {
                    final double starValue = (index + 1) * stepValue;
                    final double prevStarValue = index * stepValue;
                    final double halfStarValue = prevStarValue + (stepValue / 2.0);

                    IconData iconData;
                    Color iconColor;

                    if (_currentRating >= starValue) {
                      iconData = Icons.star_rounded;
                      iconColor = widget.activeColor;
                    } else if (widget.allowHalfRating && _currentRating >= halfStarValue) {
                      iconData = Icons.star_half_rounded;
                      iconColor = widget.activeColor;
                    } else {
                      iconData = Icons.star_outline_rounded;
                      iconColor = widget.inactiveColor;
                    }

                    final bool isSelectedStar =
                        (_currentRating - starValue).abs() < (stepValue / 2.0) ||
                        (_currentRating - halfStarValue).abs() < (stepValue / 4.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ExpressiveInteractiveContainer(
                        speed: ExpressiveSpeed.fast,
                        pressedScale: 0.85,
                        hoverScale: 1.15,
                        onTap: () {
                          double newRating;
                          if (widget.allowHalfRating && _currentRating == starValue) {
                            newRating = halfStarValue;
                          } else if (_currentRating == halfStarValue) {
                            newRating = prevStarValue;
                          } else {
                            newRating = starValue;
                          }
                          newRating = newRating.clamp(widget.minRating, widget.maxRating);

                          HapticFeedback.lightImpact();
                          setState(() {
                            _currentRating = newRating;
                          });
                          widget.onRatingUpdate?.call(_currentRating);
                          _notifyRatingEnd();
                        },
                        child: AnimatedScale(
                          scale: isSelectedStar ? 1.18 : 1.0,
                          duration: ExpressiveSpeed.fast.duration,
                          curve: ExpressiveMotion.spatialFast,
                          child: Icon(
                            iconData,
                            size: widget.itemSize,
                            color: iconColor,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
