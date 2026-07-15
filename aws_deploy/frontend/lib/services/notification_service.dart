import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';

/// NotificationService handles local push notifications for alerts.
/// Shows notifications when critical machine events occur.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific screen
    // Payload contains the alert ID for future navigation implementation
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Show a notification for an alert
  Future<void> showAlertNotification(Alert alert) async {
    if (!_isInitialized) await initialize();

    // Determine notification priority based on severity
    final importance = _getImportance(alert.severity);
    final priority = _getPriority(alert.severity);

    final androidDetails = AndroidNotificationDetails(
      'machine_alerts',
      'Machine Alerts',
      channelDescription: 'Notifications for industrial machine alerts',
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      color: _getColor(alert.severity),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alert.id.hashCode, // Use alert ID hash as notification ID
      alert.typeName,
      '${alert.machineName}: ${alert.message}',
      details,
      payload: alert.id,
    );
  }

  /// Show a quick notification with custom title and body
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'general',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Get Android importance level based on alert severity
  Importance _getImportance(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Importance.max;
      case AlertSeverity.high:
        return Importance.high;
      case AlertSeverity.medium:
        return Importance.defaultImportance;
      case AlertSeverity.low:
        return Importance.low;
    }
  }

  /// Get Android priority level based on alert severity
  Priority _getPriority(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Priority.max;
      case AlertSeverity.high:
        return Priority.high;
      case AlertSeverity.medium:
        return Priority.defaultPriority;
      case AlertSeverity.low:
        return Priority.low;
    }
  }

  /// Get notification color based on severity
  Color _getColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFD32F2F); // Red
      case AlertSeverity.high:
        return const Color(0xFFF57C00); // Orange
      case AlertSeverity.medium:
        return const Color(0xFFFBC02D); // Yellow
      case AlertSeverity.low:
        return const Color(0xFF388E3C); // Green
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
