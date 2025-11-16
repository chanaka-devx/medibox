# MediBox - Smart Medical Pillbox System

A comprehensive cloud-connected smart medical pillbox system for elderly users who need medication reminders. The system consists of a Flutter guardian app and ESP32-based hardware.

## 📱 System Overview

### Components
1. **Flutter Mobile App (Guardian)** - Allows caregivers to monitor and control the pillbox remotely
2. **Firebase Backend** - Handles authentication, real-time database, and push notifications
3. **ESP32 Device** - Physical pillbox with automatic pill dispensing
4. **DS3231 RTC** - Real-time clock for accurate timing
5. **Motor System** - Rotates compartments to dispense pills

### Features
- ✅ Guardian authentication (Email/Password)
- ✅ Multiple device management
- ✅ Real-time medication schedule configuration
- ✅ Automatic pill dispensing with alarms
- ✅ Remote manual dispense control
- ✅ Missed dose alerts
- ✅ Device online/offline monitoring
- ✅ Push notifications (FCM)
- ✅ 3 daily medication times (Morning, Afternoon, Night)

---

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Android Studio / Xcode
- Firebase Project
- ESP32 Development Board
- Arduino IDE or PlatformIO

---

## 📱 Part 1: Flutter App Setup

### Step 1: Install Dependencies

```bash
cd medibox
flutter pub get
```

### Step 2: Configure Firebase

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add Project"
   - Enter project name (e.g., "medibox")
   - Disable Google Analytics (optional)
   - Click "Create Project"

2. **Enable Firebase Services**
   
   **Authentication:**
   - Go to Authentication → Sign-in method
   - Enable "Email/Password"
   - Save

   **Realtime Database:**
   - Go to Realtime Database
   - Click "Create Database"
   - Start in **test mode** initially
   - Select location closest to you
   - Click "Enable"

   **Cloud Messaging:**
   - Go to Project Settings → Cloud Messaging
   - Note your Server Key (for later)

3. **Add Android App to Firebase**
   - In Project Settings, click "Add app" → Android
   - Package name: `com.example.medibox` (or your custom package)
   - Download `google-services.json`
   - Place it in `android/app/google-services.json`

4. **Add iOS App to Firebase** (if building for iOS)
   - In Project Settings, click "Add app" → iOS
   - Bundle ID: `com.example.medibox`
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/GoogleService-Info.plist`

5. **Generate Firebase Options**
   
   Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

   Configure Firebase:
   ```bash
   flutterfire configure
   ```
   
   - Select your Firebase project
   - Select platforms (Android, iOS, etc.)
   - This will generate `lib/firebase_options.dart`

6. **Deploy Security Rules**
   
   - Copy contents from `firebase_database_rules.json`
   - Go to Firebase Console → Realtime Database → Rules
   - Paste the rules
   - Click "Publish"

### Step 3: Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For release build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Step 4: Test the App

1. **Register a Guardian Account**
   - Open the app
   - Click "Register"
   - Enter name, email, password
   - Click "Create Account"

2. **Add a Device**
   - Login with your credentials
   - Click "Add Device"
   - Enter Device ID (e.g., "MB001234")
   - Enter nickname (e.g., "Mom's Pillbox")
   - Click "Add Device"

3. **Set Medication Schedule**
   - Click on the device card
   - Click the schedule icon
   - Set times for Morning, Afternoon, Night
   - Click "Save Schedule"

---

## 🔧 Part 2: ESP32 Hardware Setup

### Hardware Requirements

| Component | Specification | Quantity |
|-----------|--------------|----------|
| ESP32 Dev Board | ESP32-WROOM-32 | 1 |
| DS3231 RTC Module | I2C Interface | 1 |
| Stepper Motor | NEMA 17 (or similar) | 1 |
| Stepper Driver | A4988 / DRV8825 | 1 |
| Buzzer | Active or Passive | 1 |
| LEDs | 5mm, any color | 3 |
| Push Button | Momentary switch | 1 |
| Resistors | 220Ω (LED), 10kΩ (Button) | 4 |
| Power Supply | 12V 2A (for motor) | 1 |
| Breadboard/PCB | For prototyping | 1 |
| Jumper Wires | Male-to-Male, Male-to-Female | 20+ |

### Wiring Diagram

```
ESP32 Connections:
├─ DS3231 RTC
│  ├─ VCC  → 3.3V
│  ├─ GND  → GND
│  ├─ SDA  → GPIO21
│  └─ SCL  → GPIO22
│
├─ Stepper Driver (A4988)
│  ├─ STEP → GPIO25
│  ├─ DIR  → GPIO26
│  ├─ EN   → GPIO27
│  ├─ VDD  → 3.3V
│  ├─ GND  → GND
│  └─ VMOT → 12V Power Supply
│
├─ Motor (to Driver)
│  ├─ A+, A-, B+, B- → Driver outputs
│
├─ Buzzer
│  ├─ +    → GPIO32
│  └─ -    → GND
│
├─ LEDs (with 220Ω resistors)
│  ├─ Morning LED   → GPIO12
│  ├─ Afternoon LED → GPIO14
│  └─ Night LED     → GPIO13
│
└─ Button (with 10kΩ pull-up)
   ├─ One pin → GPIO33
   └─ Other pin → GND
```

### Step 1: Install Arduino IDE

1. Download from [arduino.cc](https://www.arduino.cc/en/software)
2. Install ESP32 board support:
   - File → Preferences
   - Additional Board Manager URLs: `https://dl.espressif.com/dl/package_esp32_index.json`
   - Tools → Board → Boards Manager
   - Search "ESP32" and install

### Step 2: Install Required Libraries

Open Arduino IDE → Sketch → Include Library → Manage Libraries

Install these libraries:
- **Firebase ESP Client** by Mobizt (v4.4.14 or later)
- **RTClib** by Adafruit (v2.1.4 or later)
- **AccelStepper** (optional, for smoother motor control)

### Step 3: Configure ESP32 Code

1. Open `esp32_firmware/medibox_esp32.ino`

2. **Update WiFi Credentials:**
   ```cpp
   #define WIFI_SSID "YourWiFiName"
   #define WIFI_PASSWORD "YourWiFiPassword"
   ```

3. **Update Firebase Configuration:**
   
   Get these from Firebase Console → Project Settings:
   ```cpp
   #define FIREBASE_HOST "your-project-id.firebaseio.com"
   #define API_KEY "your-web-api-key"
   #define DATABASE_URL "https://your-project-id.firebaseio.com"
   ```

4. **Set Device ID:**
   ```cpp
   #define DEVICE_ID "MB001234"  // Must match the ID in the app
   ```

5. **Adjust Pin Numbers** (if different from default)

### Step 4: Upload to ESP32

1. Connect ESP32 to computer via USB
2. Select board: Tools → Board → ESP32 Dev Module
3. Select port: Tools → Port → COM# (Windows) or /dev/tty.* (Mac/Linux)
4. Click Upload button

### Step 5: Monitor Serial Output

- Open Serial Monitor (Tools → Serial Monitor)
- Set baud rate to 115200
- You should see:
  - WiFi connection status
  - Firebase initialization
  - RTC time
  - Schedule sync messages

### Step 6: Set RTC Time

If the RTC shows incorrect time:
```cpp
// In setup(), add this line temporarily:
rtc.adjust(DateTime(2025, 11, 15, 14, 30, 0));  // YYYY, MM, DD, HH, MM, SS

// Upload, then remove this line and upload again
```

---

## 🗄️ Firebase Database Structure

```json
{
  "devices": {
    "MB001234": {
      "nickname": "Mom's Pillbox",
      "schedule": {
        "morning": "08:00",
        "afternoon": "13:00",
        "night": "20:00"
      },
      "status": {
        "online": true,
        "lastDispensed": "2025-11-15T08:00:00",
        "lastSyncTime": "2025-11-15T14:30:00",
        "batteryLevel": 85
      },
      "alerts": {
        "missedDose": false,
        "deviceOffline": false,
        "lowBattery": false
      },
      "addedDate": "2025-11-15T10:00:00"
    }
  },
  "users": {
    "userId123": {
      "devices": ["MB001234", "MB005678"]
    }
  }
}
```

---

## 🔐 Security Rules

The Firebase Security Rules ensure:
- Users can only access their own devices
- Device writes require ownership verification
- Schedule times are validated for correct format
- Status updates have proper data types

Rules are in `firebase_database_rules.json`

---

## 🔔 Push Notifications

### Server-Side (Cloud Functions)

To send automatic notifications, create Cloud Functions:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Send notification when pill is dispensed
exports.onPillDispensed = functions.database
  .ref('/devices/{deviceId}/status/lastDispensed')
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    
    // Get device info
    const deviceSnap = await admin.database()
      .ref(`/devices/${deviceId}`)
      .once('value');
    
    const device = deviceSnap.val();
    
    // Send notification to guardians
    const message = {
      notification: {
        title: 'Pill Dispensed',
        body: `${device.nickname} - Medication taken successfully`
      },
      data: {
        type: 'pill_dispensed',
        deviceId: deviceId
      },
      topic: `device_${deviceId}`
    };
    
    return admin.messaging().send(message);
  });

// Send notification for missed dose
exports.onMissedDose = functions.database
  .ref('/devices/{deviceId}/alerts/missedDose')
  .onUpdate(async (change, context) => {
    if (change.after.val() === true) {
      const deviceId = context.params.deviceId;
      
      const deviceSnap = await admin.database()
        .ref(`/devices/${deviceId}`)
        .once('value');
      
      const device = deviceSnap.val();
      
      const message = {
        notification: {
          title: '⚠️ Missed Medication',
          body: `${device.nickname} - Medication not taken!`
        },
        data: {
          type: 'missed_dose',
          deviceId: deviceId
        },
        topic: `device_${deviceId}`,
        android: {
          priority: 'high'
        }
      };
      
      return admin.messaging().send(message);
    }
  });
```

---

## 📊 Testing Checklist

### App Testing
- [ ] Register new guardian account
- [ ] Login with credentials
- [ ] Add device with valid ID
- [ ] View device status (online/offline)
- [ ] Edit medication schedule
- [ ] Trigger manual dispense
- [ ] View last dispensed time
- [ ] Receive push notifications
- [ ] Silence alarm remotely

### ESP32 Testing
- [ ] WiFi connection successful
- [ ] Firebase sync working
- [ ] RTC showing correct time
- [ ] LEDs turn on at scheduled times
- [ ] Buzzer sounds alarm
- [ ] Button press stops alarm
- [ ] Motor rotates correctly
- [ ] Missed dose alert sent after timeout
- [ ] Manual dispense from app works

---

## 🐛 Troubleshooting

### App Issues

**"Firebase not initialized"**
- Run `flutterfire configure` again
- Check `firebase_options.dart` exists
- Verify `google-services.json` is in `android/app/`

**"Permission denied" in Firebase**
- Check Security Rules are deployed
- Verify user is authenticated
- Ensure device is linked to user

**"No devices showing"**
- Check device ID matches exactly
- Verify device is linked in Firebase Console
- Check network connection

### ESP32 Issues

**"WiFi not connecting"**
- Verify SSID and password
- Check WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Move closer to router

**"Firebase connection failed"**
- Check API_KEY and DATABASE_URL
- Verify device has internet access
- Check Firebase Console for errors

**"RTC time incorrect"**
- Replace CR2032 battery in DS3231
- Set time using `rtc.adjust()`
- Verify I2C connections

**"Motor not moving"**
- Check power supply (12V 2A minimum)
- Verify stepper driver connections
- Test with simple motor test code
- Check ENABLE pin (should be LOW to enable)

**"Alarm not triggering"**
- Check RTC time is correct
- Verify schedule is synced from Firebase
- Check Serial Monitor for time comparisons

---

## 🎯 Future Enhancements

- [ ] Add barcode/QR code scanning for easy device linking
- [ ] Implement medication history graphs
- [ ] Add family member sharing
- [ ] Support for multiple alarms per day
- [ ] Voice reminders
- [ ] Integration with health apps
- [ ] Battery level monitoring
- [ ] Temperature/humidity sensors
- [ ] Pill counting sensors
- [ ] Multi-language support

---

## 📄 License

This project is for educational purposes. Feel free to modify and use for your needs.

---

## 👥 Support

For issues or questions:
1. Check troubleshooting section
2. Review Firebase Console logs
3. Check ESP32 Serial Monitor output
4. Verify all connections and configurations

---

## 🙏 Acknowledgments

- Firebase for backend services
- Flutter team for the amazing framework
- Adafruit for RTC library
- Mobizt for Firebase ESP Client

---

**Built with ❤️ for elderly care**
