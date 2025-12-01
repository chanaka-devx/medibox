import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import 'schedule_screen.dart';

/// Device details screen showing status, alerts, and controls
///
/// Provides real-time monitoring and remote control features
class DeviceDetailsScreen extends StatelessWidget {
  final Device device;

  const DeviceDetailsScreen({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        // Get the updated device from the provider
        final updatedDevice = deviceProvider.getDeviceById(device.id) ?? device;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(updatedDevice.nickname),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditNicknameDialog(context, updatedDevice);
                },
                tooltip: 'Edit Nickname',
              ),
              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(device: updatedDevice),
                    ),
                  );
                },
                tooltip: 'Edit Schedule',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _handleRefresh(context),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status card
                  _buildStatusCard(context, updatedDevice),
                  const SizedBox(height: 16),
                  
                  // Schedule card
                  _buildScheduleCard(context, updatedDevice),
                  const SizedBox(height: 16),
                  
                  // Alerts card
                  if (updatedDevice.hasActiveAlerts()) ...[
                    _buildAlertsCard(context, updatedDevice),
                    const SizedBox(height: 16),
                  ],
                  
                  // Last dispensed card
                  if (updatedDevice.status.lastDispensed != null) ...[
                    _buildLastDispensedCard(context, updatedDevice),
                    const SizedBox(height: 16),
                  ],
                  
                  // Control buttons
                  _buildControlButtons(context, updatedDevice),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, Device device) {
    final isOnline = device.status.online;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 16,
                  color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOnline ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.badge,
              'Device ID',
              device.id,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.label,
              'Nickname',
              device.nickname,
            ),
            const SizedBox(height: 12),
            _buildBatteryIndicator(context, device.status.batteryLevel ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, Device device) {
    final nextTime = device.getNextScheduledTime();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScheduleScreen(device: device),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.wb_sunny, 'Morning', device.schedule.morning),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.wb_twilight, 'Afternoon', device.schedule.afternoon),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.nights_stay, 'Night', device.schedule.night),
            if (nextTime != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alarm, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Next dose: $nextTime',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context, Device device) {
    final alerts = device.alerts!;
    
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              alerts.getDescription(),
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _handleClearAlerts(context, device);
              },
              icon: const Icon(Icons.check),
              label: const Text('Clear Alerts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastDispensedCard(BuildContext context, Device device) {
    final lastDispensed = device.status.lastDispensed!;
    DateTime? dateTime;
    
    try {
      dateTime = DateTime.parse(lastDispensed);
    } catch (e) {
      // If parsing fails, show as is
    }
    
    final formattedDate = dateTime != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime)
        : lastDispensed;
    
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Dispensed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, Device device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Remote Control',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Manual dispense buttons
            Text(
              'Manual Dispense',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleManualDispense(context, device, 'morning'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.wb_sunny, size: 24),
                        SizedBox(height: 4),
                        Text('Morning', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleManualDispense(context, device, 'afternoon'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.wb_twilight, size: 24),
                        SizedBox(height: 4),
                        Text('Afternoon', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleManualDispense(context, device, 'night'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.nights_stay, size: 24),
                        SizedBox(height: 4),
                        Text('Night', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Silence alarm button
            OutlinedButton.icon(
              onPressed: () => _handleSilenceAlarm(context, device),
              icon: const Icon(Icons.volume_off),
              label: const Text('Silence Alarm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildBatteryIndicator(BuildContext context, int batteryLevel) {
    Color batteryColor;
    IconData batteryIcon;
    String displayText;

    if (batteryLevel == 0) {
      // Unknown battery level
      batteryColor = Colors.grey;
      batteryIcon = Icons.battery_unknown;
      displayText = 'Unknown';
    } else if (batteryLevel > 50) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_full;
      displayText = '$batteryLevel%';
    } else if (batteryLevel > 20) {
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_3_bar;
      displayText = '$batteryLevel%';
    } else {
      batteryColor = Colors.red;
      batteryIcon = Icons.battery_1_bar;
      displayText = '$batteryLevel%';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: batteryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: batteryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(batteryIcon, color: batteryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battery Level',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: batteryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (batteryLevel > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: batteryLevel / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: batteryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    displayText,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: batteryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualDispense(BuildContext context, Device device, String compartment) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Dispense'),
        content: Text('Dispense pills from $compartment compartment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dispense'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await deviceProvider.triggerManualDispense(
        deviceId: device.id,
        compartment: compartment,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Dispense command sent'
                  : 'Failed to send command',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSilenceAlarm(BuildContext context, Device device) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    final success = await deviceProvider.silenceAlarm(device.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Alarm silenced' : 'Failed to silence alarm',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleClearAlerts(BuildContext context, Device device) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    final success = await deviceProvider.clearAlerts(device.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Alerts cleared' : 'Failed to clear alerts',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditNicknameDialog(BuildContext context, Device device) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final nicknameController = TextEditingController(text: device.nickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: 'Device Nickname',
            hintText: 'Enter a nickname for your device',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final nickname = nicknameController.text.trim();
              if (nickname.isNotEmpty) {
                Navigator.of(context).pop(nickname);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty && newNickname != device.nickname) {
      final success = await deviceProvider.updateDeviceNickname(
        deviceId: device.id,
        nickname: newNickname,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Nickname updated successfully'
                  : 'Failed to update nickname',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }

    nicknameController.dispose();
  }

  Future<void> _handleRefresh(BuildContext context) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    await deviceProvider.refreshDevice(device.id);
     
  }
}
