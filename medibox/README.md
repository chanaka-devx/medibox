# 💊 MediBox - Smart Medical Pillbox System

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-RTDB-orange?logo=firebase" alt="Firebase">
  <img src="https://img.shields.io/badge/ESP32-IoT-green?logo=espressif" alt="ESP32">
  <img src="https://img.shields.io/badge/License-Educational-yellow" alt="License">
</p>

A comprehensive cloud-connected smart medical pillbox system designed for elderly users who need medication reminders. This IoT solution combines a Flutter mobile app for guardians with an ESP32-based smart device for automatic pill dispensing.

## 🌟 Features

### 📱 Mobile App (Guardian)
- **User Authentication** - Secure login/register with Firebase
- **Multi-Device Support** - Manage multiple pillboxes from one account
- **Real-Time Monitoring** - Live device status, battery level, online/offline
- **Schedule Management** - Set medication times (Morning, Afternoon, Night)
- **Remote Control** - Trigger manual dispense, silence alarms
- **Push Notifications** - Alerts for missed doses, device offline
- **Beautiful UI** - Modern Material Design 3 with intuitive navigation

### 🤖 ESP32 Smart Device
- **Automatic Dispensing** - Rotates compartments at scheduled times
- **Visual & Audio Alerts** - LEDs and buzzer for medication reminders
- **Precise Timing** - DS3231 RTC for accurate schedule keeping
- **Cloud Connected** - Real-time sync with Firebase
- **Button Confirmation** - User presses button to confirm medication taken
- **Missed Dose Detection** - Alerts guardian if medication not taken within 5 minutes

## 🏗️ System Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  Flutter App    │◄────►│  Firebase       │◄────►│  ESP32 Device   │
│  (Guardian)     │ HTTPS │  (Cloud)        │ HTTPS│  (Pillbox)      │
│                 │      │                 │      │                 │
│  • Monitoring   │      │  • Auth         │      │  • WiFi         │
│  • Control      │      │  • RTDB         │      │  • RTC          │
│  • Scheduling   │      │  • FCM          │      │  • Motor        │
│  • Alerts       │      │  • Rules        │      │  • Sensors      │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.10+
- Firebase account
- Android Studio / Xcode
- ESP32 dev board
- Arduino IDE

### 1. Clone Repository
```bash
git clone https://github.com/chanaka-devx/medibox.git
cd medibox
```

### 2. Setup Flutter App
```bash
flutter pub get
flutterfire configure
flutter run
```

### 3. Setup ESP32
1. Open `esp32_firmware/medibox_esp32.ino`
2. Update WiFi and Firebase credentials
3. Upload to ESP32

📚 **[Complete Setup Guide](SETUP_GUIDE.md)** - Detailed step-by-step instructions

## 📁 Project Structure

```
medibox/
├── lib/                      # Flutter source code
│   ├── models/              # Data models
│   ├── services/            # Business logic
│   ├── providers/           # State management
│   ├── screens/             # UI screens
│   └── widgets/             # Reusable components
├── esp32_firmware/          # ESP32 Arduino code
├── firebase_database_rules.json
├── SETUP_GUIDE.md          # Complete setup instructions
├── PROJECT_STRUCTURE.md    # Architecture details
└── IMPLEMENTATION_SUMMARY.md
```

## 🎯 Key Technologies

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Backend**: Firebase (Auth, RTDB, FCM)
- **Hardware**: ESP32, DS3231 RTC, Stepper Motor
- **Communication**: HTTPS, WiFi

## 📱 Screenshots

### Mobile App
- Login & Registration
- Device Dashboard
- Schedule Editor
- Device Details & Controls
- Real-time Monitoring

### Hardware
- ESP32 Pillbox with 3 compartments
- LED indicators
- Button for confirmation
- Stepper motor mechanism

## 🔐 Security

- ✅ Firebase Authentication
- ✅ Database Security Rules
- ✅ HTTPS/TLS encryption
- ✅ User-device ownership validation
- ✅ Data validation & type checking

## 🧪 Testing

```bash
# Run Flutter tests
flutter test

# Build release
flutter build apk --release
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete testing checklist.

## 📖 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup instructions
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Architecture & code organization
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - What's been built

## 🤝 Contributing

This is an educational project. Feel free to fork and customize for your needs!

## 📄 License

Educational use. See LICENSE file for details.

## 🙏 Acknowledgments

- Firebase for backend services
- Flutter team for the amazing framework
- Adafruit for RTC library
- Mobizt for Firebase ESP Client

## 📧 Contact

**Developer**: Chanaka
**GitHub**: [@chanaka-devx](https://github.com/chanaka-devx)

---

**Built with ❤️ for elderly care and better health outcomes**
