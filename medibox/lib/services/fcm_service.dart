import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';
import 'database_service.dart';

/// Firebase Cloud Messaging service for push notifications
///
/// Handles notification permissions, token management, and message handling
/// Supports foreground and background notifications
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotifications = LocalNotificationService();
  final DatabaseService _database = DatabaseService();

  /// Initialize FCM and request permissions
  ///
  /// Should be called once during app startup
  /// Cloud Functions will handle sending notifications using FCM V1 API
  Future<void> initialize({String? userId}) async {
    try {
      // Initialize local notifications
      await _localNotifications.initialize();
      
      // Request notification permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('FCM Permission status: ${settings.authorizationStatus}');
      }

      // Get FCM token
      final token = await getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // Save token to user profile and all devices
      if (userId != null && token != null) {
        await _database.saveUserFcmToken(userId: userId, fcmToken: token);
        await _database.updateFcmTokenForAllDevices(userId: userId, fcmToken: token);
      }

      // Set up message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        // Save refreshed token
        if (userId != null) {
          _database.saveUserFcmToken(userId: userId, fcmToken: newToken);
          _database.updateFcmTokenForAllDevices(userId: userId, fcmToken: newToken);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('FCM initialization error: $e');
      }
    }
  }

  /// Get FCM token for this device
  ///
  /// This token is used to send notifications to this specific device
  /// Store this token in Firebase Database for sending targeted notifications
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting FCM token: $e');
      }
    }
  }

  /// Subscribe to a topic for broadcast notifications
  ///
  /// Example: Subscribe all guardians to "pillbox_alerts" topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }

  /// Set up message handlers for foreground, background, and terminated states
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Foreground message received: ${message.messageId}');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');
        print('Data: ${message.data}');
      }

      // Show in-app notification or update UI
      _handleMessage(message);
    });

    // Handle background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Background message opened: ${message.messageId}');
      }

      // Navigate to appropriate screen based on notification data
      _handleMessageNavigation(message);
    });

    // Check if app was opened from a terminated state
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('App opened from terminated state: ${message.messageId}');
        }
        _handleMessageNavigation(message);
      }
    });
  }

  /// Handle incoming message (foreground)
  void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    if (kDebugMode) {
      print('Notification: ${notification?.title} - ${notification?.body}');
      print('Data: $data');
    }

    // Show local notification with WhatsApp-style display
    _localNotifications.showNotificationFromFCM(message);

    if (data.isNotEmpty) {
      // Handle notification data
      final type = data['type'];
      final deviceId = data['deviceId'];

      if (kDebugMode) {
        print('Notification type: $type, deviceId: $deviceId');
      }

      // You can trigger app-specific actions based on type
      // e.g., refresh device status, show alert dialog, etc.
    }
  }

  /// Handle navigation when user taps notification
  void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    
    if (data.isNotEmpty) {
      final type = data['type'];
      final deviceId = data['deviceId'];

      // Navigate based on notification type
      switch (type) {
        case 'pill_dispensed':
          // Navigate to device details screen
          if (kDebugMode) {
            print('Navigate to device: $deviceId - Pill dispensed');
          }
          break;
        case 'missed_dose':
          // Navigate to alerts screen
          if (kDebugMode) {
            print('Navigate to device: $deviceId - Missed dose alert');
          }
          break;
        case 'device_offline':
          // Navigate to device status screen
          if (kDebugMode) {
            print('Navigate to device: $deviceId - Device offline');
          }
          break;
        default:
          if (kDebugMode) {
            print('Unknown notification type: $type');
          }
      }
    }
  }

  /// Send a test notification (for debugging)
  /// Note: Actual notification sending should be done from backend/Cloud Functions
  Future<void> sendTestNotification() async {
    // This is just a placeholder
    // In production, notifications are sent from:
    // 1. Firebase Console
    // 2. Cloud Functions
    // 3. Backend server using Firebase Admin SDK
    
    if (kDebugMode) {
      print('Test notification - This should be sent from backend');
    }
  }
}

/// Background message handler
/// Must be a top-level function (not inside a class)
/// Add this to your main.dart before runApp()
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  // await Firebase.initializeApp();
  
  if (kDebugMode) {
    print('Background message handler: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
  }

  // Handle background message
  // You can perform background tasks here like updating local database
}
