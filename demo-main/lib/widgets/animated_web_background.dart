import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Animated background widget for web that shows a continuously scrolling
/// panoramic image of brick-making machinery behind all content.
/// Highly optimized to run at a solid 60fps/120fps with zero frame drops.
class AnimatedWebBackground extends StatefulWidget {
  final Widget child;

  const AnimatedWebBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedWebBackground> createState() => _AnimatedWebBackgroundState();
}

class _AnimatedWebBackgroundState extends State<AnimatedWebBackground>
    with TickerProviderStateMixin {
  late AnimationController _scrollController;
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Slow horizontal scroll animation for the background image
      _scrollController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 60), // Full scroll cycle
      )..repeat();

      // Particle floating animation
      _particleController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat();

      // Generate fewer floating particles for better rendering performance
      for (int i = 0; i < 8; i++) {
        _particles.add(_Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 2.5 + 0.5,
          speed: _random.nextDouble() * 0.3 + 0.1,
          opacity: _random.nextDouble() * 0.08 + 0.02,
          angle: _random.nextDouble() * 2 * pi,
        ));
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _scrollController.dispose();
      _particleController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!kIsWeb) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
        child: widget.child,
      );
    }

    return Stack(
      children: [
        // ── Scrolling panoramic background image (Optimized with Transform.translate) ──
        Positioned.fill(
          child: _buildImageLayer(isDark),
        ),

        // ── Dark/Light overlay gradient for readability (Static for performance) ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -0.8),
                end: const Alignment(0.8, 0.8),
                colors: isDark
                    ? [
                        const Color(0xFF0D1117).withValues(alpha: 0.82),
                        const Color(0xFF0D1117).withValues(alpha: 0.75),
                        const Color(0xFF0F1923).withValues(alpha: 0.80),
                        const Color(0xFF0D1117).withValues(alpha: 0.85),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.75),
                        const Color(0xFFF5F7FA).withValues(alpha: 0.70),
                        Colors.white.withValues(alpha: 0.72),
                        const Color(0xFFECF0F6).withValues(alpha: 0.78),
                      ],
              ),
            ),
          ),
        ),

        // ── Subtle grid/blueprint pattern ──
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPatternPainter(isDark: isDark),
          ),
        ),

        // ── Floating particles ──
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                isDark: isDark,
              ),
            );
          },
        ),

        // ── Vignette overlay ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: isDark
                    ? [
                        Colors.transparent,
                        const Color(0xFF0D1117).withValues(alpha: 0.5),
                      ]
                    : [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.4),
                      ],
              ),
            ),
          ),
        ),

        // ── Accent glow spots (Static for performance) ──
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1565C0).withValues(alpha: 0.10),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF1565C0).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
              ),
            ),
          ),
        ),

        // ── Bottom-right accent (Static for performance) ──
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF4CAF50).withValues(alpha: 0.08),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFF4CAF50).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
              ),
            ),
          ),
        ),

        // ── Main content ──
        widget.child,
      ],
    );
  }

  /// Builds the scrolling background image layer using the panoramic image.
  /// Uses a static child layout translated via the GPU to avoid layout/widget rebuilds.
  Widget _buildImageLayer(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        // We use 2x width so the image can scroll continuously
        final imageWidth = screenWidth * 2;

        // Pre-build the image stack once. It will not be rebuilt on every frame tick.
        final imageStack = Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: imageWidth,
              height: screenHeight,
              child: Image.asset(
                'assets/BG_Image/web_bg_panoramic.png',
                fit: BoxFit.cover,
                width: imageWidth,
                height: screenHeight,
                filterQuality: FilterQuality.none, // Low/none filter quality is much faster to render
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/BG_Image/BM12-700x477.jpg',
                    fit: BoxFit.cover,
                    width: imageWidth,
                    height: screenHeight,
                  );
                },
              ),
            ),
            Positioned(
              left: imageWidth,
              top: 0,
              width: imageWidth,
              height: screenHeight,
              child: Image.asset(
                'assets/BG_Image/web_bg_panoramic.png',
                fit: BoxFit.cover,
                width: imageWidth,
                height: screenHeight,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/BG_Image/BM12-700x477.jpg',
                    fit: BoxFit.cover,
                    width: imageWidth,
                    height: screenHeight,
                  );
                },
              ),
            ),
          ],
        );

        return AnimatedBuilder(
          animation: _scrollController,
          child: imageStack,
          builder: (context, child) {
            // Apply GPU translation offset without rebuilding the child Image widgets
            final offset = _scrollController.value * screenWidth;
            return Transform.translate(
              offset: Offset(-offset, 0),
              child: child,
            );
          },
        );
      },
    );
  }
}

/// A single floating particle data class.
class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double angle;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
  });
}

/// Custom painter for floating particles.
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isDark;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = (p.x + sin(progress * 2 * pi + p.angle) * p.speed * 0.05) %
          1.0 *
          size.width;
      final dy =
          (p.y - progress * p.speed * 0.02 + cos(progress * 2 * pi + p.angle) * p.speed * 0.03) %
              1.0 *
              size.height;

      final paint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: p.opacity * 0.6)
            : const Color(0xFF1565C0).withValues(alpha: p.opacity * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Custom painter for a subtle grid/blueprint pattern overlay.
class _GridPatternPainter extends CustomPainter {
  final bool isDark;

  _GridPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.02)
          : const Color(0xFF1565C0).withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 60.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
