import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/schedule.dart';
import '../services/database_service.dart';

/// Device provider for managing pillbox devices
///
/// Provides device data, real-time updates, and device management methods
/// Uses ChangeNotifier for state management with Provider package
class DeviceProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<Device> _devices = [];
  Device? _selectedDevice;
  bool _isLoading = false;
  String? _errorMessage;

  // Stream subscriptions for real-time updates
  final Map<String, StreamSubscription> _deviceStreams = {};

  // Getters
  List<Device> get devices => _devices;
  Device? get selectedDevice => _selectedDevice;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasDevices => _devices.isNotEmpty;
  int get deviceCount => _devices.length;

  /// Get devices with active alerts
  List<Device> get devicesWithAlerts {
    return _devices.where((device) => device.hasActiveAlerts()).toList();
  }

  /// Get online devices
  List<Device> get onlineDevices {
    return _devices.where((device) => device.status.online).toList();
  }

  /// Get offline devices
  List<Device> get offlineDevices {
    return _devices.where((device) => !device.status.online).toList();
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    for (var subscription in _deviceStreams.values) {
      subscription.cancel();
    }
    _deviceStreams.clear();
    super.dispose();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load all devices for a user
  Future<void> loadDevices(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final devices = await _databaseService.getAllUserDevices(userId);
      _devices = devices;

      // Set up real-time listeners for each device
      for (var device in devices) {
        _setupDeviceListener(device.id);
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load devices: $e');
      _setLoading(false);
    }
  }

  /// Set up real-time listener for a device
  void _setupDeviceListener(String deviceId) {
    // Cancel existing subscription if any
    _deviceStreams[deviceId]?.cancel();

    // Create new subscription
    _deviceStreams[deviceId] = _databaseService.deviceStream(deviceId).listen(
      (Device? updatedDevice) {
        if (updatedDevice != null) {
          // Update device in list
          final index = _devices.indexWhere((d) => d.id == deviceId);
          if (index != -1) {
            _devices[index] = updatedDevice;
            
            // Update selected device if it's the one being updated
            if (_selectedDevice?.id == deviceId) {
              _selectedDevice = updatedDevice;
            }
            
            notifyListeners();
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Error in device stream for $deviceId: $error');
        }
      },
    );
  }

  /// Link a new device to user
  Future<bool> linkDevice({
    required String userId,
    required String deviceId,
    required String deviceNickname,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Check if device exists in Firebase
      final exists = await _databaseService.deviceExists(deviceId);
      if (!exists) {
        // Create new device
        await _databaseService.linkDeviceToUser(
          userId: userId,
          deviceId: deviceId,
          deviceNickname: deviceNickname,
        );
      } else {
        // Link existing device
        await _databaseService.linkDeviceToUser(
          userId: userId,
          deviceId: deviceId,
          deviceNickname: deviceNickname,
        );
      }

      // Reload devices
      await loadDevices(userId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to link device: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Unlink a device from user
  Future<bool> unlinkDevice({
    required String userId,
    required String deviceId,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.unlinkDeviceFromUser(
        userId: userId,
        deviceId: deviceId,
      );

      // Cancel stream subscription
      _deviceStreams[deviceId]?.cancel();
      _deviceStreams.remove(deviceId);

      // Remove from list
      _devices.removeWhere((device) => device.id == deviceId);

      // Clear selected device if it was the removed one
      if (_selectedDevice?.id == deviceId) {
        _selectedDevice = null;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to unlink device: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Select a device
  void selectDevice(String deviceId) {
    _selectedDevice = _devices.firstWhere(
      (device) => device.id == deviceId,
      orElse: () => _devices.first,
    );
    notifyListeners();
  }

  /// Clear selected device
  void clearSelectedDevice() {
    _selectedDevice = null;
    notifyListeners();
  }

  /// Update device nickname
  Future<bool> updateDeviceNickname({
    required String deviceId,
    required String nickname,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.updateDeviceNickname(
        deviceId: deviceId,
        nickname: nickname,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update nickname: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update device schedule
  Future<bool> updateSchedule({
    required String deviceId,
    required Schedule schedule,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.updateSchedule(
        deviceId: deviceId,
        schedule: schedule,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update schedule: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Trigger manual dispense
  Future<bool> triggerManualDispense({
    required String deviceId,
    required String compartment,
  }) async {
    try {
      _setError(null);

      await _databaseService.triggerManualDispense(
        deviceId: deviceId,
        compartment: compartment,
      );

      return true;
    } catch (e) {
      _setError('Failed to trigger dispense: $e');
      return false;
    }
  }

  /// Silence alarm
  Future<bool> silenceAlarm(String deviceId) async {
    try {
      _setError(null);

      await _databaseService.silenceAlarm(deviceId);

      return true;
    } catch (e) {
      _setError('Failed to silence alarm: $e');
      return false;
    }
  }

  /// Clear alerts for a device
  Future<bool> clearAlerts(String deviceId) async {
    try {
      _setError(null);

      await _databaseService.clearAlerts(deviceId);

      return true;
    } catch (e) {
      _setError('Failed to clear alerts: $e');
      return false;
    }
  }

  /// Reset device schedule to defaults
  Future<bool> resetSchedule(String deviceId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.resetSchedule(deviceId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to reset schedule: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get device by ID
  Device? getDeviceById(String deviceId) {
    try {
      return _devices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh single device
  Future<void> refreshDevice(String deviceId) async {
    try {
      final device = await _databaseService.getDevice(deviceId);
      if (device != null) {
        final index = _devices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          _devices[index] = device;
          
          if (_selectedDevice?.id == deviceId) {
            _selectedDevice = device;
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing device: $e');
      }
    }
  }

  /// Refresh all devices
  Future<void> refreshAllDevices(String userId) async {
    await loadDevices(userId);
  }
}
