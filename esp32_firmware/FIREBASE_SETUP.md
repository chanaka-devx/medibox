# Firebase Setup Guide for ESP32

## Step 1: Get Firebase Configuration

### From Your Flutter App:

1. Open `medibox/lib/firebase_options.dart`
2. Find these values:
   - `databaseURL` (e.g., `medibox-foe-default-rtdb.firebaseio.com`)
   - `apiKey` (e.g., `AIzaSy...`)

### Update ESP32 Code:

Open `medibox_esp32_firebase.ino` and replace:

```cpp
#define FIREBASE_HOST "your-project.firebaseio.com"
#define API_KEY "your-api-key-here"
```

With your actual values:

```cpp
#define FIREBASE_HOST "medibox-foe-default-rtdb.firebaseio.com"
#define API_KEY "AIzaSyB1H1F5DPPLEdy7UTEZBEXUniHXGxxa7W0"
```

## Step 2: Install Firebase Arduino Library

1. Open Arduino IDE
2. Go to **Sketch → Include Library → Manage Libraries**
3. Search for **"Firebase ESP Client"** by Mobizt
4. Install the latest version (6.x or higher)

## Step 3: Firebase Database Structure

The ESP32 will read/write data at this path:
```
/devices/DEVICE001/
  ├── schedule/
  │   ├── morning: "08:00"
  │   ├── afternoon: "13:00"
  │   └── night: "20:00"
  └── status/
      ├── online: true
      ├── lastSync: "12345678"
      ├── currentStage: 0
      ├── morning/completed: false
      ├── afternoon/completed: false
      └── night/completed: false
```

## Step 4: Set Times from Mobile App

Your Flutter app should write to Firebase:

```dart
DatabaseReference scheduleRef = FirebaseDatabase.instance
    .ref('devices/DEVICE001/schedule');

await scheduleRef.update({
  'morning': '08:00',
  'afternoon': '13:00',
  'night': '20:00',
});
```

## Step 5: Monitor Status in Mobile App

Read device status from Firebase:

```dart
DatabaseReference statusRef = FirebaseDatabase.instance
    .ref('devices/DEVICE001/status');

statusRef.onValue.listen((event) {
  final data = event.snapshot.value as Map?;
  if (data != null) {
    bool isOnline = data['online'] ?? false;
    int stage = data['currentStage'] ?? 0;
    // Update UI
  }
});
```

## Step 6: Upload to ESP32

1. Connect ESP32 via USB
2. Select correct board: **ESP32 Dev Module**
3. Select correct port
4. Click **Upload**
5. Open **Serial Monitor** (115200 baud) to see logs

## Troubleshooting

### If Firebase connection fails:
- Check WiFi credentials
- Verify Firebase Host and API Key
- Ensure Firebase Realtime Database is enabled
- Check Firebase security rules (should allow read/write for testing)

### Firebase Security Rules (for testing):
```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

### If schedule doesn't update:
- Verify data is written to correct path in Firebase Console
- Check Serial Monitor for sync messages
- Ensure ESP32 has internet connection
- Schedule syncs every 60 seconds

## How It Works

1. **Mobile App** → Sets schedule times in Firebase
2. **ESP32** → Syncs schedule every 60 seconds from Firebase
3. **ESP32** → Rings buzzer at scheduled times
4. **User** → Presses button to dispense pills
5. **ESP32** → Updates status in Firebase
6. **Mobile App** → Shows real-time status

## Device ID

To use multiple devices, change `DEVICE_ID` in the code:
```cpp
#define DEVICE_ID "DEVICE002"  // Different for each device
```
