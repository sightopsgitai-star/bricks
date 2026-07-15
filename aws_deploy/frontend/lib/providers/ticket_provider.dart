import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/opc_bridge_service.dart';

/// TicketProvider manages the support ticket lifecycle.
class TicketProvider extends ChangeNotifier {
  final OpcBridgeService _bridgeService = OpcBridgeService();

  List<SupportTicket> _tickets = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  List<SupportTicket> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get openTicketCount => _tickets.where((t) => t.isOpen).length;
  int get inProgressTicketCount => _tickets.where((t) => t.isAcknowledged).length;

  TicketProvider() {
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchTickets(silent: true));
  }

  Future<void> fetchTickets({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _tickets = await _bridgeService.fetchTickets();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTicket(String title, String description) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _bridgeService.createTicket(title, description);
      await fetchTickets(silent: true);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgeTicket(int ticketId) async {
    try {
      await _bridgeService.acknowledgeTicket(ticketId);
      await fetchTickets(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resolveTicket(int ticketId) async {
    try {
      await _bridgeService.resolveTicket(ticketId);
      await fetchTickets(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
