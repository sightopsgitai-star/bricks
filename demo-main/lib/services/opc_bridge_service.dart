import 'dart:convert';
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_config.dart';

/// OpcBridgeService
/// Fetches real-time machine data from the Node.js OPC-UA bridge server.
class OpcBridgeService {
  // Singleton
  static final OpcBridgeService _instance = OpcBridgeService._internal();
  factory OpcBridgeService() => _instance;
  OpcBridgeService._internal();

  final http.Client _client = http.Client();
  String? _token;
  String? get token => _token;

  void setToken(String? token) {
    _token = token;
    if (kDebugMode) print('[BRIDGE] Token set: ${token != null ? "YES" : "NO"}');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return data;
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Login failed';
        throw Exception(error);
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Dashboard Data ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchDashboardData(String companyId) async {
    final uri = Uri.parse('${ApiConfig.dataEndpoint}?company=$companyId');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final adminOverrides = (json['adminOverrides'] as Map<String, dynamic>? ?? {});
      final machines = _parseMachines(
        json['machines'] as List<dynamic>? ?? [],
        adminOverrides,
      );
      final stats = _parseStats(
        json['stats']      as Map<String, dynamic>? ?? {},
        json['energyData'] as Map<String, dynamic>? ?? {},
        machines,
      );

      final alerts = _parseAlerts(json['alerts'] as List<dynamic>? ?? []);

      return {
        'machines': machines,
        'stats': stats,
        'alerts': alerts,
        'plcConnected': json['plcConnected'] as bool? ?? false,
        'lastUpdated': DateTime.now(),
      };
    } else {
      throw Exception('Failed to fetch data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchConfig({String? companyId}) async {
    try {
      final query = companyId != null ? '?company=$companyId' : '';
      final response = await _client.get(
        Uri.parse('${ApiConfig.configEndpoint}$query'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }


  // ── Reports ─────────────────────────────────────────────────────────────────

  /// Fetches historical production data from the /api/reports endpoint.
  /// Returns a [ReportData] object populated from the DB records.
  Future<ReportData> fetchReports(String companyId) async {
    try {
      final uri = Uri.parse('${ApiConfig.reportsEndpoint}?company=$companyId');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final body    = jsonDecode(response.body) as Map<String, dynamic>;
        final records = body['data'] as List<dynamic>? ?? [];
        final summary = body['summary'] as Map<String, dynamic>? ?? {};

        final dailyRecords = records.map((r) => _parseDailyRecord(r)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return ReportData(
          companyId:            companyId,
          companyName:          'SLV',
          // Now dailyRecords is sorted oldest-to-newest, so first is earliest, last is latest
          startDate:            dailyRecords.isNotEmpty ? dailyRecords.first.date : DateTime.now(),
          endDate:              dailyRecords.isNotEmpty ? dailyRecords.last.date  : DateTime.now(),
          dailyRecords:         dailyRecords,
          totalProduction:      (summary['totalProduction']      ?? 0).toDouble(),
          averageEfficiency:    (summary['averageEfficiency']    ?? 0).toDouble(),
          totalDowntimeMinutes: (summary['totalDowntimeMinutes'] ?? 0) as int,
          totalCycles:          (summary['totalCycles']          ?? 0) as int,
        );
      } else {
        if (kDebugMode) print('[BRIDGE] Reports fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('[BRIDGE] Error fetching reports: $e');
    }

    // Graceful fallback: return empty ReportData
    return ReportData(
      companyId: companyId,
      companyName: 'N/A',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      totalProduction: 0,
      averageEfficiency: 0,
      totalDowntimeMinutes: 0,
      totalCycles: 0,
      dailyRecords: [],
    );
  }

  // ── Admin Data ─────────────────────────────────────────────────────────────

  Future<List<Company>> fetchClients() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/clients'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as List<dynamic>;
        if (kDebugMode) print('[BRIDGE] Fetched ${data.length} clients');

        return data.map((c) => Company(
          id:            c['id'].toString(),
          name:          c['name'].toString(),
          industry:      'Industrial',
          location:      (c['location'] ?? 'Factory').toString(),
          totalMachines: 10,
          isOnline:      c['isOnline'] as bool? ?? false,
          latestDowntimeReason: c['latest_downtime_reason']?.toString(),
          latestDowntimeDescription: c['latest_downtime_description']?.toString(),
          lastSeenDate:  c['last_seen_date'] != null
            ? () {
                try {
                  final s = c['last_seen_date'].toString();
                  final parts = s.split('T')[0].split('-');
                  if (parts.length == 3) {
                    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                  }
                  return DateTime.tryParse(s)?.toLocal();
                } catch (_) {
                  return null;
                }
              }()
            : null,
        )).toList();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('[BRIDGE] Error fetching clients: $e');
      rethrow;
    }
  }

  /// Creates a new client with generated password (admin only).
  Future<Map<String, dynamic>> addClient(String name, String email, List<String> machines) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/clients'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'machines': machines}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create client: ${response.statusCode}');
  }

  /// Removes a client and all their data (admin only).
  Future<void> removeClient(String clientId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/clients/$clientId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove client: ${response.statusCode}');
    }
  }

  /// Fetches all client usernames and passwords (admin only).
  Future<List<Map<String, dynamic>>> fetchClientPasswords() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/passwords'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch passwords');
  }

  /// Fetches all password reset requests (admin only).
  Future<List<Map<String, dynamic>>> fetchPasswordResetRequests() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/password-resets'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch reset requests');
  }

  /// Sends a forgot password request (public, no auth needed).
  Future<void> forgotPassword(String username) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send request');
    }
  }

  // ── Machine Control (Admin) ────────────────────────────────────────────────

  /// Fetches all admin machine overrides for a client.
  /// Returns a map of { machineId: enabled }.
  Future<Map<String, bool>> getMachineOverrides(String clientId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/machine-control/$clientId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v as bool? ?? true));
    }
    throw Exception('Failed to fetch machine overrides');
  }

  /// Sets an admin override for a machine of a specific client.
  /// [enabled] = false → admin locks machine OFF; client cannot enable it.
  Future<void> setMachineOverride(String clientId, String machineId, bool enabled) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/machine-control'),
      headers: _headers,
      body: jsonEncode({'clientId': clientId, 'machineId': machineId, 'enabled': enabled}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set machine override: ${response.statusCode}');
    }
  }

  /// Client control: toggles a machine ON or OFF (if not admin disabled).
  Future<void> toggleMachineClient(String machineId, bool enabled) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/client/machine-control'),
      headers: _headers,
      body: jsonEncode({'machineId': machineId, 'enabled': enabled}),
    );
    if (response.statusCode != 200) {
      final msg = jsonDecode(response.body)['message'] ?? 'Failed to toggle machine';
      throw Exception(msg);
    }
  }

  // ── Support Tickets ───────────────────────────────────────────────────────

  Future<List<SupportTicket>> fetchTickets() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/tickets'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as List<dynamic>;
      return data.map((t) => SupportTicket.fromJson(t)).toList();
    } else {
      throw Exception('Failed to fetch tickets');
    }
  }

  Future<SupportTicket> createTicket(String title, String description) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/tickets'),
      headers: _headers,
      body: jsonEncode({'title': title, 'description': description}),
    );

    if (response.statusCode == 200) {
      return SupportTicket.fromJson(jsonDecode(response.body)['data']);
    } else {
      throw Exception('Failed to create ticket');
    }
  }

  Future<SupportTicket> acknowledgeTicket(int ticketId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/tickets/$ticketId/acknowledge'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return SupportTicket.fromJson(jsonDecode(response.body)['data']);
    } else {
      throw Exception('Failed to acknowledge ticket');
    }
  }

  Future<SupportTicket> resolveTicket(int ticketId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/tickets/$ticketId/resolve'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return SupportTicket.fromJson(jsonDecode(response.body)['data']);
    } else {
      throw Exception('Failed to resolve ticket');
    }
  }

  // ── Parsers ────────────────────────────────────────────────────────────────

  List<Machine> _parseMachines(List<dynamic> raw, [Map<String, dynamic> adminOverrides = const {}]) =>
      raw.map((m) => _parseMachine(m, adminOverrides)).toList();

  Machine _parseMachine(Map<String, dynamic> m, [Map<String, dynamic> adminOverrides = const {}]) {
    final machineId     = m['id']?.toString() ?? 'unknown';
    final overrideValue = adminOverrides[machineId];
    // adminDisabled: true if admin explicitly set enabled=false in DB override
    final adminDisabled = m['adminDisabled'] as bool? ??
        (overrideValue != null ? !(overrideValue as bool) : false);

    return Machine(
      id:              machineId,
      name:            m['name']        ?? 'Unknown',
      type:            m['type']        ?? 'Unknown',
      companyId:       m['companyId']   ?? 'unknown',
      status:          m['status'] == 'running' ? MachineStatus.running : MachineStatus.stopped,
      cycleCount:      m['cycleCount']  ?? 0,
      cureCycleTime:   (m['cureCycleTime']  ?? 0).toDouble(),
      downtimeMinutes: m['downtimeMinutes'] ?? 0,
      startCount:      m['startCount']  ?? 0,
      stopCount:       m['stopCount']   ?? 0,
      lastMaintenance: DateTime.now(),
      temperature:     (m['temperature'] ?? 0).toDouble(),
      efficiency:      (m['efficiency']  ?? 0).toDouble(),
      motorCurrent:    m['motorCurrent']  != null ? (m['motorCurrent']  as num).toDouble() : null,
      motorSpeedRpm:   m['motorSpeedRpm'] != null ? (m['motorSpeedRpm'] as num).toDouble() : null,
      adminDisabled:   adminDisabled,
      vfdFault:        m['vfdFault']  as bool? ?? false,
      runBit:          m['runBit']    as bool?,
    );
  }

  ProductionStats _parseStats(
    Map<String, dynamic> s,
    Map<String, dynamic> energyJson,
    List<Machine> machines,
  ) {
    return ProductionStats(
      companyId:            s['companyId']           ?? 'unknown',
      dailyProduction:      (s['dailyProduction']    ?? 0).toDouble(),
      weeklyProduction:     (s['weeklyProduction']   ?? 0).toDouble(),
      monthlyProduction:    (s['monthlyProduction']  ?? 0).toDouble(),
      yearlyProduction:     (s['yearlyProduction']   ?? 0).toDouble(),
      totalCycles:          s['totalCycles']         ?? 0,
      todayCycles:          s['todayCycles']         ?? 0,
      averageCureCycleTime: (s['averageCureCycleTime'] ?? 0).toDouble(),
      currentCycleTimeMs:   s['currentCycleTimeMs']  ?? 0,
      lastCycleTimeMs:      s['lastCycleTimeMs']     ?? 0,
      activeRecipeName:     s['activeRecipeName']?.toString() ?? '',
      blockName:            s['blockName']?.toString()        ?? '',
      actualCount:          s['actualCount']         ?? 0,
      targetCount:          s['targetCount']         ?? 5000,
      hourlyBreakdown:      s['hourlyBreakdown']     ?? {},
      concurrentCalls:      0,
      totalDowntimeMinutes: s['totalDowntimeMinutes'] ?? 0,
      machinesRunning:      machines.where((m) => m.status == MachineStatus.running).length,
      machinesStopped:      machines.where((m) => m.status == MachineStatus.stopped).length,
      machinesInMaintenance: 0,
      overallEfficiency:    (s['overallEfficiency']  ?? 0).toDouble(),
      lastUpdated:          DateTime.now(),
      rawTags:              _parseRawTags(s['rawSensors'] as Map<String, dynamic>? ?? {}),
      energy:               energyJson.isNotEmpty
                              ? EnergyData.fromJson(energyJson)
                              : EnergyData(
                                  overallPowerKw: (s['overallPowerKw'] as num? ?? 0).toDouble(),
                                  kwh:            (s['totalEnergyKwh']  as num? ?? 0).toDouble(),
                                  amps:           (s['overallAmps']     as num? ?? 0).toDouble(),
                                  pf:             (s['powerFactor']     as num? ?? 0).toDouble(),
                                  hz:             (s['frequency']       as num? ?? 0).toDouble(),
                                ),
      todayEnergyHistory: (s['todayEnergyHistory'] as List<dynamic>? ?? [])
          .map((item) => EnergyHistoryPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      yesterdayEnergyHistory: (s['yesterdayEnergyHistory'] as List<dynamic>? ?? [])
          .map((item) => EnergyHistoryPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  List<RawTag> _parseRawTags(Map<String, dynamic> sensors) {
    return sensors.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return RawTag(
        key:   e.key,
        label: v['label']?.toString() ?? e.key,
        value: v['value'] ?? 0,
        unit:  v['unit']?.toString()  ?? '',
      );
    }).toList();
  }

  DailyProductionRecord _parseDailyRecord(dynamic r) {
    DateTime date;
    try {
      final s = r['date'].toString();
      final parts = s.split('-');
      if (parts.length == 3) {
        date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } else {
        date = DateTime.parse(s).toLocal();
      }
    } catch (_) {
      date = DateTime.now();
    }
    return DailyProductionRecord(
      date:            date,
      production:      (r['production'] ?? 0).toDouble(),
      cycles:          r['cycles']      ?? 0,
      blockCount:      r['blockCount']  ?? 0,
      downtimeMinutes: r['downtime']    ?? 0,
      efficiency:      (r['efficiency'] ?? 0).toDouble(),
      activeMachines:  r['machines']    ?? 0,
      hourlyBreakdown: r['hourly']      is Map ? Map<String, dynamic>.from(r['hourly']) : {},
    );
  }

  /// Parse server-side alerts from the /api/data response.
  List<Alert> _parseAlerts(List<dynamic> raw) {
    return raw.map((a) {
      return Alert(
        id:          a['id']?.toString()          ?? Random().nextInt(999999).toString(),
        companyId:   a['companyId']?.toString()   ?? '',
        machineId:   a['machineId']?.toString()   ?? '',
        machineName: a['machineName']?.toString() ?? 'Unknown Machine',
        type:        _parseAlertType(a['type']?.toString()),
        severity:    _parseAlertSeverity(a['severity']?.toString()),
        message:     a['message']?.toString()     ?? '',
        timestamp:   a['timestamp'] != null
          ? DateTime.tryParse(a['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
        isRead:      a['isRead']     as bool? ?? false,
        isResolved:  a['isResolved'] as bool? ?? false,
      );
    }).toList();
  }

  AlertType _parseAlertType(String? s) {
    switch (s) {
      case 'machineStopped':         return AlertType.machineStopped;
      case 'abnormalCondition':      return AlertType.abnormalCondition;
      case 'highDowntime':           return AlertType.highDowntime;
      case 'temperatureWarning':     return AlertType.temperatureWarning;
      case 'maintenanceDue':         return AlertType.maintenanceDue;
      case 'productionTargetMissed': return AlertType.productionTargetMissed;
      case 'lowEfficiency':          return AlertType.lowEfficiency;
      case 'emergencyTriggered':     return AlertType.emergencyTriggered;
      case 'vfdFault':               return AlertType.vfdFault;
      default:                       return AlertType.abnormalCondition;
    }
  }

  AlertSeverity _parseAlertSeverity(String? s) {
    switch (s) {
      case 'critical': return AlertSeverity.critical;
      case 'high':     return AlertSeverity.high;
      case 'medium':   return AlertSeverity.medium;
      default:         return AlertSeverity.low;
    }
  }

  Future<void> submitDowntimeReason({
    required String reason,
    required String description,
    required int duration,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/downtime'),
      headers: _headers,
      body: jsonEncode({
        'reason': reason,
        'description': description,
        'duration': duration,
      }),
    );

    if (response.statusCode != 200) {
      final msg = jsonDecode(response.body)['message'] ?? 'Failed to submit downtime reason';
      throw Exception(msg);
    }
  }

  void markAlertRead(String id) {}
  void resolveAlert(String id) {}
  void dispose() => _client.close();
}

