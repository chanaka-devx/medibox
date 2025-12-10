import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Local notification service for displaying WhatsApp-style notifications
/// 
/// Handles notification display, sound, vibration, and actions
/// Works with Firebase Cloud Messaging for push notifications
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize local notifications
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize with notification tap handler
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ notification permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;

    if (kDebugMode) {
      print('Local notifications initialized');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }

    // Handle navigation based on payload
    // You can use a global navigator key or event bus to navigate
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate to appropriate screen
      // Example: {"deviceId": "MEDIBOX001", "type": "pill_taken"}
    }
  }

  /// Show notification for pill taken
  Future<void> showPillTakenNotification({
    required String deviceNickname,
    required String compartment,
    required String deviceId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'pill_taken_channel',
      'Pill Taken Notifications',
      channelDescription: 'Notifications when pills are taken',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = '💊 Pill Taken - $deviceNickname';
    final body = 'Pills have been taken from the $compartment compartment';
    final payload = '{"deviceId": "$deviceId", "type": "pill_taken", "compartment": "$compartment"}';

    await _notifications.show(
      _generateNotificationId(deviceId),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      print('Pill taken notification shown for $deviceNickname');
    }
  }

  /// Show notification for missed dose
  Future<void> showMissedDoseNotification({
    required String deviceNickname,
    required String compartment,
    required String deviceId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'missed_dose_channel',
      'Missed Dose Alerts',
      channelDescription: 'Critical alerts for missed medication',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      ticker: 'Missed dose alert',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = '⚠️ MISSED DOSE - $deviceNickname';
    final body = 'Pills not taken from $compartment compartment. Please check on your loved one.';
    final payload = '{"deviceId": "$deviceId", "type": "missed_dose", "compartment": "$compartment"}';

    await _notifications.show(
      _generateNotificationId(deviceId),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      print('Missed dose notification shown for $deviceNickname');
    }
  }

  /// Show notification for device offline
  Future<void> showDeviceOfflineNotification({
    required String deviceNickname,
    required String deviceId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'device_status_channel',
      'Device Status',
      channelDescription: 'Notifications about device connectivity',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = '📡 Device Offline - $deviceNickname';
    final body = 'The device has gone offline. Please check the connection.';
    final payload = '{"deviceId": "$deviceId", "type": "device_offline"}';

    await _notifications.show(
      _generateNotificationId(deviceId),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    if (kDebugMode) {
      print('Device offline notification shown for $deviceNickname');
    }
  }

  /// Show notification from Firebase Cloud Messaging
  Future<void> showNotificationFromFCM(RemoteMessage message) async {
    if (!_initialized) await initialize();

    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // Determine notification type and show appropriate notification
    final type = data['type'] as String?;
    final deviceNickname = data['deviceNickname'] as String? ?? 'Pillbox';
    final compartment = data['compartment'] as String? ?? 'unknown';
    final deviceId = data['deviceId'] as String? ?? '';

    switch (type) {
      case 'pill_taken':
        await showPillTakenNotification(
          deviceNickname: deviceNickname,
          compartment: compartment,
          deviceId: deviceId,
        );
        break;
      case 'missed_dose':
        await showMissedDoseNotification(
          deviceNickname: deviceNickname,
          compartment: compartment,
          deviceId: deviceId,
        );
        break;
      case 'device_offline':
        await showDeviceOfflineNotification(
          deviceNickname: deviceNickname,
          deviceId: deviceId,
        );
        break;
      default:
        // Generic notification
        await _showGenericNotification(
          title: notification.title ?? 'MediBox',
          body: notification.body ?? '',
          payload: data.toString(),
        );
    }
  }

  /// Show generic notification
  Future<void> _showGenericNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Generate unique notification ID from device ID
  int _generateNotificationId(String deviceId) {
    return deviceId.hashCode % 100000;
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String deviceId) async {
    await _notifications.cancel(_generateNotificationId(deviceId));
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return result ?? true;
  }
}
