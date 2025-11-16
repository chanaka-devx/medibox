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
    return Scaffold(
      appBar: AppBar(
        title: Text(device.nickname),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScheduleScreen(device: device),
                ),
              );
            },
            tooltip: 'Edit Schedule',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            _buildStatusCard(context),
            const SizedBox(height: 16),
            
            // Schedule card
            _buildScheduleCard(context),
            const SizedBox(height: 16),
            
            // Alerts card
            if (device.hasActiveAlerts()) ...[
              _buildAlertsCard(context),
              const SizedBox(height: 16),
            ],
            
            // Last dispensed card
            if (device.status.lastDispensed != null) ...[
              _buildLastDispensedCard(context),
              const SizedBox(height: 16),
            ],
            
            // Control buttons
            _buildControlButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
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
            if (device.status.batteryLevel != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.battery_std,
                'Battery',
                '${device.status.batteryLevel}% (${device.status.getBatteryStatus()})',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context) {
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

  Widget _buildAlertsCard(BuildContext context) {
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
                _handleClearAlerts(context);
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

  Widget _buildLastDispensedCard(BuildContext context) {
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

  Widget _buildControlButtons(BuildContext context) {
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
                  child: ElevatedButton.icon(
                    onPressed: () => _handleManualDispense(context, 'morning'),
                    icon: const Icon(Icons.wb_sunny, size: 20),
                    label: const Text('Morning'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleManualDispense(context, 'afternoon'),
                    icon: const Icon(Icons.wb_twilight, size: 20),
                    label: const Text('Afternoon'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleManualDispense(context, 'night'),
                    icon: const Icon(Icons.nights_stay, size: 20),
                    label: const Text('Night'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Silence alarm button
            OutlinedButton.icon(
              onPressed: () => _handleSilenceAlarm(context),
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

  Future<void> _handleManualDispense(BuildContext context, String compartment) async {
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

  Future<void> _handleSilenceAlarm(BuildContext context) async {
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

  Future<void> _handleClearAlerts(BuildContext context) async {
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
}
