import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/responsive.dart';
import '../services/opc_bridge_service.dart';

/// Home screen (Dashboard) displaying production statistics.
/// Shows machine status, cycles, downtime, and production metrics.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMachineList = false;
  bool _wasAllActive = false;
  bool _popupShown = false;
  bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CompanyProvider>(
      builder: (context, companyProvider, child) {
        final stats = companyProvider.stats;
        final machines = companyProvider.machines;

        if (companyProvider.isPlcConnected && machines.isNotEmpty && !companyProvider.isLoading) {
          final total = machines.length;
          final running = machines.where((m) => m.status == MachineStatus.running).length;
          final stopped = machines.where((m) => m.status == MachineStatus.stopped).length;

          if (running == total) {
            _wasAllActive = true;
            _popupShown = false;
          } else if (_wasAllActive && stopped == total && !_popupShown && !_isDialogOpen) {
            _popupShown = true;
            _wasAllActive = false;
            _isDialogOpen = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDowntimeReasonDialog(context, companyProvider);
            });
          }
        }

        if (companyProvider.isLoading && stats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            companyProvider.refreshData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live / offline connection banner
                  _buildConnectionBanner(companyProvider),
                  if (!companyProvider.isPlcConnected)
                    const SizedBox(height: 8),
                  // Company info header
                  _buildCompanyHeader(companyProvider),
                  const SizedBox(height: 20),
                  // Machine status cards
                  _buildMachineStatusSection(companyProvider),
                  const SizedBox(height: 20),
                  // Production stats grid
                  _buildProductionStatsGrid(companyProvider),
                  const SizedBox(height: 20),
                  // Daily Production Chart
                  _buildDailyProductionChart(companyProvider),
                  const SizedBox(height: 20),

                  // PLC Telemetry Summary
                  _buildPlcTelemetrySection(stats),
                  const SizedBox(height: 20),

                  // Machine list toggle
                  _buildMachineListSection(machines),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Connection status banner shown at top of dashboard.
  Widget _buildConnectionBanner(CompanyProvider provider) {
    if (provider.isPlcConnected && !provider.isDataStale) {
      // Live data — show subtle green indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Colors.green, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Live — OPC-UA Connected',
                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            if (provider.lastUpdated != null) ...[
              const Spacer(),
              Text(
                'Updated ${_timeSince(provider.lastUpdated!)}',
                style: TextStyle(color: Colors.green.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ],
        ),
      );
    } else {
      // Offline / stale
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provider.isDataStale
                    ? 'Offline — showing last known data'
                    : 'Connecting to OPC-UA bridge…',
                style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => provider.refreshData(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
  }

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  Widget _buildCompanyHeader(CompanyProvider provider) {
    final company = provider.selectedCompany;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/AppIcons/playstore.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company?.name ?? 'Industrial Dashboard',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company?.location ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.machines.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Machines',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMachineStatusSection(CompanyProvider provider) {
    final statusCards = [
      StatCard(
        title: 'Running',
        value: '${provider.machinesRunning}',
        icon: Icons.play_circle_filled,
        iconColor: Colors.green,
        subtitle: 'Active machines',
      ),
      StatCard(
        title: 'Stopped',
        value: '${provider.machinesStopped}',
        icon: Icons.stop_circle,
        iconColor: Colors.red,
        subtitle: 'Inactive machines',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Machine Status',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: statusCards
              .map((card) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: card,
                  )))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildProductionStatsGrid(CompanyProvider companyProvider) {
    final stats = companyProvider.stats!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = Responsive.isMobile(context);

    // Compute a responsive aspect ratio
    double aspectRatio;
    if (isMobile) {
      aspectRatio = screenWidth < 360 ? 1.0 : 1.2;
    } else if (Responsive.isTablet(context)) {
      aspectRatio = 1.4;
    } else {
      aspectRatio = 1.6;
    }

    final rawBlockName = stats.blockName;
    final blockName = (rawBlockName.trim().isEmpty || rawBlockName == '0' || rawBlockName == '0.0') ? '' : rawBlockName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Production Metrics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isMobile ? 2 : Responsive.isTablet(context) ? 3 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            StatCard(
              title: 'System Total Cycle',
              value: _formatNumber(stats.totalCycles),
              icon: Icons.loop,
              iconColor: Colors.blue,
              onTap: () => _showHourlyBreakdownDialog(context, stats),
            ),
            StatCard(
              title: 'Cure Cycle Time',
              value: stats.currentCycleTimeMs > 0
                  ? '${(stats.currentCycleTimeMs / 1000.0).toStringAsFixed(1)} s'
                  : (stats.lastCycleTimeMs > 0
                      ? '${(stats.lastCycleTimeMs / 1000.0).toStringAsFixed(1)} s'
                      : '— s'),
              icon: Icons.timer,
              iconColor: Colors.purple,
              subtitle: stats.lastCycleTimeMs > 0
                  ? 'Last: ${(stats.lastCycleTimeMs / 1000.0).toStringAsFixed(1)} s'
                  : null,
              onTap: () => _showCureCycleTimeDialog(context, stats),
            ),
            StatCard(
              title: 'Actual Count',
              value: _formatNumber(stats.actualCount),
              icon: Icons.layers,
              iconColor: Colors.green.shade700,
              subtitle: blockName.isNotEmpty ? blockName : 'totalBlockCountWithCycle',
            ),
            StatCard(
              title: 'Target Count',
              value: _formatNumber(stats.targetCount),
              icon: Icons.flag,
              iconColor: Colors.amber.shade700,
            ),
            StatCard(
              title: 'Today\'s Cycles',
              value: _formatNumber(stats.todayCycles),
              icon: Icons.today,
              iconColor: Colors.cyan,
            ),
            StatCard(
              title: 'Total Downtime',
              value: stats.formattedDowntime,
              icon: Icons.timer_off,
              iconColor: Colors.red.shade400,
              onTap: () => _showDowntimeReasonDialog(context, companyProvider),
            ),
          ],
        ),
      ],
    );
  }

  void _showCureCycleTimeDialog(BuildContext context, ProductionStats stats) {
    showDialog(
      context: context,
      builder: (context) {
        final currentSec = stats.currentCycleTimeMs / 1000.0;
        final lastSec = stats.lastCycleTimeMs / 1000.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.timer, color: Colors.purple),
              SizedBox(width: 8),
              Text('Cure Cycle Time Details'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogRow(
                  label: 'Current Running:',
                  value: '${stats.currentCycleTimeMs} ms',
                  subValue: '(${currentSec.toStringAsFixed(2)} s)',
                  valueColor: Colors.purple,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildDialogRow(
                  label: 'Last Cycle Time:',
                  value: '${stats.lastCycleTimeMs} ms',
                  subValue: '(${lastSec.toStringAsFixed(2)} s)',
                  valueColor: Colors.green,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow({
    required String label,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
            ),
            Text(
              subValue,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  void _showHourlyBreakdownDialog(BuildContext context, ProductionStats stats) {
    showDialog(
      context: context,
      builder: (context) {
        final hourlyKeys = stats.hourlyBreakdown.keys.toList()..sort();
        // Filter only hours with actual production
        final activeKeys = hourlyKeys.where((k) {
          final d = stats.hourlyBreakdown[k];
          if (d == null) return false;
          final cycles = (d['cycles'] as num?)?.toInt() ?? 0;
          final blocks = (d['blocks'] as num?)?.toInt() ?? 0;
          return cycles > 0 || blocks > 0;
        }).toList();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.loop, color: Colors.blue),
              SizedBox(width: 8),
              Text('Production Summary'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('System Total Cycle:', style: TextStyle(fontSize: 13)),
                        Text(_formatNumber(stats.totalCycles),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Today's Cycles:", style: TextStyle(fontSize: 13)),
                        Text(_formatNumber(stats.todayCycles),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total Block w/ Cycle:', style: TextStyle(fontSize: 13)),
                        Text(_formatNumber(stats.actualCount),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade700)),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Target Count:', style: TextStyle(fontSize: 13)),
                        Text(_formatNumber(stats.targetCount),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade700)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                const Text('Today\'s Hourly Production', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (activeKeys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[400], size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'No hourly breakdown data yet today.\nTotal day: ${_formatNumber(stats.todayCycles)} cycles / ${_formatNumber(stats.actualCount)} blocks',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: activeKeys.length,
                      itemBuilder: (context, index) {
                        final key = activeKeys[index];
                        final hourData = stats.hourlyBreakdown[key]!;
                        final prevKey = index > 0 ? activeKeys[index - 1] : null;
                        final prevData = prevKey != null
                            ? stats.hourlyBreakdown[prevKey]
                            : <String, dynamic>{'cycles': 0, 'blocks': 0};

                        final cycleDelta = ((hourData['cycles'] as num?)?.toInt() ?? 0) -
                            ((prevData?['cycles'] as num?)?.toInt() ?? 0);
                        final blockDelta = ((hourData['blocks'] as num?)?.toInt() ?? 0) -
                            ((prevData?['blocks'] as num?)?.toInt() ?? 0);

                        return ListTile(
                          dense: true,
                          title: Text('${key.toString().padLeft(2, '0')}:00 – ${(int.parse(key.toString())+1).toString().padLeft(2, '0')}:00'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${_formatNumber(cycleDelta)} cycles',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('${_formatNumber(blockDelta)} blocks',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  Widget _buildMachineListSection(List<Machine> machines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _showMachineList = !_showMachineList);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Machine Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(
                _showMachineList
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
            ],
          ),
        ),
        if (_showMachineList) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: machines.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.isMobile(context) ? 1 : (Responsive.isTablet(context) ? 2 : 3),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3.0,
            ),
            itemBuilder: (context, index) {
              return MachineCard(
                machine: machines[index],
                onTap: () => _showMachineDetails(machines[index].id),
              );
            },
          ),
        ],
      ],
    );
  }

  void _showMachineDetails(String machineId) {
    bool isToggling = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer<CompanyProvider>(
            builder: (context, companyProvider, child) {
              final machine = companyProvider.machines.firstWhere(
                (m) => m.id == machineId,
                orElse: () => companyProvider.machines.first,
              );
              final auth = context.read<AuthProvider>();
              final isAdmin = auth.isAdmin;
              final clientId = companyProvider.selectedCompany?.id ?? '';

              return StatefulBuilder(
                builder: (context, setModalState) {
                  final bool isSwitchEnabled = !machine.adminDisabled || isAdmin;

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
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Machine header
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getMachineStatusColor(machine.status),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    machine.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${machine.type} • ${machine.id}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Toggle Switch in sheet
                            isToggling
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : (isAdmin
                                    ? Switch.adaptive(
                                        value: machine.isRunning,
                                        activeColor: Colors.green,
                                        onChanged: isSwitchEnabled
                                            ? (value) async {
                                                setModalState(() => isToggling = true);
                                                try {
                                                  final bridge = OpcBridgeService();
                                                  await bridge.setMachineOverride(clientId, machine.id, value);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${machine.name} ${value ? 'started' : 'stopped'}'),
                                                        backgroundColor: value ? Colors.green : Colors.red,
                                                        duration: const Duration(seconds: 1),
                                                      ),
                                                    );
                                                    // Refresh data
                                                    context.read<CompanyProvider>().refreshData();
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  setModalState(() => isToggling = false);
                                                }
                                              }
                                            : null, // Disabled if client + adminDisabled is true
                                      )
                                    : const SizedBox.shrink()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Stats
                        _buildDetailRow('Status', machine.statusLabel),
                        _buildDetailRow(
                          'Cycle Count',
                          _formatNumber(machine.cycleCount),
                        ),
                        _buildDetailRow(
                          'Cure Cycle Time',
                          '${machine.cureCycleTime} min',
                        ),
                        _buildDetailRow('Downtime', '${machine.downtimeMinutes} min'),
                        _buildDetailRow(
                          'Start Count',
                          '${machine.startCount}',
                        ),
                        _buildDetailRow(
                          'Stop Count',
                          '${machine.stopCount}',
                        ),
                        _buildDetailRow('Temperature', '${machine.temperature}°C'),
                        _buildDetailRow(
                          'Efficiency',
                          '${machine.efficiency.toStringAsFixed(1)}%',
                        ),
                        _buildDetailRow(
                          'Last Maintenance',
                          '${machine.lastMaintenance.day}/${machine.lastMaintenance.month}/${machine.lastMaintenance.year}',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 90) return Colors.green;
    if (efficiency >= 70) return Colors.orange;
    return Colors.red;
  }

  Color _getMachineStatusColor(MachineStatus status) {
    switch (status) {
      case MachineStatus.running:
        return Colors.green;
      case MachineStatus.stopped:
        return Colors.red;
      case MachineStatus.maintenance:
        return Colors.orange;
    }
  }

  /// Formats an integer with thousands separators (e.g. 1234567 → "1,234,567").
  String _formatNumber(int number) {
    return NumberFormat('#,##0').format(number);
  }

  Widget _buildDailyProductionChart(CompanyProvider provider) {
    final report = provider.reportData;
    final liveStats = provider.stats;

    // Build day entries: use DB records + ensure today is always present
    List<DailyProductionRecord> days = [];
    if (report != null && report.dailyRecords.isNotEmpty) {
      days = report.dailyRecords.reversed.take(10).toList().reversed.toList();
    }

    // Always inject today with live data if stats available
    if (liveStats != null) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final alreadyHasToday = days.any((d) =>
          d.date.year == todayDate.year &&
          d.date.month == todayDate.month &&
          d.date.day == todayDate.day);

      final liveTodayCycles = liveStats.todayCycles;
      final liveTodayBlocks = liveStats.actualCount; // totalBlockCountWithCycle

      if (alreadyHasToday) {
        // Upgrade existing today entry with live values if they're higher
        days = days.map((d) {
          final isToday = d.date.year == todayDate.year &&
              d.date.month == todayDate.month &&
              d.date.day == todayDate.day;
          if (isToday) {
            final bestCycles = liveTodayCycles > d.cycles ? liveTodayCycles : d.cycles;
            final bestBlocks = liveTodayBlocks > d.blockCount ? liveTodayBlocks : d.blockCount;
            return DailyProductionRecord(
              date: d.date,
              production: bestBlocks.toDouble(),
              cycles: bestCycles,
              blockCount: bestBlocks,
              downtimeMinutes: d.downtimeMinutes,
              efficiency: d.efficiency,
              activeMachines: d.activeMachines,
              hourlyBreakdown: d.hourlyBreakdown,
            );
          }
          return d;
        }).toList();
      } else if (liveTodayCycles > 0 || liveTodayBlocks > 0) {
        // Add a live today entry at the end
        days.add(DailyProductionRecord(
          date: todayDate,
          production: liveTodayBlocks.toDouble(),
          cycles: liveTodayCycles,
          blockCount: liveTodayBlocks,
          downtimeMinutes: 0,
          efficiency: 0,
          activeMachines: 0,
          hourlyBreakdown: const {},
        ));
      }
    }

    if (days.isEmpty) return const SizedBox.shrink();

    final maxProduction = days.map((d) => d.production).reduce((a, b) => a > b ? a : b);
    final chartMax = maxProduction > 0 ? maxProduction * 1.2 : 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Production History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Blocks / Day',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((day) {
                  final isToday = day.date.day == DateTime.now().day &&
                                  day.date.month == DateTime.now().month &&
                                  day.date.year == DateTime.now().year;

                  final barPercent = day.production / chartMax;

                  return Expanded(
                    child: Tooltip(
                      message: 'Date: ${day.date.day}/${day.date.month}/${day.date.year}\nCycles: ${day.cycles}\nBlocks: ${day.blockCount}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Labels above bar
                          if (day.cycles > 0)
                            Text(
                              'C:${_formatNumber(day.cycles)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday ? Colors.blue[800] : Colors.blueGrey[700],
                              ),
                            ),
                          Text(
                            'B:${_formatNumber(day.blockCount)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.blue[800] : Colors.blueGrey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Bar
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: (160 * barPercent).clamp(2.0, 160.0).toDouble(),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [Colors.blue[400]!, Colors.blue[800]!]
                                    : [Colors.cyan[300]!, Colors.cyan[600]!],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              boxShadow: [
                                BoxShadow(
                                  color: (isToday ? Colors.blue : Colors.cyan).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Date label
                          Text(
                            isToday ? 'Today' : '${day.date.day}/${day.date.month}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.blue[800] : Colors.cyan[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PLC Telemetry summary section — 3 counter cards + efficiency.
  Widget _buildPlcTelemetrySection(ProductionStats stats) {
    // Find blockCount (blocks per cycle / mould count) from rawTags
    int blockCount = 0;
    int rawTotalBlockWithCycle = 0;
    for (final tag in stats.rawTags) {
      if (tag.key == 'blockCount') {
        blockCount = (tag.value as num?)?.toInt() ?? 0;
      }
      if (tag.key == 'totalBlockCountWithCycle') {
        rawTotalBlockWithCycle = (tag.value as num?)?.toInt() ?? 0;
      }
    }

    // totalBlockCountWithCycle — prefer rawTag, fallback to actualCount
    final int totalBlockWithCycle = rawTotalBlockWithCycle > 0
        ? rawTotalBlockWithCycle
        : stats.actualCount;

    // Efficiency = totalBlockWithCycle / targetCount * 100
    final double efficiency = stats.targetCount > 0
        ? (totalBlockWithCycle / stats.targetCount * 100).clamp(0, 999).toDouble()
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'PLC Telemetry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildTelemetryCard(
                      'System Total Cycle',
                      _formatNumber(stats.totalCycles),
                      Icons.loop,
                      Colors.blue.shade600,
                      isMobile,
                      constraints.maxWidth,
                    ),
                    _buildTelemetryCard(
                      'Block Count\n(per cycle)',
                      _formatNumber(blockCount),
                      Icons.grid_view,
                      Colors.green.shade600,
                      isMobile,
                      constraints.maxWidth,
                    ),
                    _buildTelemetryCard(
                      'Total Block w/ Cycle',
                      _formatNumber(totalBlockWithCycle),
                      Icons.layers,
                      Colors.orange.shade700,
                      isMobile,
                      constraints.maxWidth,
                    ),
                    _buildTelemetryCard(
                      'Efficiency',
                      '${efficiency.toStringAsFixed(1)}%',
                      Icons.speed,
                      efficiency >= 80
                          ? Colors.teal.shade600
                          : efficiency >= 50
                              ? Colors.amber.shade700
                              : Colors.red.shade500,
                      isMobile,
                      constraints.maxWidth,
                      subtitle:
                          '${_formatNumber(totalBlockWithCycle)} / ${_formatNumber(stats.targetCount)}',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
    double parentWidth, {
    String? subtitle,
  }) {
    // Calculate card width: 4 per row on wide, 2 per row on mobile
    final int perRow = isMobile ? 2 : 4;
    final double spacing = 12.0 * (perRow - 1);
    final double cardWidth =
        ((parentWidth - spacing) / perRow).clamp(100.0, 250.0);

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...
              [
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  void _showDowntimeReasonDialog(BuildContext context, CompanyProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? selectedReason = 'Regular downtime';
        final descriptionController = TextEditingController();
        final durationController = TextEditingController(text: '15');
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final showDescField = selectedReason == 'Others';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.timer_off_outlined, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Reason For Downtime', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All machines are currently inactive. Please log the downtime reason below:',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          labelText: 'Reason Category *',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          'Mould problem',
                          'Regular downtime',
                          'Power cut',
                          'Mechanical breakdown',
                          'Electrical fault',
                          'Raw material shortage',
                          'Others',
                        ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) => setDialogState(() => selectedReason = val),
                      ),
                      const SizedBox(height: 16),
                      if (showDescField) ...[
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Downtime Description *',
                            hintText: 'Describe the specific reason for downtime...',
                            prefixIcon: const Icon(Icons.description_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (minutes) *',
                          hintText: 'Enter estimated duration in minutes',
                          prefixIcon: const Icon(Icons.hourglass_empty),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Submit'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = selectedReason ?? 'Regular downtime';
                          final desc = descriptionController.text.trim();
                          final durationVal = int.tryParse(durationController.text.trim()) ?? 15;

                          if (reason == 'Others' && desc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Description is required for "Others" option.')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final bridge = OpcBridgeService();
                            await bridge.submitDowntimeReason(
                              reason: reason,
                              description: desc.isNotEmpty ? desc : 'Downtime category: $reason',
                              duration: durationVal,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Downtime reason logged successfully.'), backgroundColor: Colors.green),
                              );
                              provider.refreshData();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isDialogOpen = false;
    });
  }
}
