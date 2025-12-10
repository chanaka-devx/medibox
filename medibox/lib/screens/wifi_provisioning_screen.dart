import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WiFiProvisioningScreen extends StatefulWidget {
  const WiFiProvisioningScreen({Key? key}) : super(key: key);

  @override
  State<WiFiProvisioningScreen> createState() => _WiFiProvisioningScreenState();
}

class _WiFiProvisioningScreenState extends State<WiFiProvisioningScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  BluetoothDevice? _device;
  String _status = "Initializing...";
  bool _isScanning = false;
  bool _isConfiguring = false;

  // UUIDs from ESP32
  final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String ssidCharUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String passwordCharUUID = "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e";
  final String statusCharUUID = "d8de624e-140f-4a22-8594-e2216b84a5f2";
  final String resetCharUUID = "a3c87500-8ed3-4bdf-8a39-a01bebede295";
  
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      _startScan();
    } else {
      setState(() {
        _status = "⚠️ Please grant Bluetooth and Location permissions";
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _status = "🔍 Scanning for MEDIBOX...";
      _device = null;
    });

    try {
      // Check if Bluetooth is on
      if (await FlutterBluePlus.isSupported == false) {
        setState(() {
          _status = "❌ Bluetooth not supported on this device";
          _isScanning = false;
        });
        return;
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName.contains("MEDIBOX")) {
            setState(() {
              _device = r.device;
              _status = "✅ Found ${r.device.platformName}!\nReady to configure WiFi.";
            });
            FlutterBluePlus.stopScan();
            return;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 15));
      
      if (_device == null) {
        setState(() => _status = "❌ MEDIBOX not found.\nMake sure device is powered on and in setup mode.");
      }
    } catch (e) {
      setState(() => _status = "❌ Error: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _sendCredentials() async {
    if (_device == null) {
      _showSnackBar("No device found. Please scan again.");
      return;
    }

    if (_ssidController.text.isEmpty) {
      _showSnackBar("Please enter WiFi network name");
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showSnackBar("Please enter WiFi password");
      return;
    }

    setState(() {
      _isConfiguring = true;
      _status = "📡 Connecting to MEDIBOX...";
    });

    try {
      await _device!.connect(timeout: const Duration(seconds: 15));
      setState(() => _status = "🔍 Discovering services...");

      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? targetService;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception("MEDIBOX service not found");
      }

      // Find characteristics
      BluetoothCharacteristic? ssidChar;
      BluetoothCharacteristic? passwordChar;
      BluetoothCharacteristic? statusChar;

      for (var char in targetService.characteristics) {
        String uuid = char.uuid.toString().toLowerCase();
        if (uuid == ssidCharUUID.toLowerCase()) ssidChar = char;
        if (uuid == passwordCharUUID.toLowerCase()) passwordChar = char;
        if (uuid == statusCharUUID.toLowerCase()) statusChar = char;
      }

      if (ssidChar == null || passwordChar == null || statusChar == null) {
        throw Exception("Required characteristics not found");
      }

      // Subscribe to status updates
      await statusChar.setNotifyValue(true);
      statusChar.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        
        String status = String.fromCharCodes(value);
        setState(() => _status = "📊 Status: $status");

        if (status == "CONNECTED") {
          _showSnackBar("✅ WiFi configured successfully!");
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context, true);
          });
        } else if (status == "FAILED") {
          setState(() {
            _isConfiguring = false;
            _status = "❌ Connection failed.\nPlease check your credentials and try again.";
          });
          _showSnackBar("Connection failed. Check WiFi credentials.");
        } else if (status == "CONNECTING") {
          setState(() => _status = "⏳ MEDIBOX connecting to WiFi...");
        }
      });

      // Send SSID
      setState(() => _status = "📤 Sending WiFi network name...");
      await ssidChar.write(_ssidController.text.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 500));

      // Send Password
      setState(() => _status = "📤 Sending WiFi password...");
      await passwordChar.write(_passwordController.text.codeUnits, withoutResponse: false);

      setState(() => _status = "⏳ Waiting for MEDIBOX to connect...");
    } catch (e) {
      setState(() {
        _isConfiguring = false;
        _status = "❌ Error: $e";
      });
      _showSnackBar("Error: $e");
      await _device?.disconnect();
    }
  }

  Future<void> _resetWiFiCredentials() async {
    if (_device == null) {
      _showSnackBar("No device found. Please scan again.");
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset WiFi Credentials?"),
        content: const Text(
          "This will erase saved WiFi settings on MEDIBOX. "
          "You'll need to configure WiFi again."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isResetting = true;
      _status = "🔄 Resetting WiFi credentials...";
    });

    try {
      await _device!.connect(timeout: const Duration(seconds: 15));
      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? targetService;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception("MEDIBOX service not found");
      }

      // Find reset and status characteristics
      BluetoothCharacteristic? resetChar;
      BluetoothCharacteristic? statusChar;

      for (var char in targetService.characteristics) {
        String uuid = char.uuid.toString().toLowerCase();
        if (uuid == resetCharUUID.toLowerCase()) resetChar = char;
        if (uuid == statusCharUUID.toLowerCase()) statusChar = char;
      }

      if (resetChar == null || statusChar == null) {
        throw Exception("Required characteristics not found");
      }

      // Subscribe to status updates
      await statusChar.setNotifyValue(true);
      statusChar.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        String status = String.fromCharCodes(value);
        
        if (status == "RESET_OK") {
          setState(() {
            _status = "✅ WiFi credentials reset successfully!";
            _isResetting = false;
          });
          _showSnackBar("WiFi reset complete. MEDIBOX is now in setup mode.");
          _device?.disconnect();
        }
      });

      // Send reset command
      await resetChar.write("RESET".codeUnits, withoutResponse: false);
      
      await Future.delayed(const Duration(seconds: 3));
      
      if (_isResetting) {
        setState(() {
          _status = "✅ Reset command sent";
          _isResetting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isResetting = false;
        _status = "❌ Reset failed: $e";
      });
      _showSnackBar("Error: $e");
      await _device?.disconnect();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup MEDIBOX WiFi"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _device != null ? Colors.green.shade50 : Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _device != null ? Icons.check_circle : Icons.bluetooth_searching,
                      size: 48,
                      color: _device != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // WiFi Credentials Form
            if (_device != null) ...[
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: "WiFi Network Name (SSID)",
                  prefixIcon: const Icon(Icons.wifi),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                enabled: !_isConfiguring,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "WiFi Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: true,
                enabled: !_isConfiguring,
              ),
              const SizedBox(height: 24),

              // Configure Button
              ElevatedButton.icon(
                onPressed: _isConfiguring ? null : _sendCredentials,
                icon: _isConfiguring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isConfiguring ? "Configuring..." : "Configure WiFi"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Scan Again Button
            OutlinedButton.icon(
              onPressed: _isScanning || _isConfiguring ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isScanning ? "Scanning..." : "Scan Again"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            if (_device != null) ...[
              const SizedBox(height: 16),
              // Reset WiFi Button
              OutlinedButton.icon(
                onPressed: _isResetting || _isConfiguring ? null : _resetWiFiCredentials,
                icon: _isResetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_off),
                label: Text(_isResetting ? "Resetting..." : "Reset WiFi Credentials"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "📋 Setup Instructions:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text("1. Make sure MEDIBOX is powered on"),
                    Text("2. Wait for device to appear in scan"),
                    Text("3. Enter your WiFi credentials"),
                    Text("4. Tap 'Configure WiFi'"),
                    Text("5. Wait for confirmation"),
                    SizedBox(height: 12),
                    Text(
                      "🔄 To reconfigure WiFi:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text("• Scan for MEDIBOX device"),
                    Text("• Tap 'Reset WiFi Credentials'"),
                    Text("• Configure with new WiFi"),
                    SizedBox(height: 8),
                    Text(
                      "⚠️ Note: MEDIBOX only supports 2.4GHz WiFi networks",
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _device?.disconnect();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
