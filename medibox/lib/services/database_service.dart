import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../models/schedule.dart';
import '../models/pillbox_status.dart';
import '../models/alert.dart';

/// Database service for Firebase Realtime Database operations
///
/// Handles CRUD operations for devices, schedules, status, and alerts
/// All paths follow the structure:
/// - devices/{deviceId}/schedule
/// - devices/{deviceId}/status  
/// - devices/{deviceId}/alerts
/// - users/{userId}/devices: [deviceId1, deviceId2, ...]
class DatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Database references
  DatabaseReference get _devicesRef => _database.ref('devices');
  DatabaseReference get _usersRef => _database.ref('users');

  /// Link a device to a user account
  ///
  /// Adds the device ID to the user's device list
  /// Creates the device node if it doesn't exist
  Future<void> linkDeviceToUser({
    required String userId,
    required String deviceId,
    required String deviceNickname,
  }) async {
    try {
      // Add device ID to user's device list
      final userDevicesRef = _usersRef.child(userId).child('devices');
      
      // Get current devices
      final snapshot = await userDevicesRef.get();
      List<String> devices = [];
      
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is List) {
          devices = value.whereType<String>().toList();
        } else if (value is Map) {
          devices = value.values.whereType<String>().toList();
        }
      }
      
      // Add new device if not already present
      if (!devices.contains(deviceId)) {
        devices.add(deviceId);
        await userDevicesRef.set(devices);
      }

      // Initialize device node if it doesn't exist
      final deviceRef = _devicesRef.child(deviceId);
      final deviceSnapshot = await deviceRef.get();
      
      if (!deviceSnapshot.exists) {
        await deviceRef.set({
          'nickname': deviceNickname,
          'schedule': Schedule(
            morning: '08:00',
            afternoon: '13:00',
            night: '20:00',
          ).toJson(),
          'status': PillboxStatus(online: false).toJson(),
          'addedDate': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Failed to link device: $e');
    }
  }

  /// Unlink a device from a user account
  Future<void> unlinkDeviceFromUser({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final userDevicesRef = _usersRef.child(userId).child('devices');
      final snapshot = await userDevicesRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        List<String> devices = [];
        final value = snapshot.value;
        
        if (value is List) {
          devices = value.whereType<String>().toList();
        } else if (value is Map) {
          devices = value.values.whereType<String>().toList();
        }
        
        devices.remove(deviceId);
        await userDevicesRef.set(devices);
      }
    } catch (e) {
      throw Exception('Failed to unlink device: $e');
    }
  }

  /// Get list of device IDs for a user
  Future<List<String>> getUserDevices(String userId) async {
    try {
      final snapshot = await _usersRef.child(userId).child('devices').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final value = snapshot.value;
      if (value is List) {
        return value.whereType<String>().toList();
      } else if (value is Map) {
        return value.values.whereType<String>().toList();
      }
      
      return [];
    } catch (e) {
      throw Exception('Failed to get user devices: $e');
    }
  }

  /// Get a device by ID
  Future<Device?> getDevice(String deviceId) async {
    try {
      final snapshot = await _devicesRef.child(deviceId).get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return Device.fromJson(deviceId, snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      throw Exception('Failed to get device: $e');
    }
  }

  /// Stream of device data changes
  Stream<Device?> deviceStream(String deviceId) {
    return _devicesRef.child(deviceId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      return Device.fromJson(
        deviceId,
        event.snapshot.value as Map<dynamic, dynamic>,
      );
    });
  }

  /// Get all devices for a user
  Future<List<Device>> getAllUserDevices(String userId) async {
    try {
      final deviceIds = await getUserDevices(userId);
      final List<Device> devices = [];

      for (final deviceId in deviceIds) {
        final device = await getDevice(deviceId);
        if (device != null) {
          devices.add(device);
        }
      }

      return devices;
    } catch (e) {
      throw Exception('Failed to get all devices: $e');
    }
  }

  /// Update device nickname
  Future<void> updateDeviceNickname({
    required String deviceId,
    required String nickname,
  }) async {
    try {
      await _devicesRef.child(deviceId).child('nickname').set(nickname);
    } catch (e) {
      throw Exception('Failed to update device nickname: $e');
    }
  }

  /// Update device schedule
  Future<void> updateSchedule({
    required String deviceId,
    required Schedule schedule,
  }) async {
    try {
      await _devicesRef.child(deviceId).child('schedule').set(schedule.toJson());
    } catch (e) {
      throw Exception('Failed to update schedule: $e');
    }
  }

  /// Get device schedule
  Future<Schedule?> getSchedule(String deviceId) async {
    try {
      final snapshot = await _devicesRef.child(deviceId).child('schedule').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return Schedule.fromJson(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      throw Exception('Failed to get schedule: $e');
    }
  }

  /// Update device status (typically called by ESP32)
  Future<void> updateStatus({
    required String deviceId,
    required PillboxStatus status,
  }) async {
    try {
      await _devicesRef.child(deviceId).child('status').set(status.toJson());
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  /// Get device status
  Future<PillboxStatus?> getStatus(String deviceId) async {
    try {
      final snapshot = await _devicesRef.child(deviceId).child('status').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return PillboxStatus.fromJson(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      throw Exception('Failed to get status: $e');
    }
  }

  /// Stream of device status changes
  Stream<PillboxStatus?> statusStream(String deviceId) {
    return _devicesRef.child(deviceId).child('status').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      return PillboxStatus.fromJson(event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  /// Update device alerts
  Future<void> updateAlerts({
    required String deviceId,
    required Alert alerts,
  }) async {
    try {
      await _devicesRef.child(deviceId).child('alerts').set(alerts.toJson());
    } catch (e) {
      throw Exception('Failed to update alerts: $e');
    }
  }

  /// Clear all alerts for a device
  Future<void> clearAlerts(String deviceId) async {
    try {
      await _devicesRef.child(deviceId).child('alerts').remove();
    } catch (e) {
      throw Exception('Failed to clear alerts: $e');
    }
  }

  /// Get device alerts
  Future<Alert?> getAlerts(String deviceId) async {
    try {
      final snapshot = await _devicesRef.child(deviceId).child('alerts').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return Alert.fromJson(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      throw Exception('Failed to get alerts: $e');
    }
  }

  /// Stream of alert changes
  Stream<Alert?> alertsStream(String deviceId) {
    return _devicesRef.child(deviceId).child('alerts').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      return Alert.fromJson(event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  /// Trigger manual dispense (sets a flag for ESP32 to read)
  Future<void> triggerManualDispense({
    required String deviceId,
    required String compartment, // 'morning', 'afternoon', or 'night'
  }) async {
    try {
      await _devicesRef.child(deviceId).child('manualDispense').set({
        'compartment': compartment,
        'timestamp': DateTime.now().toIso8601String(),
        'triggered': true,
      });
    } catch (e) {
      throw Exception('Failed to trigger manual dispense: $e');
    }
  }

  /// Clear manual dispense flag (called by ESP32 after dispensing)
  Future<void> clearManualDispense(String deviceId) async {
    try {
      await _devicesRef.child(deviceId).child('manualDispense').remove();
    } catch (e) {
      throw Exception('Failed to clear manual dispense: $e');
    }
  }

  /// Silence alarm (sets a flag for ESP32 to read)
  Future<void> silenceAlarm(String deviceId) async {
    try {
      await _devicesRef.child(deviceId).child('silenceAlarm').set({
        'silenced': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Auto-clear after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _devicesRef.child(deviceId).child('silenceAlarm').remove();
      });
    } catch (e) {
      throw Exception('Failed to silence alarm: $e');
    }
  }

  /// Reset device schedule to defaults
  Future<void> resetSchedule(String deviceId) async {
    try {
      final defaultSchedule = Schedule(
        morning: '08:00',
        afternoon: '13:00',
        night: '20:00',
      );
      await updateSchedule(deviceId: deviceId, schedule: defaultSchedule);
    } catch (e) {
      throw Exception('Failed to reset schedule: $e');
    }
  }

  /// Check if device exists
  Future<bool> deviceExists(String deviceId) async {
    try {
      final snapshot = await _devicesRef.child(deviceId).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Save guardian's FCM token for push notifications
  Future<void> saveGuardianFcmToken({
    required String deviceId,
    required String fcmToken,
  }) async {
    try {
      await _devicesRef.child(deviceId).update({
        'guardianFcmToken': fcmToken,
      });
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }

  /// Save user's FCM token to their profile
  Future<void> saveUserFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      await _usersRef.child(userId).update({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save user FCM token: $e');
    }
  }

  /// Update FCM token for all user's devices
  Future<void> updateFcmTokenForAllDevices({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      final deviceIds = await getUserDevices(userId);
      for (final deviceId in deviceIds) {
        await saveGuardianFcmToken(deviceId: deviceId, fcmToken: fcmToken);
      }
    } catch (e) {
      throw Exception('Failed to update FCM tokens for devices: $e');
    }
  }

  /// Update FCM V1 API access token for all user's devices
  /// ESP32 needs this OAuth token to send notifications via FCM V1 API
  Future<void> updateFcmAccessTokenForAllDevices({
    required String userId,
    required String accessToken,
  }) async {
    try {
      final deviceIds = await getUserDevices(userId);
      for (final deviceId in deviceIds) {
        await _devicesRef.child(deviceId).update({
          'fcmAccessToken': accessToken,
          'fcmAccessTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Failed to update FCM access tokens for devices: $e');
    }
  }

  /// Stream of notification trigger changes
  Stream<Map<String, dynamic>?> notificationTriggerStream(String deviceId) {
    return _devicesRef.child(deviceId).child('notificationTrigger').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      final value = event.snapshot.value as Map<dynamic, dynamic>;
      return Map<String, dynamic>.from(value);
    });
  }

  /// Clear notification trigger after processing
  Future<void> clearNotificationTrigger(String deviceId) async {
    try {
      await _devicesRef.child(deviceId).child('notificationTrigger').remove();
    } catch (e) {
      throw Exception('Failed to clear notification trigger: $e');
    }
  }

  /// Stream of missed dose alerts
  Stream<Map<String, dynamic>?> missedDoseStream(String deviceId) {
    return _devicesRef.child(deviceId).child('missedDose').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      final value = event.snapshot.value as Map<dynamic, dynamic>;
      return Map<String, dynamic>.from(value);
    });
  }

  /// Save notification to user's notification history
  Future<void> saveNotification({
    required String userId,
    required String deviceId,
    required String deviceNickname,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final notificationRef = _usersRef.child(userId).child('notifications').push();
      await notificationRef.set({
        'deviceId': deviceId,
        'deviceNickname': deviceNickname,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'isRead': false,
      });
    } catch (e) {
      throw Exception('Failed to save notification: $e');
    }
  }

  /// Get all notifications for a user
  Future<List<dynamic>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _usersRef.child(userId).child('notifications').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final notificationsMap = snapshot.value as Map<dynamic, dynamic>;
      final List<dynamic> notifications = [];

      notificationsMap.forEach((key, value) {
        final notification = Map<String, dynamic>.from({
          'id': key,
          ...Map<String, dynamic>.from(value as Map),
        });
        notifications.add(notification);
      });

      // Sort by timestamp, newest first
      notifications.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] as String);
        final bTime = DateTime.parse(b['timestamp'] as String);
        return bTime.compareTo(aTime);
      });

      return notifications.map((n) {
        return {
          'id': n['id'],
          'deviceId': n['deviceId'],
          'deviceNickname': n['deviceNickname'],
          'title': n['title'],
          'message': n['message'],
          'timestamp': n['timestamp'],
          'type': n['type'],
          'isRead': n['isRead'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _usersRef.child(userId).child('notifications').child(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      await _usersRef.child(userId).child('notifications').remove();
    } catch (e) {
      throw Exception('Failed to clear notifications: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _usersRef.child(userId).child('notifications').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }

      final notificationsMap = snapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      notificationsMap.forEach((key, value) {
        final notification = value as Map<dynamic, dynamic>;
        if (notification['isRead'] == false) {
          unreadCount++;
        }
      });

      return unreadCount;
    } catch (e) {
      return 0;
    }
  }
}
