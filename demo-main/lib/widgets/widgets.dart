import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'hover_glow_card.dart';
import '../services/opc_bridge_service.dart';

/// Company dropdown widget for global company selection.
/// Appears in the app bar and affects data across all screens.
class CompanyDropdown extends StatelessWidget {
  const CompanyDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    if (!isAdmin) return const SizedBox.shrink();

    return Consumer<CompanyProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),

            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedCompany?.id,
              dropdownColor: Theme.of(context).primaryColor,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: provider.companies.map((company) {
                return DropdownMenuItem<String>(
                  value: company.id,
                  child: Text(
                    company.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (String? companyId) {
                if (companyId != null) {
                  provider.selectCompanyById(companyId);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// Statistic card widget for displaying dashboard metrics.
/// Shows a value with label and optional icon/color coding.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 2,
      color: backgroundColor ?? Theme.of(context).cardTheme.color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale padding and fonts based on available width
            final isCompact = constraints.maxWidth < 140;
            final cardPadding = isCompact ? 10.0 : 16.0;
            final titleFontSize = isCompact ? 11.0 : 13.0;
            final valueFontSize = isCompact ? 18.0 : 24.0;
            final subtitleFontSize = isCompact ? 10.0 : 12.0;
            final iconSize = isCompact ? 16.0 : 20.0;
            final iconPadding = isCompact ? 6.0 : 8.0;

            return Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: (iconColor ?? Theme.of(context).primaryColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor ?? Theme.of(context).primaryColor,
                          size: iconSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    // Wrap with hover glow on web only
    if (kIsWeb) {
      return HoverGlowCard(child: card);
    }
    return card;
  }
}

/// Machine card widget for displaying individual machine status.
class MachineCard extends StatefulWidget {
  final Machine machine;
  final VoidCallback? onTap;

  const MachineCard({super.key, required this.machine, this.onTap});

  @override
  State<MachineCard> createState() => _MachineCardState();
}

class _MachineCardState extends State<MachineCard> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Status indicator dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(width: 12),
              // Machine info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.machine.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.machine.type} • ${widget.machine.id}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Controls and Badges Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle Switch for Machine Control
                      _isToggling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                if (!auth.isAdmin) {
                                  return const SizedBox.shrink();
                                }
                                final isAdmin = auth.isAdmin;
                                final bool isSwitchEnabled = !widget.machine.adminDisabled || isAdmin;

                                return Switch.adaptive(
                                  value: widget.machine.isRunning,
                                  activeColor: Colors.green,
                                  onChanged: isSwitchEnabled
                                      ? (value) async {
                                          setState(() => _isToggling = true);
                                          try {
                                            final bridge = OpcBridgeService();
                                            if (isAdmin) {
                                              final clientId = context.read<CompanyProvider>().selectedCompany?.id ?? '';
                                              await bridge.setMachineOverride(clientId, widget.machine.id, value);
                                            } else {
                                              await bridge.toggleMachineClient(widget.machine.id, value);
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${widget.machine.name} ${value ? 'started' : 'stopped'}'),
                                                  backgroundColor: value ? Colors.green : Colors.red,
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                              // Refresh provider data
                                              context.read<CompanyProvider>().refreshData();
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _isToggling = false);
                                            }
                                          }
                                        }
                                      : null, // Disabled for client if adminDisabled is true
                                );
                              },
                            ),
                    ],
                  ),
                  // Additional badges below control
                  if (widget.machine.vfdFault) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 9, color: Colors.orange),
                          SizedBox(width: 3),
                          Text('VFD Fault',
                            style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  if (widget.machine.isRunning && !widget.machine.vfdFault && !widget.machine.adminDisabled) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${widget.machine.efficiency.toStringAsFixed(1)}% Eff',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (kIsWeb) {
      return HoverGlowCard(child: card);
    }
    return card;
  }

  Color _getStatusColor() {
    if (widget.machine.adminDisabled) return Colors.red.shade700;
    if (widget.machine.vfdFault)      return Colors.orange;
    switch (widget.machine.status) {
      case MachineStatus.running:
        return Colors.green;
      case MachineStatus.stopped:
        return Colors.red;
      case MachineStatus.maintenance:
        return Colors.orange;
    }
  }
}

/// Alert tile widget for displaying individual alerts.
class AlertTile extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onResolve;

  const AlertTile({
    super.key,
    required this.alert,
    this.onTap,
    this.onMarkRead,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    // For read cards, use a slightly dimmed version of the card color
    final readCardColor = isDark
        ? const Color(0xFF151D2C)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Card(
      elevation: alert.isRead ? 0 : 2,
      color: alert.isRead ? readCardColor : cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Severity indicator
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getSeverityColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Alert content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getAlertIcon(),
                              size: 18,
                              color: _getSeverityColor(),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alert.typeName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: alert.isRead
                                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // Severity badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getSeverityColor().withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                alert.severityLabel,
                                style: TextStyle(
                                  color: _getSeverityColor(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.machineName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Timestamp and actions
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(alert.timestamp),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), fontSize: 11),
                  ),
                  const Spacer(),
                  if (alert.isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Resolved',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!alert.isRead && onMarkRead != null)
                    TextButton(
                      onPressed: onMarkRead,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Mark Read',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  if (!alert.isResolved && onResolve != null)
                    TextButton(
                      onPressed: onResolve,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Resolve',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor() {
    switch (alert.severity) {
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

  IconData _getAlertIcon() {
    switch (alert.type) {
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Production time period selector widget.
/// Allows switching between daily, weekly, monthly, and yearly views.
class TimePeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const TimePeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          _buildPeriodButton(context, 'Today', 'today'),
          _buildPeriodButton(context, 'Weekly', 'weekly'),
          _buildPeriodButton(context, 'Monthly', 'monthly'),
          _buildPeriodButton(context, 'Yearly', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(BuildContext context, String label, String value) {
    final isSelected = selectedPeriod == value;
    return GestureDetector(
      onTap: () => onPeriodChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
