# Firebase Cloud Messaging (FCM) V1 API Notification Setup

## ✅ What's Already Done

1. **Flutter App (Complete)**
   - FCM service initialized on login
   - FCM device token automatically saved to user profile and all devices
   - OAuth 2.0 access token generated and saved for ESP32
   - Token saved as `guardianFcmToken` in Firebase Database
   - Access token saved as `fcmAccessToken` (auto-refreshes every 50 minutes)
   - Background message handler configured
   - Local notification display working

2. **ESP32 Firmware (Complete)**
   - FCM V1 API functions added: `sendFCMNotification()` and `loadGuardianFcmToken()`
   - Token and access token loading integrated into setup
   - Pill taken notification sends FCM V1 push
   - Missed dose notification sends FCM V1 push
   - Still writes to database for notification history

## 🔧 What You Need to Do

### Step 1: Update Firebase Project ID in ESP32

Open `esp32_firmware/medibox_esp32_firebase.ino` and find line ~32:

```cpp
#define FIREBASE_PROJECT_ID "medibox-foe"
```

**Verify this matches your Firebase project ID** (you can find it in Firebase Console → Project Settings)

### Step 2: Enable Firebase Cloud Messaging API (V1)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (`medibox-foe`)
3. Go to **APIs & Services** → **Library**
4. Search for **"Firebase Cloud Messaging API"**
5. Click **Enable** (if not already enabled)

⚠️ **Note**: The old "Cloud Messaging API (Legacy)" is deprecated. We're using the new V1 API which requires OAuth 2.0 tokens instead of server keys.

### Step 3: Upload Firmware to ESP32

1. Open Arduino IDE
2. Open `medibox_esp32_firebase.ino`
3. Select your ESP32 board and port
4. Click **Upload**

### Step 4: Test Background Notifications

1. **Open the MediBox app** on your phone
2. **Login** to your account
3. Wait a few seconds for the FCM tokens to be saved (check logs)
4. **Close the app completely** (swipe away from recent apps)
5. **Trigger an alarm** on the ESP32
6. You should receive a **push notification** even though the app is closed!

## 📋 How It Works

### FCM V1 API Architecture:
1. **Flutter app** generates two tokens:
   - **Device token**: Unique identifier for this phone
   - **OAuth access token**: Authorization for sending notifications
2. Both tokens are saved to Firebase Database under each device
3. **ESP32** loads both tokens on startup
4. ESP32 uses the access token to authenticate with FCM V1 API
5. ESP32 sends notifications to the device token

### When App is OPEN:
1. ESP32 sends FCM V1 push → Phone receives instantly
2. ESP32 writes to database → App listens → Shows local notification
3. You may get two notifications (FCM + local) - this is normal for foreground

### When App is CLOSED:
1. ESP32 sends FCM V1 push → Phone receives instantly ✅
2. ESP32 writes to database → App isn't listening (closed)
3. You get **one notification** (FCM only) - perfect!

### OAuth Token Refresh:
- Access tokens expire after **1 hour**
- Flutter app automatically refreshes every **50 minutes**
- ESP32 reloads token from database periodically
- No manual intervention needed

## 🐛 Troubleshooting

### No Notifications When App is Closed

**Check 1: FCM Tokens in Database**
1. Open Firebase Console → Realtime Database
2. Navigate to `devices/MEDIBOX001/`
3. Verify `guardianFcmToken` exists (long string)
4. Verify `fcmAccessToken` exists (very long JWT string)

**Check 2: ESP32 Serial Monitor**
1. Open Serial Monitor in Arduino IDE
2. Look for on startup:
   - `✓ Guardian FCM token loaded`
   - `✓ FCM access token loaded`
3. When alarm triggers:
   - `Sending FCM V1 notification...`
   - `✓ FCM notification sent successfully`

**Check 3: FCM API Enabled**
1. Go to Google Cloud Console
2. APIs & Services → Enabled APIs
3. Verify "Firebase Cloud Messaging API" is listed

**Check 4: Phone Settings**
1. Settings → Apps → MediBox
2. Check **Notifications** are enabled
3. Check **Battery optimization** is OFF

### Getting "FCM error: 401" (Unauthorized)

**Possible causes:**
- Access token expired → Wait 1 minute for app to refresh and ESP32 to reload
- Access token not loaded → Check Serial Monitor for "✓ FCM access token loaded"
- FCM API not enabled → Enable in Google Cloud Console

### Getting "FCM error: 400" (Bad Request)

**Possible causes:**
- Wrong Firebase project ID → Check `FIREBASE_PROJECT_ID` in ESP32 code
- Invalid device token → Check `guardianFcmToken` in database
- Malformed JSON payload → Check ESP32 Serial Monitor for details

### Getting "FCM error: 404" (Not Found)

**Possible causes:**
- Wrong Firebase project ID in ESP32 code
- Typo in project ID → Double check against Firebase Console

### App Doesn't Generate Tokens

**Fix:**
1. Make sure you're logged in to the app
2. Check device has internet connection
3. Reinstall the app if necessary
4. Grant notification permissions when prompted
5. Check Flutter logs: `flutter logs` or Android Studio Logcat

## 📊 Expected Serial Monitor Output

```
WiFi Connected!
NTP Time Synced
Firebase Connected Successfully
✓ Guardian FCM token loaded
✓ FCM access token loaded
System Ready...

[When alarm triggers]
✓ Motor rotation completed
Triggering guardian notification...
Sending FCM V1 notification...
✓ FCM notification sent successfully
✓ Notification trigger sent to database
```

## 🔄 Token Refresh Behavior

### Automatic Refresh:
- **Access tokens** expire after 1 hour
- Flutter app refreshes them every **50 minutes**
- Updated tokens are saved to Firebase Database
- ESP32 reloads on next alarm trigger

### Manual Refresh:
If you need to force a token refresh:
1. Open the MediBox app
2. Wait 10 seconds
3. Close and reopen the app
4. Tokens will be regenerated and saved

## 🆚 Legacy API vs V1 API

| Feature | Legacy API | V1 API (Current) |
|---------|-----------|------------------|
| **Authentication** | Server Key | OAuth 2.0 Token |
| **Endpoint** | `/fcm/send` | `/v1/projects/{project}/messages:send` |
| **Token Type** | Static | Expires hourly |
| **Status** | ⛔ Deprecated | ✅ Active |
| **Security** | Lower | Higher |

## 💡 Tips for Production

1. **Monitor token expiration**: Check Firebase Console logs
2. **Handle token refresh failures**: Add retry logic in Flutter
3. **Test in different states**: Foreground, background, terminated
4. **Battery optimization**: Ensure app is whitelisted
5. **Network connectivity**: Handle offline scenarios gracefully

## 🔐 Security Notes

- **Never commit** the FCM Server Key to public repositories
- Consider using Firebase Admin SDK with Cloud Functions for production
- Current approach (ESP32 direct send) is simpler but less secure

## 🎯 Next Steps

After notifications work:

1. **Change App Icon**: Add your icon to `assets/icon/app_icon.png` and run `dart run flutter_launcher_icons`
2. **Test Missed Dose**: Let an alarm go off without pressing the button
3. **Test Offline**: Disconnect ESP32 WiFi to test offline notification
4. **Customize**: Adjust notification text, sounds, or vibration patterns

## ❓ Need Help?

If notifications still don't work after following all steps:

1. Share the **ESP32 Serial Monitor output** when alarm triggers
2. Check if `guardianFcmToken` exists in Firebase Database
3. Verify notification permissions in phone settings
4. Try rebooting both ESP32 and phone
