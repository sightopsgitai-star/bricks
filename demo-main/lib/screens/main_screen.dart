import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/responsive.dart';
import '../widgets/animated_web_background.dart';
import 'home_screen.dart';
import 'energy_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';
import 'tickets_screen.dart';

/// Main screen with bottom navigation and IndexedStack for state persistence.
class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;

  // Sidebar animation controllers (web only)
  AnimationController? _sidebarParticleController;
  AnimationController? _sidebarGlowController;
  final List<_SidebarParticle> _sidebarParticles = [];

  // Screens are preserved using IndexedStack
  final List<Widget> _screens = const [
    HomeScreen(),
    EnergyScreen(),
    ReportsScreen(),
    TicketsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    if (kIsWeb) {
      _sidebarParticleController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 25),
      )..repeat();

      _sidebarGlowController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat(reverse: true);

      final random = Random();
      for (int i = 0; i < 15; i++) {
        _sidebarParticles.add(_SidebarParticle(
          x: random.nextDouble(), y: random.nextDouble(),
          size: random.nextDouble() * 2 + 0.5,
          speed: random.nextDouble() * 0.2 + 0.05,
          opacity: random.nextDouble() * 0.15 + 0.05,
          angle: random.nextDouble() * 2 * pi,
        ));
      }
    }
  }

  @override
  void dispose() {
    _sidebarParticleController?.dispose();
    _sidebarGlowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return AnimatedWebBackground(
      child: Scaffold(
        appBar: _buildAppBar(),
        body: isMobile
            ? IndexedStack(index: _currentIndex, children: _screens)
            : Row(
                children: [
                  kIsWeb ? _buildAnimatedSidebar() : _buildNavigationRail(),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      ),
    );
  }

  Widget _buildAnimatedSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExtended = Responsive.isDesktop(context);
    final sidebarWidth = isExtended ? 200.0 : 80.0;

    return SizedBox(
      width: sidebarWidth,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sidebarGlowController!,
                builder: (context, _) {
                  final glow = _sidebarGlowController!.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF0D1520), Color.lerp(const Color(0xFF0D1520), const Color(0xFF132035), glow)!, const Color(0xFF0F1923), Color.lerp(const Color(0xFF0F1923), const Color(0xFF0D1520), 1 - glow)!]
                            : [Color.lerp(const Color(0xFFE8EDF5), const Color(0xFFDDE5F0), glow)!, const Color(0xFFECF0F6), Color.lerp(const Color(0xFFECF0F6), const Color(0xFFE3EAF4), 1 - glow)!, const Color(0xFFE8EDF5)],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Theme(
                data: Theme.of(context).copyWith(
                  navigationRailTheme: NavigationRailThemeData(
                    backgroundColor: Colors.transparent,
                    indicatorColor: isDark ? const Color(0xFF42A5F5).withValues(alpha: 0.25) : const Color(0xFF1565C0).withValues(alpha: 0.15),
                    selectedIconTheme: IconThemeData(color: isDark ? const Color(0xFF42A5F5) : const Color(0xFF1565C0)),
                    unselectedIconTheme: IconThemeData(color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF334155)),
                  ),
                ),
                child: _buildNavigationRail(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final companyName = context.watch<CompanyProvider>().selectedCompany?.name ?? 'Bricks';
    return AppBar(
      title: Text(companyName),
      centerTitle: false,
      elevation: 0,
      actions: [
        const CompanyDropdown(),
        const SizedBox(width: 4),
        Consumer<CompanyProvider>(
          builder: (context, provider, _) {
            final unreadCount = provider.unreadAlertCount;
            return IconButton(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount > 9 ? '9+' : '$unreadCount', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildNavigationRail() {
    final ticketProvider = context.watch<TicketProvider>();
    final openCount = ticketProvider.openTicketCount;

    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      extended: Responsive.isDesktop(context),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: Text('Energy'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: openCount > 0,
            label: Text('$openCount'),
            child: const Icon(Icons.support_agent_outlined),
          ),
          selectedIcon: const Icon(Icons.support_agent),
          label: const Text('Support'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final ticketProvider = context.watch<TicketProvider>();
    final openCount = ticketProvider.openTicketCount;

    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      destinations: [
        const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
        const NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Energy'),
        const NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Reports'),
        NavigationDestination(
          icon: Badge(isLabelVisible: openCount > 0, label: Text('$openCount'), child: const Icon(Icons.support_agent_outlined)),
          selectedIcon: const Icon(Icons.support_agent),
          label: 'Support',
        ),
        const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  void _handleLogout() {
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}

class _SidebarParticle {
  double x, y, size, speed, opacity, angle;
  _SidebarParticle({required this.x, required this.y, required this.size, required this.speed, required this.opacity, required this.angle});
}
