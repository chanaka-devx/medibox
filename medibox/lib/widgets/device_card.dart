import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';

/// Device card widget for displaying device summary
///
/// Shows device name, status, and alerts in a compact card format
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Device icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: device.status.online
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication,
                      size: 32,
                      color: device.status.online
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Device name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.nickname,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: device.status.online
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              device.status.online ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: device.status.online
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Arrow icon
                  const Icon(Icons.chevron_right),
                ],
              ),
              
              // Alert banner if any
              if (device.hasActiveAlerts()) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.alerts!.getDescription(),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Schedule info
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildScheduleInfo(
                      context,
                      Icons.wb_sunny,
                      'Morning',
                      device.schedule.morning,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildScheduleInfo(
                      context,
                      Icons.wb_twilight,
                      'Afternoon',
                      device.schedule.afternoon,
                      Colors.amber,
                    ),
                  ),
                  Expanded(
                    child: _buildScheduleInfo(
                      context,
                      Icons.nights_stay,
                      'Night',
                      device.schedule.night,
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
              
              // Last dispensed info
              if (device.status.lastDispensed != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last dispensed: ${_formatDateTime(device.status.lastDispensed!)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleInfo(
    BuildContext context,
    IconData icon,
    String label,
    String time,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd').format(dateTime);
      }
    } catch (e) {
      return dateTimeString;
    }
  }
}
