import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

import '../services/opc_bridge_service.dart';
import '../services/api_config.dart';

export 'ticket_provider.dart';

/// AuthProvider handles user authentication state.
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _username;
  String? _errorMessage;
  String _userRole = 'client';
  String? _clientId;

  final OpcBridgeService _bridgeService = OpcBridgeService();

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get errorMessage => _errorMessage;
  String get userRole => _userRole;
  String? get clientId => _clientId;
  bool get isAdmin => _userRole == 'admin';
  OpcBridgeService get bridgeService => _bridgeService;

  /// Attempt to log in with provided credentials against the bridge server.
  Future<bool> login(String username, String password) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _bridgeService.login(username, password);
      if (result['success'] == true) {
        _isAuthenticated = true;
        _username = username;
        
        final user = result['user'];
        _userRole = user['role'] ?? 'client';
        _clientId = user['clientId'];
        
        // Setup token in bridge service
        _bridgeService.setToken(result['token']);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Log out the current user
  void logout() {
    _isAuthenticated = false;
    _username = null;
    _errorMessage = null;
    _userRole = 'client';
    _clientId = null;
    _bridgeService.setToken(null);
    notifyListeners();
  }

  /// Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// CompanyProvider manages the selected company state and all company-scoped data.
class CompanyProvider extends ChangeNotifier {
  final OpcBridgeService _bridgeService = OpcBridgeService();

  List<Company> _companies = [];
  Company? _selectedCompany;
  List<Machine> _machines = [];
  ProductionStats? _stats;
  List<Alert> _alerts = [];
  ProfileData? _profileData;
  ReportData? _reportData;

  bool _isLoading = false;
  bool _isPlcConnected = false;
  bool _isDataStale = false;
  String? _bridgeError;
  DateTime? _lastUpdated;
  Timer? _pollingTimer;
  Timer? _historyTimer;

  List<Company> get companies => _companies;
  Company? get selectedCompany => _selectedCompany;
  List<Machine> get machines => _machines;
  ProductionStats? get stats => _stats;
  List<Alert> get alerts => _alerts;
  List<Alert> get unreadAlerts => _alerts.where((a) => !a.isRead).toList();
  ProfileData? get profileData => _profileData;
  ReportData? get reportData => _reportData;
  bool get isLoading => _isLoading;
  bool get isPlcConnected => _isPlcConnected;
  bool get isDataStale => _isDataStale;
  String? get bridgeError => _bridgeError;
  DateTime? get lastUpdated => _lastUpdated;

  int get machinesRunning => _machines.where((m) => m.status == MachineStatus.running).length;
  int get machinesStopped => _machines.where((m) => m.status == MachineStatus.stopped).length;
  int get machinesInMaintenance => _machines.where((m) => m.status == MachineStatus.maintenance).length;
  int get unreadAlertCount => _alerts.where((a) => !a.isRead).length;

  Future<void> initialize({String? clientCompanyId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final configData = await _bridgeService.fetchConfig(companyId: clientCompanyId);
      final cMap = configData['company'] as Map<String, dynamic>? ?? {};

      _companies = [
        Company(
          id: cMap['id'] ?? clientCompanyId ?? 'bricks-001',
          name: cMap['name'] ?? 'SLV',
          industry: cMap['industry'] ?? 'Block Manufacturing',
          location: cMap['location'] ?? 'BM6 ECO',
          totalMachines: cMap['totalMachines'] ?? 13,
        )
      ];
      _selectedCompany = _companies.first;

      _profileData = ProfileData(
        userInfo: UserInfo(name: 'User', role: 'Staff'),
        companyInfo: CompanyProfileInfo(name: _selectedCompany!.name, location: _selectedCompany!.location, totalMachines: _selectedCompany!.totalMachines),
        simInfo: SimRechargeInfo(lastRechargeDate: DateTime.now(), planValidity: DateTime.now(), remainingDays: 0),
        usageStats: const UsageStats(totalAlerts: 0, monthlyDowntimeMinutes: 0, efficiencyPercent: 0),
      );

      await _fetchLiveData();
      
      _isLoading = false;
      notifyListeners();
      _startPolling();

      // Fetch history asynchronously in the background so it doesn't block loading
      fetchHistory();
    } catch (e) {
      debugPrint('Initialization error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(ApiConfig.pollInterval, (_) => _fetchLiveData());

    // Refresh chart/history data every 30 seconds
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 30), (_) => fetchHistory());
  }

  Future<void> _fetchLiveData() async {
    if (_selectedCompany == null) return;
    try {
      final result = await _bridgeService.fetchDashboardData(_selectedCompany!.id);
      _machines         = result['machines'] as List<Machine>? ?? _machines;
      _stats            = result['stats']    as ProductionStats? ?? _stats;
      _alerts           = result['alerts']   as List<Alert>? ?? [];
      _isPlcConnected   = result['plcConnected'] as bool? ?? false;
      _lastUpdated      = result['lastUpdated'] as DateTime?;
      _bridgeError      = null;
      _isDataStale      = false;  // ← clear stale flag on every successful response
    } catch (e) {
      _isPlcConnected = false;
      _isDataStale    = true;    // ← mark stale only when request fails
      _bridgeError    = e.toString();
    }
    notifyListeners();
  }

  Future<void> fetchHistory() async {
    if (_selectedCompany == null) return;
    try {
      final data = await _bridgeService.fetchReports(_selectedCompany!.id);
      _reportData = data.copyWith(companyName: _selectedCompany!.name);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
  }

  /// Update the list of available companies (used by Admin)
  void setCompanies(List<Company> list) {
    _companies = list;
    notifyListeners();
  }

  void selectCompanyById(String id) {
    if (_companies.isEmpty) return;
    _selectedCompany = _companies.firstWhere(
      (c) => c.id == id, 
      orElse: () => _companies.first
    );
    _profileData = ProfileData(
      userInfo: UserInfo(name: 'User', role: 'Staff'),
      companyInfo: CompanyProfileInfo(
        name: _selectedCompany!.name,
        location: _selectedCompany!.location,
        totalMachines: _selectedCompany!.totalMachines,
      ),
      simInfo: SimRechargeInfo(lastRechargeDate: DateTime.now(), planValidity: DateTime.now(), remainingDays: 0),
      usageStats: const UsageStats(totalAlerts: 0, monthlyDowntimeMinutes: 0, efficiencyPercent: 0),
    );
    _reportData = null;
    notifyListeners();
    _fetchLiveData();
    fetchHistory();
  }

  void refreshData() {
    _fetchLiveData();
    fetchHistory();
  }
  
  void markAlertAsRead(String id) {
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(isRead: true);
      notifyListeners();
      _bridgeService.markAlertRead(id);
    }
  }

  void markAllAlertsAsRead() {
    _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void markAlertAsResolved(String id) {
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(isRead: true, isResolved: true);
      notifyListeners();
      _bridgeService.resolveAlert(id);
    }
  }
  
  ReportData generateReport(DateTime start, DateTime end) {
    final base = _reportData;
    if (base == null) {
      return ReportData(
        companyId: _selectedCompany?.id ?? 'none',
        companyName: _selectedCompany?.name ?? 'N/A',
        startDate: start,
        endDate: end,
        totalProduction: 0,
        averageEfficiency: 0,
        totalDowntimeMinutes: 0,
        totalCycles: 0,
        dailyRecords: [],
      );
    }

    // Normalize start/end to midnight for inclusive date comparison
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay   = DateTime(end.year,   end.month,   end.day, 23, 59, 59);

    final filtered = base.dailyRecords
        .where((r) => !r.date.isBefore(startDay) && !r.date.isAfter(endDay))
        .toList();

    // Recompute totals from the filtered subset
    final totalProd   = filtered.fold(0.0, (s, r) => s + r.production);
    final totalCycles = filtered.fold(0,   (s, r) => s + r.cycles);
    final avgEff      = filtered.isEmpty ? 0.0
        : filtered.fold(0.0, (s, r) => s + r.efficiency) / filtered.length;

    return ReportData(
      companyId:            base.companyId,
      companyName:          base.companyName,
      startDate:            start,
      endDate:              end,
      dailyRecords:         filtered,
      totalProduction:      totalProd,
      averageEfficiency:    avgEff,
      totalDowntimeMinutes: filtered.fold(0, (s, r) => s + r.downtimeMinutes),
      totalCycles:          totalCycles,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _historyTimer?.cancel();
    super.dispose();
  }
}
