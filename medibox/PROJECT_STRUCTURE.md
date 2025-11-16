# MediBox Project Structure

## 📁 Directory Overview

```
medibox/
├── lib/                          # Flutter source code
│   ├── main.dart                 # App entry point with providers
│   │
│   ├── models/                   # Data models
│   │   ├── device.dart          # Device model
│   │   ├── schedule.dart        # Schedule model (morning/afternoon/night)
│   │   ├── pillbox_status.dart  # Status model (online, battery, etc.)
│   │   └── alert.dart           # Alert model (missed dose, offline, etc.)
│   │
│   ├── services/                 # Business logic services
│   │   ├── auth_service.dart    # Firebase Authentication
│   │   ├── database_service.dart # Firebase Realtime Database CRUD
│   │   └── fcm_service.dart     # Firebase Cloud Messaging
│   │
│   ├── providers/                # State management (Provider pattern)
│   │   ├── auth_provider.dart   # Authentication state
│   │   └── device_provider.dart # Device list & operations state
│   │
│   ├── screens/                  # UI screens
│   │   ├── login_screen.dart           # Login page
│   │   ├── register_screen.dart        # Registration page
│   │   ├── forgot_password_screen.dart # Password reset
│   │   ├── home_screen.dart            # Dashboard with device list
│   │   ├── add_device_screen.dart      # Add new device
│   │   ├── device_details_screen.dart  # Device monitoring & control
│   │   └── schedule_screen.dart        # Edit medication schedule
│   │
│   └── widgets/                  # Reusable UI components
│       └── device_card.dart      # Device summary card widget
│
├── android/                      # Android-specific files
│   ├── app/
│   │   ├── build.gradle.kts     # With google-services plugin
│   │   └── google-services.json # Firebase config (not in git)
│   └── build.gradle.kts         # With google-services classpath
│
├── ios/                          # iOS-specific files
│   └── Runner/
│       └── GoogleService-Info.plist # Firebase config (not in git)
│
├── esp32_firmware/               # ESP32 Arduino code
│   └── medibox_esp32.ino        # Complete ESP32 firmware
│
├── firebase_database_rules.json # Security rules for Firebase RTDB
├── pubspec.yaml                  # Flutter dependencies
├── SETUP_GUIDE.md               # Complete setup instructions
└── README.md                     # Project overview

```

## 🔑 Key Files Explained

### **main.dart**
- Initializes Firebase
- Sets up Provider state management
- Configures app theme
- Implements auth wrapper (shows login or home based on auth state)
- Initializes FCM for notifications

### **Models**
All models include:
- `fromJson()` - Parse from Firebase
- `toJson()` - Convert to Firebase format
- `copyWith()` - Immutable updates
- Helper methods for business logic

### **Services**
Singleton-like services that handle:
- Firebase operations
- Network requests
- Error handling
- Data transformation

### **Providers**
ChangeNotifier-based state management:
- Listen to Firebase streams
- Manage loading states
- Handle errors
- Notify UI of changes

### **Screens**
Complete UI pages with:
- Form validation
- Error display
- Loading indicators
- Navigation logic

### **ESP32 Firmware**
Complete Arduino sketch with:
- WiFi connection
- Firebase sync
- RTC time management
- Motor control
- Alarm logic
- Button handling

## 🔄 Data Flow

### App → Firebase → ESP32
```
Guardian App                Firebase RTDB              ESP32 Device
    │                             │                          │
    │  1. Edit Schedule            │                          │
    │─────────────────────────────>│                          │
    │                              │  2. Schedule Updated     │
    │                              │─────────────────────────>│
    │                              │                          │
    │                              │  3. Sync Schedule        │
    │                              │<─────────────────────────│
    │  4. Refresh UI               │                          │
    │<─────────────────────────────│                          │
```

### ESP32 → Firebase → App
```
ESP32 Device               Firebase RTDB              Guardian App
    │                             │                          │
    │  1. Pill Dispensed           │                          │
    │─────────────────────────────>│                          │
    │                              │  2. Real-time Update     │
    │                              │─────────────────────────>│
    │                              │                          │
    │                              │  3. Send Notification    │
    │                              │─────────────────────────>│
    │                              │  4. UI Updates           │
```

## 🎨 App Architecture

```
┌─────────────────────────────────────────────────────┐
│                    main.dart                        │
│  (Firebase Init + MultiProvider + Theme)            │
└─────────────────┬───────────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    ┌────▼────┐      ┌────▼────┐
    │  Auth   │      │ Device  │
    │Provider │      │Provider │
    └────┬────┘      └────┬────┘
         │                │
    ┌────▼────┐      ┌────▼────┐
    │  Auth   │      │Database │
    │Service  │      │Service  │
    └────┬────┘      └────┬────┘
         │                │
         └────────┬────────┘
                  │
         ┌────────▼─────────┐
         │  Firebase Auth   │
         │  Firebase RTDB   │
         │  Firebase FCM    │
         └──────────────────┘
```

## 📱 Screen Navigation Flow

```
LoginScreen
    │
    ├─> RegisterScreen
    │       └─> LoginScreen
    │
    ├─> ForgotPasswordScreen
    │       └─> LoginScreen
    │
    └─> HomeScreen (after login)
            │
            ├─> AddDeviceScreen
            │       └─> HomeScreen
            │
            └─> DeviceDetailsScreen
                    │
                    └─> ScheduleScreen
                            └─> DeviceDetailsScreen
```

## 🔧 ESP32 Code Structure

```
medibox_esp32.ino
│
├─ Configuration Section
│   ├─ WiFi credentials
│   ├─ Firebase config
│   ├─ Device ID
│   └─ Pin definitions
│
├─ setup()
│   ├─ Initialize pins
│   ├─ Initialize RTC
│   ├─ Connect WiFi
│   ├─ Initialize Firebase
│   └─ Sync schedule
│
└─ loop()
    ├─ Check WiFi connection
    ├─ Periodic Firebase sync
    ├─ Update online status
    ├─ Check scheduled times
    ├─ Handle active alarm
    └─ Check manual commands
```

## 📊 State Management Pattern

### AuthProvider
```dart
AuthProvider
├─ user: User?
├─ isLoading: bool
├─ errorMessage: String?
│
├─ signIn()
├─ register()
├─ signOut()
└─ sendPasswordReset()
```

### DeviceProvider
```dart
DeviceProvider
├─ devices: List<Device>
├─ selectedDevice: Device?
├─ isLoading: bool
├─ errorMessage: String?
│
├─ loadDevices()
├─ linkDevice()
├─ unlinkDevice()
├─ updateSchedule()
├─ triggerManualDispense()
└─ silenceAlarm()
```

## 🔐 Security Layers

1. **Firebase Authentication**
   - Email/password verification
   - Secure token management

2. **Firebase Security Rules**
   - User can only access their devices
   - Data validation
   - Type checking

3. **Network Security**
   - HTTPS/TLS for all connections
   - Firebase SDK handles encryption

4. **ESP32 Security**
   - Device ID verification
   - Read-only access to Firebase
   - Local button override

## 📦 Dependencies

### Flutter (pubspec.yaml)
```yaml
dependencies:
  firebase_core: ^3.15.2        # Firebase core
  firebase_auth: ^5.7.0         # Authentication
  firebase_database: ^11.3.10   # Realtime Database
  firebase_messaging: ^15.0.4   # Push notifications
  provider: ^6.0.7              # State management
  intl: ^0.18.0                 # Date formatting
```

### ESP32 (Arduino Libraries)
```
Firebase ESP Client (v4.4.14+)
RTClib (v2.1.4+)
WiFi (built-in)
Wire (built-in)
```

## 🎯 Quick Command Reference

### Flutter Commands
```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release

# Build release iOS
flutter build ios --release

# Clean build
flutter clean
```

### Firebase Commands
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure

# Deploy rules
firebase deploy --only database
```

### ESP32 Commands
```bash
# Compile and upload (Arduino IDE)
Ctrl/Cmd + U

# Open Serial Monitor
Ctrl/Cmd + Shift + M
```

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Firebase not initialized" | Run `flutterfire configure` |
| Gradle sync failed | Check `google-services.json` location |
| ESP32 WiFi timeout | Verify SSID/password, use 2.4GHz |
| Motor not moving | Check power supply and connections |
| Time incorrect | Replace RTC battery, set time manually |
| No notifications | Enable FCM in Firebase Console |

## 📝 Development Workflow

1. **Setup** → Run `flutterfire configure`
2. **Develop** → Make changes to code
3. **Test** → `flutter run` for testing
4. **Debug** → Check logs and Firebase Console
5. **Build** → `flutter build` for release
6. **Deploy** → Upload ESP32 firmware
7. **Monitor** → Check Serial Monitor and app

---

**Happy Coding! 🚀**
