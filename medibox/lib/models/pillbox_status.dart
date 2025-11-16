/// Status model representing real-time pillbox device state
///
/// Tracks online status, last dispense time, and other operational data
class PillboxStatus {
  final bool online;
  final String? lastDispensed;
  final String? lastSyncTime;
  final int? batteryLevel; // Optional: battery percentage (0-100)

  PillboxStatus({
    required this.online,
    this.lastDispensed,
    this.lastSyncTime,
    this.batteryLevel,
  });

  /// Create PillboxStatus from Firebase JSON data
  factory PillboxStatus.fromJson(Map<dynamic, dynamic> json) {
    return PillboxStatus(
      online: json['online'] as bool? ?? false,
      lastDispensed: json['lastDispensed'] as String?,
      lastSyncTime: json['lastSyncTime'] as String?,
      batteryLevel: json['batteryLevel'] as int?,
    );
  }

  /// Convert PillboxStatus to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'online': online,
      if (lastDispensed != null) 'lastDispensed': lastDispensed,
      if (lastSyncTime != null) 'lastSyncTime': lastSyncTime,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
    };
  }

  /// Create a copy of PillboxStatus with optional field updates
  PillboxStatus copyWith({
    bool? online,
    String? lastDispensed,
    String? lastSyncTime,
    int? batteryLevel,
  }) {
    return PillboxStatus(
      online: online ?? this.online,
      lastDispensed: lastDispensed ?? this.lastDispensed,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  /// Check if device is recently online (within last 5 minutes)
  bool isRecentlyOnline() {
    if (!online || lastSyncTime == null) return false;
    
    try {
      final syncTime = DateTime.parse(lastSyncTime!);
      final now = DateTime.now();
      final difference = now.difference(syncTime);
      
      return difference.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  /// Get battery status description
  String getBatteryStatus() {
    if (batteryLevel == null) return 'Unknown';
    if (batteryLevel! > 50) return 'Good';
    if (batteryLevel! > 20) return 'Low';
    return 'Critical';
  }
}
