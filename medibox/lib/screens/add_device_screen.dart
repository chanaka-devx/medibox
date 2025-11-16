import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';

/// Add device screen for linking a new pillbox
///
/// Guardian enters device ID and nickname to link device
class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleAddDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    if (authProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await deviceProvider.linkDevice(
      userId: authProvider.userId!,
      deviceId: _deviceIdController.text.trim().toUpperCase(),
      deviceNickname: _nicknameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deviceProvider.errorMessage ?? 'Failed to add device'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Device'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Icon(
                  Icons.add_box,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 32),
                
                // Instructions
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'How to find Device ID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Device ID is printed on the pillbox label\n'
                          '• It\'s usually a 8-12 character code\n'
                          '• Example: MB001234 or PILLBOX123',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Device ID field
                TextFormField(
                  controller: _deviceIdController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    hintText: 'Enter device ID',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                    helperText: 'Found on device label',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter device ID';
                    }
                    if (value.trim().length < 6) {
                      return 'Device ID must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Nickname field
                TextFormField(
                  controller: _nicknameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Device Nickname',
                    hintText: 'e.g., Mom\'s Pillbox',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                    helperText: 'Give your device a friendly name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a nickname';
                    }
                    if (value.trim().length < 2) {
                      return 'Nickname must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Add button
                Consumer<DeviceProvider>(
                  builder: (context, deviceProvider, _) {
                    return ElevatedButton(
                      onPressed: deviceProvider.isLoading ? null : _handleAddDevice,
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
                              'Add Device',
                              style: TextStyle(fontSize: 16),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
