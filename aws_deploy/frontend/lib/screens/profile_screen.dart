import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/responsive.dart';
import '../widgets/hover_glow_card.dart';

/// Profile screen showing SIM recharge info, support options,
/// user/company info, dark mode toggle, and usage stats.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  Widget build(BuildContext context) {
    return Consumer<CompanyProvider>(
      builder: (context, companyProvider, child) {
        final profile = companyProvider.profileData;

        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ResponsiveCenter(
                maxWidth: 800,
                child: Responsive.isMobile(context)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserInfoCard(profile.userInfo),
                          const SizedBox(height: 16),
                          _buildDarkModeCard(),
                          const SizedBox(height: 16),
                          _buildCompanyInfoCard(profile.companyInfo),
                          const SizedBox(height: 16),
                          _buildSimRechargeCard(profile.simInfo),
                          const SizedBox(height: 16),
                          _buildSupportTicketCard(),
                          const SizedBox(height: 80),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    HoverGlowCard(child: _buildUserInfoCard(profile.userInfo)),
                                    const SizedBox(height: 16),
                                    HoverGlowCard(child: _buildDarkModeCard()),
                                    const SizedBox(height: 16),
                                    HoverGlowCard(child: _buildCompanyInfoCard(profile.companyInfo)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    HoverGlowCard(child: _buildSimRechargeCard(profile.simInfo)),
                                    const SizedBox(height: 16),
                                    HoverGlowCard(child: _buildSupportTicketCard()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 200),
                        ],
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'call_support',
                onPressed: _openDialPad,
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text(
                  '24/7 Support',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDarkModeCard() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final isSystem = themeProvider.isSystemMode;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.amber : Colors.indigo).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? Colors.amber : Colors.indigo,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Appearance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeOption(
                  icon: Icons.phone_android,
                  title: 'Use System Theme',
                  subtitle: 'Automatically match your device settings',
                  trailing: Switch(
                    value: isSystem,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      if (val) {
                        themeProvider.useSystemTheme();
                      } else {
                        themeProvider.toggleDarkMode(isDark);
                      }
                    },
                  ),
                ),
                const Divider(height: 24),
                AnimatedOpacity(
                  opacity: isSystem ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildThemeOption(
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    subtitle: isDark ? 'Dark theme is active' : 'Light theme is active',
                    trailing: Switch(
                      value: isDark,
                      activeThumbColor: Colors.amber.shade700,
                      onChanged: isSystem
                          ? null
                          : (val) => themeProvider.toggleDarkMode(val),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildUserInfoCard(UserInfo userInfo) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF1565C0), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Information',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(userInfo.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(userInfo.role,
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoCard(CompanyProfileInfo companyInfo) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                const Text('Company Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.apartment, 'Company Name', companyInfo.name),
            const Divider(height: 24),
            _buildInfoRow(Icons.location_on, 'Location', companyInfo.location),
            const Divider(height: 24),
            _buildInfoRow(Icons.precision_manufacturing, 'Total Machines', '${companyInfo.totalMachines}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSimRechargeCard(SimRechargeInfo simInfo) {
    final isLow = simInfo.remainingDays < 30;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sim_card, color: Colors.teal.shade600, size: 22),
                const SizedBox(width: 8),
                const Text('SIM Recharge Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, 'Last Recharge Date', _dateFormat.format(simInfo.lastRechargeDate)),
            const Divider(height: 24),
            _buildInfoRow(Icons.event, 'Plan Validity', _dateFormat.format(simInfo.planValidity)),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.hourglass_bottom, size: 20, color: isLow ? Colors.red : Colors.green),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remaining Days', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('${simInfo.remainingDays}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                            color: isLow ? Colors.red : Colors.green.shade700)),
                        const SizedBox(width: 4),
                        Text('days', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportTicketCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.indigo.shade600, size: 22),
                const SizedBox(width: 8),
                const Text('Support Center', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Having an issue? Raise a support ticket in our specialized support desk to track response times.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // This is a placeholder since the ProfileScreen doesn't have access to the MainScreen's state
                  // but in a real app, you'd use a GlobalKey or similar to switch tabs.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please use the "Support" tab in the sidebar to raise tickets.')),
                  );
                },
                icon: const Icon(Icons.support_agent, size: 20),
                label: const Text('Go to Support Desk'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  void _openDialPad() async {
    const phoneNumber = '1800-ARMIX-HELP';
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
