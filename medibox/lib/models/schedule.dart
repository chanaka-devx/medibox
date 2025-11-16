/// Schedule model representing pill dispensing times
/// 
/// Each device has three time slots for medication:
/// - Morning (e.g., 08:00)
/// - Afternoon (e.g., 13:00)  
/// - Night (e.g., 20:00)
class Schedule {
  final String morning;
  final String afternoon;
  final String night;

  Schedule({
    required this.morning,
    required this.afternoon,
    required this.night,
  });

  /// Create Schedule from Firebase JSON data
  factory Schedule.fromJson(Map<dynamic, dynamic> json) {
    return Schedule(
      morning: json['morning'] as String? ?? '08:00',
      afternoon: json['afternoon'] as String? ?? '13:00',
      night: json['night'] as String? ?? '20:00',
    );
  }

  /// Convert Schedule to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'morning': morning,
      'afternoon': afternoon,
      'night': night,
    };
  }

  /// Create a copy of Schedule with optional field updates
  Schedule copyWith({
    String? morning,
    String? afternoon,
    String? night,
  }) {
    return Schedule(
      morning: morning ?? this.morning,
      afternoon: afternoon ?? this.afternoon,
      night: night ?? this.night,
    );
  }

  /// Get all time slots as a list
  List<String> getAllTimes() {
    return [morning, afternoon, night];
  }

  /// Get next scheduled time from current time
  String? getNextScheduledTime(DateTime currentTime) {
    final times = getAllTimes();
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    for (var timeStr in times) {
      final parts = timeStr.split(':');
      final scheduleMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      
      if (scheduleMinutes > currentMinutes) {
        return timeStr;
      }
    }

    // If no time left today, return tomorrow's morning time
    return times.first;
  }
}
