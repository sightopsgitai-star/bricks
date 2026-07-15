import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/responsive.dart';
import '../widgets/animated_web_background.dart';

/// Alerts screen displaying machine alerts and notifications.
/// Accessed via the notification bell icon in the AppBar (not in bottom nav).
/// Updates dynamically when the selected company changes.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertSeverity? _severityFilter;
  bool _showUnreadOnly = false;

  List<Alert> _getFilteredAlerts(List<Alert> alerts) {
    var filtered = List<Alert>.from(alerts);

    if (_severityFilter != null) {
      filtered = filtered.where((a) => a.severity == _severityFilter).toList();
    }

    if (_showUnreadOnly) {
      filtered = filtered.where((a) => !a.isRead).toList();
    }

    // Sort by timestamp, newest first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedWebBackground(
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          Consumer<CompanyProvider>(
            builder: (context, provider, _) {
              final unread = provider.alerts.where((a) => !a.isRead).length;
              if (unread > 0) {
                return TextButton.icon(
                  onPressed: () {
                    provider.markAllAlertsAsRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All alerts marked as read'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text(
                    'Mark all read',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CompanyProvider>(
        builder: (context, companyProvider, child) {
          final alerts = _getFilteredAlerts(companyProvider.alerts);

          return Column(
            children: [
              // Filter bar
              _buildFilterBar(companyProvider),
              // Alerts list
              Expanded(
                child: companyProvider.alerts.isEmpty
                    ? _buildEmptyState(false)
                    : alerts.isEmpty
                        ? _buildEmptyState(true)
                        : _buildAlertsList(companyProvider, alerts),
              ),
            ],
          );
        },
      ),
    ));
  }

  Widget _buildFilterBar(CompanyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A2433)
            : Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Severity filter
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All',
                    isSelected: _severityFilter == null,
                    onSelected: () =>
                        setState(() => _severityFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Critical',
                    isSelected:
                        _severityFilter == AlertSeverity.critical,
                    onSelected: () => setState(
                        () => _severityFilter = AlertSeverity.critical),
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'High',
                    isSelected: _severityFilter == AlertSeverity.high,
                    onSelected: () => setState(
                        () => _severityFilter = AlertSeverity.high),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Medium',
                    isSelected: _severityFilter == AlertSeverity.medium,
                    onSelected: () => setState(
                        () => _severityFilter = AlertSeverity.medium),
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Low',
                    isSelected: _severityFilter == AlertSeverity.low,
                    onSelected: () => setState(
                        () => _severityFilter = AlertSeverity.low),
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Unread toggle
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showUnreadOnly ? Icons.mail : Icons.mail_outline,
                  size: 16,
                  color: _showUnreadOnly
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  'Unread',
                  style: TextStyle(
                    color: _showUnreadOnly
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            selected: _showUnreadOnly,
            onSelected: (_) =>
                setState(() => _showUnreadOnly = !_showUnreadOnly),
            selectedColor: Theme.of(context).primaryColor,
            showCheckmark: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color ?? Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color ?? Theme.of(context).primaryColor,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildEmptyState(bool hasFilters) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off : Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No alerts match your filters'
                : 'No alerts at this time',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _severityFilter = null;
                _showUnreadOnly = false;
              }),
              icon: const Icon(Icons.clear),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsList(
    CompanyProvider provider,
    List<Alert> alerts,
  ) {
    // Group alerts by severity for display
    final criticalAlerts = alerts
        .where((a) => a.severity == AlertSeverity.critical)
        .toList();
    final highAlerts = alerts
        .where((a) => a.severity == AlertSeverity.high)
        .toList();
    final otherAlerts = alerts
        .where(
          (a) =>
              a.severity != AlertSeverity.critical &&
              a.severity != AlertSeverity.high,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        provider.refreshData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResponsiveCenter(
            maxWidth: 900,
            child: Column(
              children: [
                // Summary header
                _buildAlertSummary(alerts),
                const SizedBox(height: 16),

                // Critical alerts section
                if (criticalAlerts.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Critical Alerts',
                    criticalAlerts.length,
                    Colors.red,
                  ),
                  const SizedBox(height: 8),
                  ...criticalAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAlertTile(provider, alert),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // High priority alerts section
                if (highAlerts.isNotEmpty) ...[
                  _buildSectionHeader(
                    'High Priority',
                    highAlerts.length,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...highAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAlertTile(provider, alert),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Other alerts section
                if (otherAlerts.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Other Alerts',
                    otherAlerts.length,
                    Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  ...otherAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAlertTile(provider, alert),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSummary(List<Alert> alerts) {
    final unread = alerts.where((a) => !a.isRead).length;
    final resolved = alerts.where((a) => a.isResolved).length;
    final critical = alerts
        .where((a) => a.severity == AlertSeverity.critical && !a.isResolved)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Total',
                '${alerts.length}',
                Icons.notifications,
                Colors.blue,
              ),
            ),
            Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
            Expanded(
              child: _buildSummaryItem(
                'Unread',
                '$unread',
                Icons.mark_email_unread,
                Colors.orange,
              ),
            ),
            Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
            Expanded(
              child: _buildSummaryItem(
                'Critical',
                '$critical',
                Icons.error,
                Colors.red,
              ),
            ),
            Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
            Expanded(
              child: _buildSummaryItem(
                'Resolved',
                '$resolved',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        )),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertTile(CompanyProvider provider, Alert alert) {
    return AlertTile(
      alert: alert,
      onTap: () => _showAlertDetails(provider, alert),
      onMarkRead: () {
        provider.markAlertAsRead(alert.id);
      },
      onResolve: () {
        _confirmResolve(provider, alert);
      },
    );
  }

  void _showAlertDetails(CompanyProvider provider, Alert alert) {
    // Mark as read when viewing
    if (!alert.isRead) {
      provider.markAlertAsRead(alert.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Alert type with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(
                          alert.severity,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getAlertIcon(alert.type),
                        color: _getSeverityColor(alert.severity),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.typeName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getSeverityColor(alert.severity),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  alert.severityLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (alert.isResolved) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Resolved',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Machine info
                _buildDetailSection('Machine', alert.machineName),
                _buildDetailSection('Machine ID', alert.machineId),
                const SizedBox(height: 16),
                // Message
                const Text(
                  'Description',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(alert.message, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                // Timestamp
                _buildDetailSection(
                  'Timestamp',
                  _formatFullTimestamp(alert.timestamp),
                ),
                const SizedBox(height: 24),
                // Actions
                if (!alert.isResolved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmResolve(provider, alert);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResolve(CompanyProvider provider, Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Alert'),
        content: Text(
          'Mark "${alert.typeName}" on ${alert.machineName} as resolved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.markAlertAsResolved(alert.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alert resolved'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.high:
        return Colors.orange;
      case AlertSeverity.medium:
        return Colors.amber;
      case AlertSeverity.low:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.machineStopped:
        return Icons.power_off;
      case AlertType.highDowntime:
        return Icons.timer_off;
      case AlertType.temperatureWarning:
        return Icons.thermostat;
      case AlertType.maintenanceDue:
        return Icons.build;
      case AlertType.productionTargetMissed:
        return Icons.trending_down;
      case AlertType.abnormalCondition:
        return Icons.warning;
      case AlertType.lowEfficiency:
        return Icons.speed;
      case AlertType.emergencyTriggered:
        return Icons.report;
      case AlertType.vfdFault:
        return Icons.bolt;
      case AlertType.hydraulicPressureLow:
        return Icons.plumbing;
      case AlertType.controlOff:
        return Icons.settings_power;
      case AlertType.machineStop:
        return Icons.stop_circle;
      case AlertType.materialLow:
        return Icons.inventory_2;
      case AlertType.hydraulicOff:
        return Icons.water_drop_outlined;
      case AlertType.programStop:
        return Icons.cancel_presentation;
    }
  }

  String _formatFullTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    String relative;
    if (diff.inMinutes < 1) {
      relative = 'Just now';
    } else if (diff.inMinutes < 60) {
      relative = '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      relative = '${diff.inHours} hours ago';
    } else {
      relative = '${diff.inDays} days ago';
    }

    final dateStr =
        '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    return '$dateStr ($relative)';
  }
}
