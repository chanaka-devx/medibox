/// Notification item model for storing notification history
///
/// Stores details about pill-taking events with timestamps
class NotificationItem {
  final String id;
  final String deviceId;
  final String deviceNickname;
  final String title;
  final String message;
  final String timestamp;
  final String type; // 'pill_taken', 'missed_dose', 'device_offline'
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.deviceId,
    required this.deviceNickname,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  /// Create NotificationItem from Firebase JSON data
  factory NotificationItem.fromJson(String id, Map<dynamic, dynamic> json) {
    return NotificationItem(
      id: id,
      deviceId: json['deviceId'] as String? ?? '',
      deviceNickname: json['deviceNickname'] as String? ?? 'Unknown Device',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      type: json['type'] as String? ?? 'pill_taken',
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Convert NotificationItem to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceNickname': deviceNickname,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'isRead': isRead,
    };
  }

  /// Create a copy of NotificationItem with optional field updates
  NotificationItem copyWith({
    String? id,
    String? deviceId,
    String? deviceNickname,
    String? title,
    String? message,
    String? timestamp,
    String? type,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceNickname: deviceNickname ?? this.deviceNickname,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Get formatted time ago string
  String getTimeAgo() {
    try {
      final notificationTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(notificationTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  /// Get formatted timestamp
  String getFormattedTimestamp() {
    try {
      final notificationTime = DateTime.parse(timestamp);
      return '${notificationTime.year}-${notificationTime.month.toString().padLeft(2, '0')}-${notificationTime.day.toString().padLeft(2, '0')} '
             '${notificationTime.hour.toString().padLeft(2, '0')}:${notificationTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  /// Get icon based on notification type
  String getIcon() {
    switch (type) {
      case 'pill_taken':
        return '💊';
      case 'missed_dose':
        return '⚠️';
      case 'device_offline':
        return '📡';
      default:
        return '🔔';
    }
  }
}
