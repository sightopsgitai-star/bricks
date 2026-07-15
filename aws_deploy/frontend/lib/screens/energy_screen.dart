import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/responsive.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this, duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  double _zoomMinX = 8.0;
  double _zoomMaxX = 20.0;

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final stats = provider.stats;
        if (stats == null) return const Center(child: CircularProgressIndicator());
        final energy = stats.energy;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(provider, energy, isDark),
              const SizedBox(height: 20),

              // ── Live Power Hero Card ──────────────────────────────────────
              _buildLivePowerHero(energy, provider.isPlcConnected, isDark),
              const SizedBox(height: 20),

              // ── Summary Cards Row ─────────────────────────────────────────
              Responsive.isMobile(context)
                ? Column(children: _buildSummaryCards(energy, isDark).map((c) =>
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList())
                : Row(
                    children: _buildSummaryCards(energy, isDark).map((c) =>
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))
                    ).toList(),
                  ),

              const SizedBox(height: 20),

              // ── Phase Details Grid ────────────────────────────────────────
              _buildPhaseGrid(energy, isDark),
              const SizedBox(height: 20),

              // ── Per-Phase Power Factor Card ───────────────────────────────
              _buildPowerFactorCard(energy, isDark),
              const SizedBox(height: 20),

              // ── Energy Historical Charts ──────────────────────────────────
              _buildEnergyHistoricalCharts(stats, isDark),
              const SizedBox(height: 20),

              // ── Motor Currents Grid (live from rawTags) ───────────────────
              _buildMotorCurrentsGrid(provider, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(CompanyProvider provider, EnergyData energy, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Energy Monitoring',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                provider.isPlcConnected
                    ? 'Live data from PLC power analyser'
                    : 'Offline — showing last known values',
                style: TextStyle(
                  color: provider.isPlcConnected ? Colors.green : Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Frequency badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                energy.hz > 0 ? '${energy.hz.toStringAsFixed(2)} Hz' : '-- Hz',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const Text('Frequency', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivePowerHero(EnergyData energy, bool isLive, bool isDark) {
    final kw = energy.overallPowerKw;
    final hasData = kw > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLive
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF37474F), const Color(0xFF455A64)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isLive ? Colors.green : Colors.grey).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Live dot
          if (isLive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent
                      .withValues(alpha: 0.5 + 0.5 * _pulseController.value),
                  boxShadow: [BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.4 * _pulseController.value),
                    blurRadius: 8, spreadRadius: 2,
                  )],
                ),
              ),
            ),
          if (isLive) const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive ? 'LIVE POWER CONSUMPTION' : 'LAST KNOWN POWER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasData ? kw.toStringAsFixed(2) : '--',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('kW',
                          style: TextStyle(fontSize: 22, color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Energy: ${energy.kwh.toStringAsFixed(2)} kWh   •   '
                  'Overall Amps: ${energy.amps.toStringAsFixed(1)} A',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Power Factor
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      energy.pf > 0 ? energy.pf.toStringAsFixed(3) : '--',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('PF', style: TextStyle(fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _pfLabel(energy.pf),
                style: TextStyle(
                  color: _pfColor(energy.pf).withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pfLabel(double pf) {
    if (pf <= 0) return '---';
    if (pf >= 0.95) return 'Excellent';
    if (pf >= 0.90) return 'Good';
    if (pf >= 0.80) return 'Fair';
    return 'Poor';
  }

  Color _pfColor(double pf) {
    if (pf <= 0) return Colors.grey;
    if (pf >= 0.90) return Colors.greenAccent;
    if (pf >= 0.80) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  List<Widget> _buildSummaryCards(EnergyData e, bool isDark) {
    return [
      _buildMetricCard(
        'VOLTAGE AVG', e.voltageAvg > 0 ? '${e.voltageAvg.toStringAsFixed(1)} V' : '${e.llAvg.toStringAsFixed(1)} V',
        Icons.electric_bolt, Colors.amber[700]!, isDark,
        subtitle: 'Line-to-line avg',
      ),
      _buildMetricCard(
        'TOTAL ENERGY', '${e.kwh.toStringAsFixed(2)} kWh',
        Icons.battery_charging_full, Colors.blue, isDark,
        subtitle: 'Cumulative today',
      ),
      _buildMetricCard(
        'OVERALL AMPS', '${e.amps.toStringAsFixed(1)} A',
        Icons.bolt, Colors.deepOrange, isDark,
        subtitle: 'Phase avg current',
      ),
    ];
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isDark,
      {String? subtitle}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseGrid(EnergyData e, bool isDark) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.electric_bolt, size: 20, color: Colors.amber),
                SizedBox(width: 8),
                Text('Phase Voltages & Currents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Phase-to-neutral (L-N) and Phase-to-phase (L-L) readings',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            // Table header
            _buildPhaseRow('Phase', 'L-N Voltage', 'Current', 'header', e),
            const Divider(),
            _buildPhaseRow('L1', '${e.l1.toStringAsFixed(2)} V', '${e.l1Amps.toStringAsFixed(2)} A', 'l1', e),
            _buildPhaseRow('L2', '${e.l2.toStringAsFixed(2)} V', '${e.l2Amps.toStringAsFixed(2)} A', 'l2', e),
            _buildPhaseRow('L3', '${e.l3.toStringAsFixed(2)} V', '${e.l3Amps.toStringAsFixed(2)} A', 'l3', e),
            const Divider(height: 24),
            // L-L Voltages
            const Text('Line-to-Line Voltages',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Responsive.isMobile(context)
              ? Column(children: [
                  _buildLLChip('L12', e.l12),
                  const SizedBox(height: 8),
                  _buildLLChip('L23', e.l23),
                  const SizedBox(height: 8),
                  _buildLLChip('L31', e.l31),
                ])
              : Row(children: [
                  Expanded(child: _buildLLChip('L12', e.l12)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLLChip('L23', e.l23)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLLChip('L31', e.l31)),
                ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseRow(String phase, String voltage, String current, String type, EnergyData e) {
    if (type == 'header') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 40, child: Text(phase, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
            Expanded(child: Text(voltage, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
            SizedBox(width: 100, child: Text(current, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    final colors = {'l1': Colors.red.shade400, 'l2': Colors.yellow.shade700, 'l3': Colors.blue.shade400};
    final col = colors[type] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(child: Text(phase,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voltage, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(current,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: col)),
        ],
      ),
    );
  }

  Widget _buildLLChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo)),
          Text('${value.toStringAsFixed(2)} V',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPowerFactorCard(EnergyData e, bool isDark) {
    final phases = [
      {'label': 'L1 PF', 'value': e.l1Pf, 'color': Colors.red.shade400},
      {'label': 'L2 PF', 'value': e.l2Pf, 'color': Colors.amber.shade700},
      {'label': 'L3 PF', 'value': e.l3Pf, 'color': Colors.blue.shade400},
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, size: 20, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text('Power Factor Analytics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Per-phase power factor readings from PLC power meter',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            // Overall PF bar
            _buildPfBar('Overall', e.pf, Colors.green),
            const SizedBox(height: 12),
            ...phases.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPfBar(p['label'] as String, p['value'] as double, p['color'] as Color),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPfBar(String label, double pf, Color color) {
    final display = pf > 0 ? pf.toStringAsFixed(3) : '--';
    final fraction = pf.clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Stack(
            children: [
              Container(height: 20, decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              )),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(height: 20, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                  borderRadius: BorderRadius.circular(10),
                )),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 48, child: Text(display,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
      ],
    );
  }

  Widget _buildMotorCurrentsGrid(CompanyProvider provider, bool isDark) {
    final currents = provider.stats?.rawTags
        .where((t) => t.label.toLowerCase().contains('current'))
        .toList() ?? [];

    if (currents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.electric_meter, size: 20, color: Colors.teal),
            SizedBox(width: 8),
            Text('Real-time Motor Currents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Live PLC motor current readings (each ÷10 = actual Amperes)',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (context, index) {
            final tag  = currents[index];
            final val  = (tag.value as num? ?? 0).toDouble();
            final amps = val / 10.0; // PLC sends current × 10
            final color = amps > 25 ? Colors.red
                        : amps > 15 ? Colors.orange
                        : amps > 0  ? Colors.teal
                        : Colors.grey;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 8, offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(amps.toStringAsFixed(1),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('A', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnergyHistoricalCharts(ProductionStats stats, bool isDark) {
    List<EnergyHistoryPoint> today = stats.todayEnergyHistory;
    List<EnergyHistoryPoint> yesterday = stats.yesterdayEnergyHistory;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final charts = [
          _buildChartCard(
            title: 'Total Energy Consumption',
            subtitle: 'Hourly cumulative total energy consumption comparison',
            unit: ' kWh',
            todayData: today,
            yesterdayData: yesterday,
            valGetter: (p) => p.kwh,
            isDark: isDark,
            minY: null,
            maxY: null,
            maxYAuto: true,
          ),
          _buildChartCard(
            title: 'Overall Current (Amps)',
            subtitle: 'Hourly average overall current comparison',
            unit: ' A',
            todayData: today,
            yesterdayData: yesterday,
            valGetter: (p) => p.amps,
            isDark: isDark,
            minY: 0,
            maxY: null,
            maxYAuto: true,
          ),
          _buildChartCard(
            title: 'Power Factor Trend',
            subtitle: 'Hourly average power factor trend comparison',
            unit: '',
            todayData: today,
            yesterdayData: yesterday,
            valGetter: (p) => p.pf,
            isDark: isDark,
            minY: 0.0,
            maxY: 1.0,
            maxYAuto: false,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildZoomControlPanel(isDark),
            const SizedBox(height: 20),
            if (isMobile)
              Column(
                children: charts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: c,
                )).toList(),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: 20),
                      Expanded(child: charts[1]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: charts[2]),
                      const SizedBox(width: 20),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required String unit,
    required List<EnergyHistoryPoint> todayData,
    required List<EnergyHistoryPoint> yesterdayData,
    required double Function(EnergyHistoryPoint) valGetter,
    required bool isDark,
    double? minY,
    double? maxY,
    required bool maxYAuto,
  }) {
    // Build spots – filter zero/invalid values, then anchor at hour 8.0
    // so lines start at the left edge of the chart.
    List<FlSpot> _makeSpots(List<EnergyHistoryPoint> data) {
      final effectiveMinY = minY ?? 0;

      // Filter out zero values (they mean "no reading yet") and restrict to 8:00 AM to 8:00 PM (8.0 to 20.0)
      final raw = data
          .map((p) => FlSpot(p.hour.toDouble(), valGetter(p)))
          .where((s) => s.y > 0 && s.x >= 8.0 && s.x <= 20.0)          // skip hours with no data, restrict to 8-20
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));

      return raw;
    }

    final todaySpots     = _makeSpots(todayData);
    final yesterdaySpots = _makeSpots(yesterdayData);

    double resolvedMinY = minY ?? 0;
    double resolvedMaxY = maxY ?? 100;

    if (maxYAuto) {
      double maxVal = 0;
      double minVal = double.infinity;
      // Calculate dynamic Y bounds restricted to the currently zoomed horizontal window
      for (final s in todaySpots) {
        if (s.x >= _zoomMinX && s.x <= _zoomMaxX) {
          if (s.y > maxVal) maxVal = s.y;
          if (s.y < minVal) minVal = s.y;
        }
      }
      for (final s in yesterdaySpots) {
        if (s.x >= _zoomMinX && s.x <= _zoomMaxX) {
          if (s.y > maxVal) maxVal = s.y;
          if (s.y < minVal) minVal = s.y;
        }
      }
      // Fallback in case no points are visible in the zoom range
      if (maxVal == 0) {
        for (final s in todaySpots) {
          if (s.y > maxVal) maxVal = s.y;
          if (s.y < minVal) minVal = s.y;
        }
        for (final s in yesterdaySpots) {
          if (s.y > maxVal) maxVal = s.y;
          if (s.y < minVal) minVal = s.y;
        }
      }
      if (maxVal == 0) maxVal = 100;
      if (minVal == double.infinity) minVal = 0;

      resolvedMaxY = maxVal * 1.05;
      resolvedMinY = math.max(0.0, minVal * 0.95);
      
      if (resolvedMaxY == resolvedMinY) {
        resolvedMaxY += 10.0;
        resolvedMinY = math.max(0.0, resolvedMinY - 10.0);
      }
    }

    // Calculate dynamic X-axis vertical grid line & label intervals based on zoom range
    final double range = _zoomMaxX - _zoomMinX;
    double interval;
    if (range <= 0.5) {
      // 30 minutes or less: label every 5 minutes
      interval = 5 / 60; // 0.0833 hours
    } else if (range <= 1.0) {
      // 1 hour or less: label every 10 minutes
      interval = 10 / 60; // 0.1667 hours
    } else if (range <= 2.0) {
      // 2 hours or less: label every 15 minutes
      interval = 15 / 60; // 0.25 hours
    } else if (range <= 4.0) {
      // 4 hours or less: label every 30 minutes
      interval = 30 / 60; // 0.5 hours
    } else if (range <= 8.0) {
      // 8 hours or less: label every 1 hour
      interval = 1.0;
    } else {
      // Full range (12 hours): label every 2 hours
      interval = 2.0;
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.blueGrey.shade900;
    final subtitleColor = isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600;
    final gridLineColor = isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade200;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem('Today', Colors.red, isDark),
                    const SizedBox(width: 12),
                    _buildLegendItem('Yesterday', Colors.blue, isDark),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  if (todaySpots.isEmpty && yesterdaySpots.isEmpty)
                    const Center(
                      child: Text(
                        'No telemetry data available',
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    )
                  else
                    LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minX: _zoomMinX,
                        maxX: _zoomMaxX,
                        minY: resolvedMinY,
                        maxY: resolvedMaxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: (resolvedMaxY - resolvedMinY) / 4,
                          verticalInterval: interval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: gridLineColor,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: gridLineColor,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              interval: (resolvedMaxY - resolvedMinY) / 4,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                                String formatted = value.toStringAsFixed(unit == ' kWh' ? 2 : (value < 5 ? 2 : 0));
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '$formatted$unit',
                                    style: TextStyle(
                                      color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: interval,
                              getTitlesWidget: (value, meta) {
                                // Filter out labels outside current range
                                if (value < _zoomMinX - 0.01 || value > _zoomMaxX + 0.01) return const SizedBox.shrink();
                                
                                // Format value to exact HH:MM
                                final totalMins = (value * 60).round();
                                final hh = totalMins ~/ 60;
                                final mm = totalMins % 60;
                                
                                // Draw labels exactly at active interval increments
                                final intervalMins = (interval * 60).round();
                                if (totalMins % intervalMins != 0) return const SizedBox.shrink();
                                
                                final display = '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    display,
                                    style: TextStyle(
                                      color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => isDark ? const Color(0xFF0F172A) : Colors.blueGrey.shade900,
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((barSpot) {
                                final isToday = barSpot.barIndex == 0;
                                final color = isToday ? Colors.red.shade400 : Colors.blue.shade400;
                                final label = isToday ? 'Today' : 'Yesterday';
                                final valStr = barSpot.y.toStringAsFixed(unit == ' kWh' ? 2 : (barSpot.y < 5 ? 3 : 1));
                                // Convert fractional hour to HH:MM (e.g. 13.25 → 13:15)
                                final totalMins = (barSpot.x * 60).round();
                                final hh = (totalMins ~/ 60).toString().padLeft(2, '0');
                                final mm = (totalMins % 60).toString().padLeft(2, '0');
                                return LineTooltipItem(
                                  '$label $hh:$mm\n$valStr$unit',
                                  TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          // Today's Line (Red)
                          LineChartBarData(
                            spots: todaySpots,
                            isCurved: todaySpots.length >= 2,
                            curveSmoothness: 0.35,
                            preventCurveOverShooting: true,
                            color: Colors.redAccent,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 2.0,
                                  color: Colors.redAccent,
                                  strokeWidth: 1.0,
                                  strokeColor: Colors.white,
                                ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.redAccent.withValues(alpha: 0.08),
                            ),
                          ),
                          // Yesterday's Line (Blue)
                          LineChartBarData(
                            spots: yesterdaySpots,
                            isCurved: yesterdaySpots.length >= 2,
                            curveSmoothness: 0.35,
                            preventCurveOverShooting: true,
                            color: Colors.blueAccent,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 1.5,
                                  color: Colors.blueAccent,
                                  strokeWidth: 1.0,
                                  strokeColor: Colors.white,
                                ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blueAccent.withValues(alpha: 0.04),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // "No yesterday data" badge
                  if (todaySpots.isNotEmpty && yesterdaySpots.isEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 11, color: Colors.blueAccent.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'No yesterday data yet',
                              style: TextStyle(fontSize: 10, color: Colors.blueAccent.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControlPanel(bool isDark) {
    String formatTime(double hourFraction) {
      final totalMins = (hourFraction * 60).round();
      int hh = totalMins ~/ 60;
      final mm = totalMins % 60;
      final amPm = hh >= 12 ? 'PM' : 'AM';
      final displayHour = hh > 12 ? hh - 12 : (hh == 0 ? 12 : hh);
      return '${displayHour.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} $amPm';
    }

    final startStr = formatTime(_zoomMinX);
    final endStr = formatTime(_zoomMaxX);
    
    final totalMins = ((_zoomMaxX - _zoomMinX) * 60).round();
    final durationHours = totalMins ~/ 60;
    final durationMins = totalMins % 60;
    String durationStr = '';
    if (durationHours > 0 && durationMins > 0) {
      durationStr = '${durationHours}h ${durationMins}m';
    } else if (durationHours > 0) {
      durationStr = '${durationHours}h';
    } else {
      durationStr = '${durationMins}m';
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.blueGrey.shade900;
    final subtitleColor = isDark ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.zoom_in, color: Colors.indigo, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactive Time Zoom',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Slide handles to zoom into minutes; charts will automatically adapt intervals',
                        style: TextStyle(fontSize: 11, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.25)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.indigo.shade900),
                    children: [
                      TextSpan(text: '$startStr  —  $endStr'),
                      TextSpan(
                        text: '  ($durationStr)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.indigo,
                inactiveTrackColor: Colors.indigo.withValues(alpha: 0.15),
                thumbColor: Colors.indigo,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                overlayColor: Colors.indigo.withValues(alpha: 0.12),
                valueIndicatorColor: Colors.indigo,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, pressedElevation: 6),
              ),
              child: RangeSlider(
                values: RangeValues(_zoomMinX, _zoomMaxX),
                min: 8.0,
                max: 20.0,
                divisions: 720,
                labels: RangeLabels(
                  formatTime(_zoomMinX),
                  formatTime(_zoomMaxX),
                ),
                onChanged: (RangeValues values) {
                  double start = values.start;
                  double end = values.end;
                  if (end - start < 0.0833) {
                    if (start == _zoomMinX) {
                      start = (end - 0.0833).clamp(8.0, 20.0);
                    } else {
                      end = (start + 0.0833).clamp(8.0, 20.0);
                    }
                  }
                  setState(() {
                    _zoomMinX = start;
                    _zoomMaxX = end;
                  });
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton('Full Day', 8.0, 20.0, isDark),
                _buildPresetButton('Morning (8-12)', 8.0, 12.0, isDark),
                _buildPresetButton('Mid-day (12-4)', 12.0, 16.0, isDark),
                _buildPresetButton('Evening (4-8)', 16.0, 20.0, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, double minVal, double maxVal, bool isDark) {
    final isSelected = (_zoomMinX - minVal).abs() < 0.01 && (_zoomMaxX - maxVal).abs() < 0.01;
    final activeBg = Colors.indigo;
    final activeFg = Colors.white;
    final inactiveBg = isDark ? const Color(0xFF334155) : Colors.grey.shade100;
    final inactiveFg = isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? activeBg : inactiveBg,
        foregroundColor: isSelected ? activeFg : inactiveFg,
        side: isSelected ? const BorderSide(color: Colors.indigo) : BorderSide(color: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        setState(() {
          _zoomMinX = minVal;
          _zoomMaxX = maxVal;
        });
      },
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<EnergyHistoryPoint> _getMockYesterdayHistory() {
    final List<EnergyHistoryPoint> pts = [];
    double kwh = 2450.0;
    for (int h = 0; h < 24; h++) {
      final double angle = (h - 6) * 2 * math.pi / 24;
      final double sinVal = math.sin(angle);
      
      final double amps = 18.0 + 10.0 * sinVal + (h % 3) * 1.5;
      final double pfAngle = (h - 2) * 2 * math.pi / 24;
      final double pf = 0.85 + 0.08 * math.sin(pfAngle) + (h % 2) * 0.01;
      
      final double rate = 8.0 + 6.0 * sinVal;
      kwh += rate;
      
      pts.add(EnergyHistoryPoint(hour: h.toDouble(), kwh: kwh, amps: amps, pf: pf));
    }
    return pts;
  }

  List<EnergyHistoryPoint> _getMockTodayHistory(int currentHour) {
    final List<EnergyHistoryPoint> pts = [];
    double kwh = 2450.0;
    for (int h = 0; h <= currentHour; h++) {
      final double angle = (h - 6) * 2 * math.pi / 24;
      final double sinVal = math.sin(angle);
      
      final double amps = 19.5 + 11.0 * sinVal + (h % 4) * 1.0;
      final double pfAngle = (h - 2) * 2 * math.pi / 24;
      final double pf = 0.86 + 0.07 * math.sin(pfAngle) + (h % 3) * 0.01;
      
      final double rate = 9.0 + 7.0 * sinVal;
      kwh += rate;
      
      pts.add(EnergyHistoryPoint(hour: h.toDouble(), kwh: kwh, amps: amps, pf: pf));
    }
    return pts;
  }
}
