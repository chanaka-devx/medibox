import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/schedule.dart';
import '../providers/device_provider.dart';

/// Schedule editing screen
///
/// Allows guardian to set medication times for morning, afternoon, and night
class ScheduleScreen extends StatefulWidget {
  final Device device;

  const ScheduleScreen({
    super.key,
    required this.device,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late TimeOfDay _morningTime;
  late TimeOfDay _afternoonTime;
  late TimeOfDay _nightTime;

  @override
  void initState() {
    super.initState();
    _initializeTimes();
  }

  void _initializeTimes() {
    _morningTime = _parseTime(widget.device.schedule.morning);
    _afternoonTime = _parseTime(widget.device.schedule.afternoon);
    _nightTime = _parseTime(widget.device.schedule.night);
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(String period) async {
    TimeOfDay initialTime;
    
    switch (period) {
      case 'morning':
        initialTime = _morningTime;
        break;
      case 'afternoon':
        initialTime = _afternoonTime;
        break;
      case 'night':
        initialTime = _nightTime;
        break;
      default:
        return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (period) {
          case 'morning':
            _morningTime = picked;
            break;
          case 'afternoon':
            _afternoonTime = picked;
            break;
          case 'night':
            _nightTime = picked;
            break;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    final newSchedule = Schedule(
      morning: _formatTime(_morningTime),
      afternoon: _formatTime(_afternoonTime),
      night: _formatTime(_nightTime),
    );

    final success = await deviceProvider.updateSchedule(
      deviceId: widget.device.id,
      schedule: newSchedule,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deviceProvider.errorMessage ?? 'Failed to update schedule'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Schedule'),
        content: const Text('Reset to default times?\n\nMorning: 08:00\nAfternoon: 13:00\nNight: 20:00'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
      
      final success = await deviceProvider.resetSchedule(widget.device.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deviceProvider.errorMessage ?? 'Failed to reset schedule'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _handleReset,
            tooltip: 'Reset to Default',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set the times when pills should be dispensed',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Morning time
            _buildTimeCard(
              'Morning',
              Icons.wb_sunny,
              _morningTime,
              Colors.orange,
              () => _selectTime('morning'),
            ),
            const SizedBox(height: 16),
            
            // Afternoon time
            _buildTimeCard(
              'Afternoon',
              Icons.wb_twilight,
              _afternoonTime,
              Colors.amber,
              () => _selectTime('afternoon'),
            ),
            const SizedBox(height: 16),
            
            // Night time
            _buildTimeCard(
              'Night',
              Icons.nights_stay,
              _nightTime,
              Colors.indigo,
              () => _selectTime('night'),
            ),
            const SizedBox(height: 32),
            
            // Save button
            Consumer<DeviceProvider>(
              builder: (context, deviceProvider, _) {
                return ElevatedButton(
                  onPressed: deviceProvider.isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: deviceProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Schedule',
                          style: TextStyle(fontSize: 16),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(
    String label,
    IconData icon,
    TimeOfDay time,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(time),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
