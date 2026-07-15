import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/animated_web_background.dart';
import 'login_screen.dart';

/// Splash screen that displays the Armix Machinery company logo
/// with a smooth fade-in and scale animation before navigating to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // Navigate to login after the splash animation completes
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashBody = _buildSplashBody();

    final splashContent = Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : null,
      body: kIsWeb
          ? splashBody
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1565C0),
                    Color(0xFF0D47A1),
                    Color(0xFF1A237E),
                  ],
                ),
              ),
              child: splashBody,
            ),
    );

    // Wrap with scrolling background on web
    if (kIsWeb) {
      return AnimatedWebBackground(child: splashContent);
    }
    return splashContent;
  }

  /// Builds the splash body content (logo, company name, loading indicator)
  Widget _buildSplashBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
      children: [
        // Company logo
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/AppIcons/playstore.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Company name
        FadeTransition(
          opacity: _fadeAnimation,
          child: const Text(
            'Armix Machinery',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Location
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Bengaluru',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 48),
        // Loading indicator
        FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
