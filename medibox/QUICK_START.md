# ⚡ Quick Start Guide - MediBox

Get your MediBox system running in under 30 minutes!

## 🎯 Overview

This quick start assumes you:
- Have a Firebase account
- Have Flutter installed
- Have basic familiarity with Flutter/Firebase

**Time Required: ~30 minutes**

---

## 📱 Part 1: Flutter App (10 minutes)

### Step 1: Configure Firebase (5 mins)

1. **Create Firebase Project**
   ```
   Go to: https://console.firebase.google.com
   → Click "Add project"
   → Name: "medibox"
   → Disable Analytics (optional)
   → Click "Create project"
   ```

2. **Enable Services**
   ```
   Authentication → Email/Password → Enable
   Realtime Database → Create Database → Test mode
   Cloud Messaging → Already enabled ✓
   ```

3. **Add Android App**
   ```
   Project Settings → Add app → Android
   Package name: com.example.medibox
   Download google-services.json
   Place in: android/app/google-services.json
   ```

4. **Configure with FlutterFire**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure (auto-generates firebase_options.dart)
   flutterfire configure
   ```

5. **Deploy Security Rules**
   ```
   Go to: Realtime Database → Rules
   Copy contents from: firebase_database_rules.json
   Click "Publish"
   ```

### Step 2: Run the App (5 mins)

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Or build APK
flutter build apk --release
```

**That's it!** The app is ready. You should see the login screen.

---

## 🤖 Part 2: ESP32 Device (15 minutes)

### Step 1: Install Arduino IDE (if not installed)

```
Download from: https://www.arduino.cc/en/software
Install ESP32 board support (via Boards Manager)
```

### Step 2: Install Libraries (3 mins)

Open Arduino IDE → Tools → Manage Libraries

Install these:
- `Firebase ESP Client` by Mobizt
- `RTClib` by Adafruit

### Step 3: Configure Code (2 mins)

Open: `esp32_firmware/medibox_esp32.ino`

Update these lines:

```cpp
// Line 48-49: WiFi Credentials
#define WIFI_SSID "YOUR_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Line 51-53: Firebase Config
#define FIREBASE_HOST "YOUR_PROJECT_ID.firebaseio.com"
#define API_KEY "YOUR_API_KEY"  // From Firebase Project Settings
#define DATABASE_URL "https://YOUR_PROJECT_ID.firebaseio.com"

// Line 56: Device ID (must match app)
#define DEVICE_ID "MB001234"
```

**Where to find Firebase config:**
```
Firebase Console → Project Settings → Web App
Copy Web API Key and Project ID
```

### Step 4: Wire Hardware (5 mins)

**Minimum setup for testing:**
```
ESP32 Connections:
├─ DS3231 RTC
│  ├─ VCC  → 3.3V
│  ├─ GND  → GND
│  ├─ SDA  → GPIO21
│  └─ SCL  → GPIO22
│
├─ Buzzer
│  ├─ +    → GPIO32
│  └─ -    → GND
│
└─ Button
   ├─ One pin → GPIO33
   └─ Other   → GND
```

*(LED and motor optional for initial testing)*

### Step 5: Upload Code (2 mins)

```
1. Connect ESP32 via USB
2. Select: Tools → Board → ESP32 Dev Module
3. Select: Tools → Port → COM# (your port)
4. Click: Upload button
5. Wait for "Done uploading"
```

### Step 6: Monitor (3 mins)

```
1. Open: Tools → Serial Monitor
2. Set baud rate: 115200
3. Press ESP32 reset button
4. You should see:
   ✓ WiFi connecting...
   ✓ WiFi Connected!
   ✓ Firebase initialized
   ✓ RTC initialized
   ✓ Schedule synced
```

---

## ✅ Part 3: Test Everything (5 minutes)

### Test 1: Add Device in App

```
1. Open MediBox app
2. Register account (name, email, password)
3. Click "Add Device"
4. Enter Device ID: MB001234
5. Enter Nickname: Test Pillbox
6. Click "Add Device"
```

**Expected:** Device appears in list with status "Online" ✓

### Test 2: Set Schedule

```
1. Click on device card
2. Click schedule icon (top right)
3. Set times:
   Morning: 08:00
   Afternoon: 13:00
   Night: 20:00
4. Click "Save Schedule"
```

**Expected:** ESP32 Serial Monitor shows "Schedule synced" ✓

### Test 3: Manual Dispense

```
1. In device details screen
2. Under "Remote Control"
3. Click "Morning" button
4. Confirm dialog
```

**Expected:** 
- App shows "Dispense command sent" ✓
- ESP32 Serial Monitor shows "Manual dispense triggered" ✓

### Test 4: Alarm Test

```
1. Set current time as Morning schedule
   (e.g., if it's 14:25, set Morning to 14:25)
2. Wait 1 minute
3. Buzzer should sound
4. LED should turn on (if connected)
5. Press button on ESP32
```

**Expected:**
- Buzzer stops ✓
- App shows updated "Last dispensed" time ✓

---

## 🎉 Success!

If all tests passed, your MediBox system is fully operational!

## 🐛 Quick Troubleshooting

### App won't build
```bash
flutter clean
flutter pub get
flutter run
```

### ESP32 won't connect to WiFi
- Check SSID/password (case-sensitive)
- Verify WiFi is 2.4GHz (not 5GHz)
- Move ESP32 closer to router

### ESP32 can't connect to Firebase
- Verify API_KEY is correct
- Check DATABASE_URL format
- Test internet connection

### Device not showing in app
- Check Device ID matches exactly
- Verify device is online (Serial Monitor)
- Refresh app (pull down on home screen)

### Time is wrong
- RTC battery may be dead (replace CR2032)
- Set time manually in code:
  ```cpp
  rtc.adjust(DateTime(2025, 11, 15, 14, 30, 0));
  ```

---

## 📚 Next Steps

1. **Read Full Documentation**
   - [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed instructions
   - [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Code architecture

2. **Customize**
   - Change app colors in `main.dart`
   - Adjust alarm duration in ESP32 code
   - Add more LEDs or sensors

3. **Deploy**
   - Build release APK
   - Set up physical pillbox hardware
   - Configure Firebase production rules

---

## 💡 Pro Tips

- **Keep ESP32 connected to Serial Monitor** during testing to see real-time logs
- **Use test times close to current time** for quick alarm testing
- **Enable Firebase Debug View** in console for detailed logs
- **Test with different time zones** if deploying internationally

---

## 🆘 Need Help?

1. Check Serial Monitor output
2. Review Firebase Console logs
3. Verify all configurations match
4. Read troubleshooting section in SETUP_GUIDE.md

---

**You're all set! Happy building! 🚀**
