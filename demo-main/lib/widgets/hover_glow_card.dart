import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A card wrapper that adds a hover-based elevation lift and a colored glow
/// effect around the card. This effect is only active on web platforms.
///
/// On mobile, it simply renders the child as-is with no hover behavior.
class HoverGlowCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowSpread;
  final double glowBlur;
  final double hoverElevation;
  final double baseElevation;
  final BorderRadius? borderRadius;
  final Duration duration;

  const HoverGlowCard({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF4CAF50), // Green glow by default
    this.glowSpread = 2.0,
    this.glowBlur = 16.0,
    this.hoverElevation = 12.0,
    this.baseElevation = 2.0,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<HoverGlowCard> createState() => _HoverGlowCardState();
}

class _HoverGlowCardState extends State<HoverGlowCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Only apply hover effects on web
    if (!kIsWeb) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: _isHovered ? 1.0 : 0.0,
        ),
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -4 * value), // Lift up on hover
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                boxShadow: [
                  // Glow shadow
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.0 + 0.35 * value),
                    blurRadius: widget.glowBlur * value,
                    spreadRadius: widget.glowSpread * value,
                  ),
                  // Standard shadow (elevation)
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.08 + 0.08 * value,
                    ),
                    blurRadius: 4 + 12 * value,
                    offset: Offset(0, 2 + 4 * value),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A reusable hover scale wrapper that adds a subtle scale-up on hover (web only).
class HoverScaleWidget extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final Duration duration;

  const HoverScaleWidget({
    super.key,
    required this.child,
    this.hoverScale = 1.03,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.hoverScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
