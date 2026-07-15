import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._(); // prevent instantiation

  // ────────────────────────────────────────────────────────────────────
  //  Dynamic URL Resolution
  // ────────────────────────────────────────────────────────────────────
  static String get bridgeBaseUrl {
    if (_overrideUrl != null && _overrideUrl!.isNotEmpty) {
      return _overrideUrl!;
    }
    if (kIsWeb) {
      // If loaded via browser (e.g. via tunnel), use the current browser URL
      return Uri.base.origin;
    }
    return 'http://192.168.0.101:3001';
  }
  
  static String? _overrideUrl;
  static set overrideUrl(String url) => _overrideUrl = url;

  static String get baseUrl => bridgeBaseUrl;
  // ────────────────────────────────────────────────────────────────────

  static const Duration pollInterval = Duration(milliseconds: 250);
  static const Duration requestTimeout = Duration(seconds: 8);

  static String get dataEndpoint => '$bridgeBaseUrl/api/data';
  static String get statusEndpoint => '$bridgeBaseUrl/api/status';
  static String get alertsEndpoint => '$bridgeBaseUrl/api/alerts';
  static String get rawEndpoint => '$bridgeBaseUrl/api/raw';
  static String get configEndpoint => '$bridgeBaseUrl/api/config';
  static String get reportsEndpoint => '$bridgeBaseUrl/api/reports';
  static String alertReadEndpoint(String id) => '$bridgeBaseUrl/api/alerts/$id/read';
  static String alertResolveEndpoint(String id) => '$bridgeBaseUrl/api/alerts/$id/resolve';
}
