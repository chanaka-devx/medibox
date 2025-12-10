import 'schedule.dart';
import 'pillbox_status.dart';
import 'alert.dart';

/// Device model representing a smart pillbox device
///
/// Each device has a unique ID, nickname, schedule, status, and alerts
class Device {
  final String id; // Unique device identifier
  final String nickname; // User-friendly device name
  final String? guardianFcmToken; // FCM token for push notifications
  final Schedule schedule;
  final PillboxStatus status;
  final Alert? alerts;
  final DateTime? addedDate;

  Device({
    required this.id,
    required this.nickname,
    this.guardianFcmToken,
    required this.schedule,
    required this.status,
    this.alerts,
    this.addedDate,
  });

  /// Create Device from Firebase JSON data
  /// 
  /// Expected structure:
  /// ```
  /// {
  ///   "id": "DEVICE123",
  ///   "nickname": "Mom's Pillbox",
  ///   "schedule": { "morning": "08:00", ... },
  ///   "status": { "online": true, ... },
  ///   "alerts": { "missedDose": false, ... },
  ///   "addedDate": "2025-01-15T10:30:00Z"
  /// }
  /// ```
  factory Device.fromJson(String id, Map<dynamic, dynamic> json) {
    return Device(
      id: id,
      nickname: json['nickname'] as String? ?? 'Pillbox',
      guardianFcmToken: json['guardianFcmToken'] as String?,
      schedule: json['schedule'] != null
          ? Schedule.fromJson(json['schedule'] as Map<dynamic, dynamic>)
          : Schedule(morning: '08:00', afternoon: '13:00', night: '20:00'),
      status: json['status'] != null
          ? PillboxStatus.fromJson(json['status'] as Map<dynamic, dynamic>)
          : PillboxStatus(online: false),
      alerts: json['alerts'] != null
          ? Alert.fromJson(json['alerts'] as Map<dynamic, dynamic>)
          : null,
      addedDate: json['addedDate'] != null
          ? DateTime.parse(json['addedDate'] as String)
          : null,
    );
  }

  /// Convert Device to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      if (guardianFcmToken != null) 'guardianFcmToken': guardianFcmToken,
      'schedule': schedule.toJson(),
      'status': status.toJson(),
      if (alerts != null) 'alerts': alerts!.toJson(),
      if (addedDate != null) 'addedDate': addedDate!.toIso8601String(),
    };
  }

  /// Create a copy of Device with optional field updates
  Device copyWith({
    String? id,
    String? nickname,
    String? guardianFcmToken,
    Schedule? schedule,
    PillboxStatus? status,
    Alert? alerts,
    DateTime? addedDate,
  }) {
    return Device(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      guardianFcmToken: guardianFcmToken ?? this.guardianFcmToken,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      addedDate: addedDate ?? this.addedDate,
    );
  }

  /// Check if device has any active alerts
  bool hasActiveAlerts() {
    return alerts?.hasActiveAlerts() ?? false;
  }

  /// Get next scheduled medication time
  String? getNextScheduledTime() {
    return schedule.getNextScheduledTime(DateTime.now());
  }

  /// Check if device is operational (online and no critical alerts)
  bool isOperational() {
    return status.online && !hasActiveAlerts();
  }
}
