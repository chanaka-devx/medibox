/// Alert model representing pillbox alerts and notifications
///
/// Tracks missed doses, device offline status, and other alerts
class Alert {
  final bool missedDose;
  final String? missedDoseTime;
  final bool deviceOffline;
  final bool lowBattery;
  final String? message;
  final DateTime? timestamp;

  Alert({
    this.missedDose = false,
    this.missedDoseTime,
    this.deviceOffline = false,
    this.lowBattery = false,
    this.message,
    this.timestamp,
  });

  /// Create Alert from Firebase JSON data
  factory Alert.fromJson(Map<dynamic, dynamic> json) {
    return Alert(
      missedDose: json['missedDose'] as bool? ?? false,
      missedDoseTime: json['missedDoseTime'] as String?,
      deviceOffline: json['deviceOffline'] as bool? ?? false,
      lowBattery: json['lowBattery'] as bool? ?? false,
      message: json['message'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  /// Convert Alert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'missedDose': missedDose,
      if (missedDoseTime != null) 'missedDoseTime': missedDoseTime,
      'deviceOffline': deviceOffline,
      'lowBattery': lowBattery,
      if (message != null) 'message': message,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  /// Create a copy of Alert with optional field updates
  Alert copyWith({
    bool? missedDose,
    String? missedDoseTime,
    bool? deviceOffline,
    bool? lowBattery,
    String? message,
    DateTime? timestamp,
  }) {
    return Alert(
      missedDose: missedDose ?? this.missedDose,
      missedDoseTime: missedDoseTime ?? this.missedDoseTime,
      deviceOffline: deviceOffline ?? this.deviceOffline,
      lowBattery: lowBattery ?? this.lowBattery,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Check if there are any active alerts
  bool hasActiveAlerts() {
    return missedDose || deviceOffline || lowBattery;
  }

  /// Get priority level (1-3, where 3 is highest)
  int getPriority() {
    if (missedDose) return 3;
    if (deviceOffline) return 2;
    if (lowBattery) return 1;
    return 0;
  }

  /// Get user-friendly alert description
  String getDescription() {
    if (missedDose && missedDoseTime != null) {
      return 'Missed dose at $missedDoseTime';
    } else if (missedDose) {
      return 'Missed medication dose';
    } else if (deviceOffline) {
      return 'Device is offline';
    } else if (lowBattery) {
      return 'Device battery is low';
    } else if (message != null) {
      return message!;
    }
    return 'No alerts';
  }
}
