import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// SMS Service for sending notifications via SMSAPI.LK
///
/// Watches Firebase database for notification triggers and sends SMS
/// to the guardian's phone number configured in the user profile
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  // SMSAPI.LK Configuration
  static const String _apiUrl = 'https://dashboard.smsapi.lk/api/v3/sms/send';
  static const String _apiToken = '218|KAbOqPZjfTTbRurszfFUAuRtDXCfeeSYlYb7Tsl1';
  static const String _senderId = 'SMSAPI Demo';

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Map<String, StreamSubscription> _deviceStreams = {};
  bool _isInitialized = false;

  /// Initialize SMS service for a user's devices
  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      debugPrint('SMS Service already initialized');
      return;
    }

    try {
      debugPrint('🔔 Initializing SMS Service...');

      // Get user's devices
      final devicesSnapshot = await _database.ref('users/$userId/devices').get();
      
      if (!devicesSnapshot.exists) {
        debugPrint('⚠️  No devices found for user');
        return;
      }

      final deviceIds = List<String>.from(devicesSnapshot.value as List);
      debugPrint('📱 Found ${deviceIds.length} devices');

      // Set up listeners for each device
      for (final deviceId in deviceIds) {
        await _setupDeviceListener(userId, deviceId);
      }

      _isInitialized = true;
      debugPrint('✅ SMS Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing SMS Service: $e');
    }
  }

  /// Set up listener for a specific device
  Future<void> _setupDeviceListener(String userId, String deviceId) async {
    debugPrint('📡 Setting up listener for device: $deviceId');

    // Listen to notificationTrigger
    final triggerRef = _database.ref('devices/$deviceId/notificationTrigger');
    _deviceStreams['$deviceId-trigger'] = triggerRef.onValue.listen(
      (event) async {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          if (data['triggered'] == true) {
            debugPrint('📬 Pill taken notification for $deviceId');
            await _sendPillTakenSMS(userId, deviceId);
          }
        }
      },
      onError: (error) {
        debugPrint('Error in trigger listener: $error');
      },
    );

    // Listen to missedDose
    final missedRef = _database.ref('devices/$deviceId/missedDose');
    _deviceStreams['$deviceId-missed'] = missedRef.onValue.listen(
      (event) async {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          if (data['missed'] == true) {
            final compartment = data['compartment'] ?? 'scheduled';
            debugPrint('⚠️  Missed dose notification for $deviceId ($compartment)');
            await _sendMissedDoseSMS(userId, deviceId, compartment);
          }
        }
      },
      onError: (error) {
        debugPrint('Error in missed dose listener: $error');
      },
    );
  }

  /// Send SMS when pills are taken
  Future<void> _sendPillTakenSMS(String userId, String deviceId) async {
    final phoneNumber = await _getGuardianPhone(userId);
    if (phoneNumber == null) {
      debugPrint('ℹ️  No phone number configured for SMS');
      return;
    }

    // Get device nickname
    final deviceNickname = await _getDeviceNickname(deviceId);
    final title = deviceNickname != null ? '$deviceNickname - Medicine Taken ✓' : 'Medicine Taken ✓';

    await _sendSMS(
      phoneNumber: phoneNumber,
      title: title,
      body: 'The patient has taken their medication on time.',
    );
  }

  /// Send SMS when dose is missed
  Future<void> _sendMissedDoseSMS(
    String userId,
    String deviceId,
    String compartment,
  ) async {
    final phoneNumber = await _getGuardianPhone(userId);
    if (phoneNumber == null) {
      debugPrint('ℹ️  No phone number configured for SMS');
      return;
    }

    // Get device nickname
    final deviceNickname = await _getDeviceNickname(deviceId);
    final title = deviceNickname != null ? '$deviceNickname - Medicine Not Taken ⚠️' : 'Medicine Not Taken ⚠️';

    await _sendSMS(
      phoneNumber: phoneNumber,
      title: title,
      body: 'Missed $compartment medication',
    );
  }

  /// Get device nickname from Firebase
  Future<String?> _getDeviceNickname(String deviceId) async {
    try {
      final snapshot = await _database
          .ref('devices/$deviceId/nickname')
          .get();

      if (!snapshot.exists) {
        return null;
      }

      return snapshot.value as String?;
    } catch (e) {
      debugPrint('Error getting device nickname: $e');
      return null;
    }
  }

  /// Get guardian phone number from user profile
  Future<String?> _getGuardianPhone(String userId) async {
    try {
      debugPrint('📞 Looking up phone number for user: $userId');
      
      final snapshot = await _database
          .ref('users/$userId/notifications/phoneNumber')
          .get();

      if (!snapshot.exists) {
        debugPrint('⚠️  Phone number not found at: users/$userId/notifications/phoneNumber');
        debugPrint('💡 Please add phone number in Profile screen');
        return null;
      }

      final phoneNumber = snapshot.value as String?;
      debugPrint('✅ Found phone number: $phoneNumber');
      return phoneNumber;
    } catch (e) {
      debugPrint('❌ Error getting guardian phone: $e');
      return null;
    }
  }

  /// Send SMS via SMSAPI.LK
  Future<void> _sendSMS({
    required String phoneNumber,
    required String title,
    required String body,
  }) async {
    try {
      final message = '$title: $body';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'recipient': phoneNumber,
          'sender_id': _senderId,
          'type': 'plain',
          'message': message,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['status'] == 'success') {
        debugPrint('✅ SMS sent to $phoneNumber');
        debugPrint('   Message: $message');
      } else {
        debugPrint('❌ SMS failed: ${responseData['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error sending SMS: $e');
    }
  }

  /// Dispose of all stream subscriptions
  void dispose() {
    debugPrint('🛑 Disposing SMS Service');
    for (var subscription in _deviceStreams.values) {
      subscription.cancel();
    }
    _deviceStreams.clear();
    _isInitialized = false;
  }
}
