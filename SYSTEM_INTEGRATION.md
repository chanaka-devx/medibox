# MediBox System Integration Guide

## 🎯 Complete Flow: Mobile App ↔ Firebase ↔ ESP32

### System Overview

```
┌─────────────────┐
│  Flutter App    │
│  (Guardian)     │
└────────┬────────┘
         │
         │ Set Schedule Times
         ↓
┌─────────────────┐
│    Firebase     │
│ Realtime DB     │
└────────┬────────┘
         │
         │ Sync Every 60s
         ↓
┌─────────────────┐
│   ESP32 Device  │
│   (Pillbox)     │
└─────────────────┘
```

## 📱 Mobile App (Already Configured ✅)

### Schedule Update Flow

1. **User Opens Schedule Screen**
   - `schedule_screen.dart` displays current times
   - Loads from device model (synced from Firebase)

2. **User Updates Times**
   - Picks new time using `showTimePicker()`
   - Clicks "Save Schedule"

3. **Schedule Saved to Firebase**
   ```dart
   // device_provider.dart
   Future<bool> updateSchedule({
     required String deviceId,
     required Schedule schedule,
   }) async {
     await _databaseService.updateSchedule(
       deviceId: deviceId,
       schedule: schedule,
     );
   }
   ```

4. **Database Service Writes to Firebase**
   ```dart
   // database_service.dart
   Future<void> updateSchedule({
     required String deviceId,
     required Schedule schedule,
   }) async {
     await _devicesRef.child(deviceId).child('schedule').set(schedule.toJson());
   }
   ```

### Firebase Database Structure

```json
{
  "devices": {
    "DEVICE001": {
      "nickname": "Mom's Pillbox",
      "schedule": {
        "morning": "08:00",      ← ESP32 reads these
        "afternoon": "14:30",    ← ESP32 reads these
        "night": "21:00"         ← ESP32 reads these
      },
      "status": {
        "online": true,
        "currentStage": 0,
        "lastSync": "12345678",
        "morning": {
          "completed": false
        },
        "afternoon": {
          "completed": false
        },
        "night": {
          "completed": false
        }
      }
    }
  },
  "users": {
    "userId123": {
      "devices": ["DEVICE001"]
    }
  }
}
```

## 🔧 ESP32 Configuration (Update Required)

### 1. Install Firebase Library

**Arduino IDE:**
1. Open Arduino IDE
2. Go to **Sketch → Include Library → Manage Libraries**
3. Search: **"Firebase ESP Client"** by Mobizt
4. Install latest version (6.x or higher)

### 2. Update Firebase Credentials

Open `esp32_firmware/medibox_esp32_firebase.ino`:

```cpp
// Line 20-21: Replace with your Firebase details
#define FIREBASE_HOST "medibox-foe-default-rtdb.firebaseio.com"
#define API_KEY "AIzaSyB1H1F5DPPLEdy7UTEZBEXUniHXGxxa7W0"
```

**Get these values from:**
- `medibox/lib/firebase_options.dart`
- Or Firebase Console: Project Settings

### 3. Set Device ID

```cpp
// Line 22: Match this with your Flutter app
#define DEVICE_ID "DEVICE001"
```

**IMPORTANT:** This must match the device ID in your Flutter app!

### 4. Upload to ESP32

1. Connect ESP32 via USB
2. Select Board: **ESP32 Dev Module**
3. Select correct COM Port
4. Click **Upload**
5. Open Serial Monitor (115200 baud)

## 🔄 How Sync Works

### ESP32 Reads Schedule

```cpp
// Runs in setup() and every 60 seconds
void syncScheduleFromFirebase() {
  String schedulePath = dbPath + "/schedule";
  
  if(Firebase.RTDB.getJSON(&fbdo, schedulePath)) {
    // Parse morning time
    json.get(morning, "morning");
    parseTimeString(morning.stringValue, alarmHour[0], alarmMinute[0]);
    
    // Parse afternoon time
    json.get(afternoon, "afternoon");
    parseTimeString(afternoon.stringValue, alarmHour[1], alarmMinute[1]);
    
    // Parse night time
    json.get(night, "night");
    parseTimeString(night.stringValue, alarmHour[2], alarmMinute[2]);
  }
}
```

### ESP32 Writes Status

```cpp
// After each medication dose
void updateStatusToFirebase() {
  String statusPath = dbPath + "/status";
  
  FirebaseJson json;
  json.set("online", true);
  json.set("currentStage", currentStage);
  json.set("morning/completed", currentStage > 0);
  json.set("afternoon/completed", currentStage > 1);
  json.set("night/completed", currentStage > 2);
  
  Firebase.RTDB.setJSON(&fbdo, statusPath, &json);
}
```

### Flutter App Listens for Changes

```dart
// device_provider.dart - Real-time listener
void _setupDeviceListener(String deviceId) {
  _deviceStreams[deviceId] = _databaseService.deviceStream(deviceId).listen(
    (Device? updatedDevice) {
      if (updatedDevice != null) {
        // Update UI automatically
        _devices[index] = updatedDevice;
        notifyListeners();
      }
    }
  );
}
```

## 🎯 Complete User Journey

### Setting Schedule from Mobile App

1. **Guardian opens Flutter app**
2. **Navigates to Schedule Screen**
3. **Sets times:**
   - Morning: 08:30
   - Afternoon: 14:00
   - Night: 21:00
4. **Clicks "Save Schedule"**
5. **Data written to Firebase:**
   ```
   /devices/DEVICE001/schedule/morning = "08:30"
   /devices/DEVICE001/schedule/afternoon = "14:00"
   /devices/DEVICE001/schedule/night = "21:00"
   ```

### ESP32 Syncs and Executes

1. **ESP32 syncs within 60 seconds**
2. **Serial Monitor shows:**
   ```
   📥 Syncing schedule from Firebase...
     Morning: 08:30
     Afternoon: 14:00
     Night: 21:00
   ✓ Schedule synced successfully
   ```

3. **At 08:30 AM:**
   - 🔔 Buzzer rings for 10 seconds
   - ⏳ Waits 30 seconds for button press

4. **Patient presses button:**
   - 🔄 Motor rotates 45° (dispenses pills)
   - ✅ Status updated to Firebase
   - 📱 Guardian sees update in real-time

### Guardian Monitors Progress

1. **Flutter app shows real-time status:**
   - Morning: ✅ Completed (08:32 AM)
   - Afternoon: ⏳ Pending
   - Night: ⏳ Pending

2. **If patient misses dose:**
   - ⚠️ Alert appears in app
   - Guardian receives notification

## 🔍 Testing the Integration

### 1. Test Schedule Update

**In Flutter app:**
```dart
// Set test time (1 minute from now)
await deviceProvider.updateSchedule(
  deviceId: 'DEVICE001',
  schedule: Schedule(
    morning: '${currentHour}:${currentMinute + 1}',
    afternoon: '13:00',
    night: '20:00',
  ),
);
```

**Check ESP32 Serial Monitor:**
```
📥 Syncing schedule from Firebase...
  Morning: 15:46 (whatever time you set)
✓ Schedule synced successfully
```

### 2. Verify Database Structure

**Firebase Console:**
1. Go to Realtime Database
2. Navigate to: `devices/DEVICE001/schedule`
3. Should see:
   ```json
   {
     "morning": "08:00",
     "afternoon": "14:00",
     "night": "21:00"
   }
   ```

### 3. Test Full Cycle

1. Set morning time to 1 minute from now
2. Wait for ESP32 to sync (up to 60 seconds)
3. At scheduled time:
   - Buzzer should ring
   - Serial Monitor shows: "ALARM TRIGGERED"
4. Press button within 30 seconds
5. Motor rotates, confirmation beep
6. Check Firebase: `status/currentStage` = 1
7. Check Flutter app: Morning marked as completed

## ⚠️ Troubleshooting

### Schedule Not Syncing to ESP32

**Check:**
- ✅ WiFi connected on ESP32
- ✅ Firebase credentials correct
- ✅ Device ID matches (`DEVICE001`)
- ✅ Firebase library installed
- ✅ Serial Monitor shows "✓ Schedule synced"

### Motor Not Rotating

**Check:**
- ✅ Button pressed within 30 seconds of alarm
- ✅ Motor pins connected correctly
- ✅ 5V power supply adequate
- ✅ Serial Monitor shows "Button pressed"

### App Not Showing Updates

**Check:**
- ✅ Internet connection on mobile
- ✅ Firebase rules allow read access
- ✅ Device linked to user account
- ✅ Real-time listener active

## 🎉 Success Indicators

### ESP32 Working Correctly:
```
✓ WiFi connected!
✓ Firebase authentication successful
✓ Firebase initialized
✓ Schedule synced successfully
System Ready...
```

### Flutter App Working Correctly:
- Device shows as "Online"
- Schedule times display correctly
- Status updates in real-time
- No error messages

### Full Integration Success:
- ✅ Change time in app → ESP32 syncs within 60s
- ✅ Alarm rings at scheduled time
- ✅ Button press dispenses pills
- ✅ Status updates in app immediately
- ✅ Guardian sees completion in real-time

## 📚 File References

**Flutter App:**
- Schedule UI: `lib/screens/schedule_screen.dart`
- Provider: `lib/providers/device_provider.dart`
- Database: `lib/services/database_service.dart`
- Model: `lib/models/schedule.dart`

**ESP32:**
- Main firmware: `esp32_firmware/medibox_esp32_firebase.ino`
- Setup guide: `esp32_firmware/FIREBASE_SETUP.md`

**Configuration:**
- Firebase config: `medibox/lib/firebase_options.dart`
- Database rules: `medibox/firebase_database_rules.json`
