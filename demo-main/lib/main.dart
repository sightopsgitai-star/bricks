import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_config.dart';

/// Main entry point for the Industrial Machine Monitoring Dashboard.
/// Sets up providers for global state management and initializes services.
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // When running as a web app, allow the backend URL to be supplied via
  // the ?backendUrl=https://xxx.ngrok-free.dev query parameter so the app
  // can reach the OPC-UA bridge through its ngrok tunnel.
  if (kIsWeb) {
    final backendParam = Uri.base.queryParameters['backendUrl'];
    if (backendParam != null && backendParam.isNotEmpty) {
      try {
        final origin = Uri.parse(backendParam).origin;
        ApiConfig.overrideUrl = origin;
        if (kDebugMode) debugPrint('[ApiConfig] Backend override → $origin');
      } catch (_) {
        // ignore malformed URLs
      }
    }
  }

  runApp(const IndustrialMonitorApp());
}

/// Root application widget.
/// Wraps the app with MultiProvider for state management.
class IndustrialMonitorApp extends StatelessWidget {
  const IndustrialMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Set up all providers for global state management
      providers: [
        // AuthProvider handles user authentication state
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // CompanyProvider manages company selection and related data
        ChangeNotifierProvider(create: (_) => CompanyProvider()),

        // ThemeProvider manages dark/light mode and system detection
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        // TicketProvider handles support tickets
        ChangeNotifierProvider(create: (_) => TicketProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'SLV',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,

            // ─── Light Theme ───
            theme: _buildLightTheme(),

            // ─── Dark Theme ───
            darkTheme: _buildDarkTheme(),

            // Start with splash screen
            home: const SplashScreen(),
          );
        },
      ),
    );
  }

  /// Build the light theme configuration
  ThemeData _buildLightTheme() {
    return ThemeData(
      // Use deep blue as primary color for industrial feel
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0), // Industrial blue
        brightness: Brightness.light,
      ),

      // Use Material 3 design
      useMaterial3: true,

      // Scaffold background
      scaffoldBackgroundColor: Colors.transparent,

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1565C0),
            );
          }
          return const TextStyle(fontSize: 12, color: Colors.grey);
        }),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
    );
  }

  /// Build the dark theme configuration
  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF42A5F5), // Lighter blue for dark mode
        brightness: Brightness.dark,
      ),

      useMaterial3: true,

      // Dark scaffold background
      scaffoldBackgroundColor: Colors.transparent,

      // Card theme for dark mode
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // AppBar theme for dark mode
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),

      // Navigation bar theme for dark mode
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF42A5F5),
            );
          }
          return const TextStyle(fontSize: 12, color: Colors.grey);
        }),
      ),

      // Navigation rail theme for dark mode
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0F172A),
      ),

      // Elevated button theme for dark mode
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42A5F5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input decoration theme for dark mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 2),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
      ),
    );
  }
}
