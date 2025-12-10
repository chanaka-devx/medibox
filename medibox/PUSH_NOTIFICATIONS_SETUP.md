# Push Notifications Setup Guide

## Overview
This guide explains how to set up WhatsApp-style push notifications for the MediBox app. When the patient presses the button after an alarm triggers, the guardian receives an instant notification.

## Architecture

```
ESP32 Device          Firebase RTDB          Cloud Functions          Guardian App
     │                      │                       │                        │
     │  1. Button Pressed   │                       │                        │
     │─────────────────────>│                       │                        │
     │   (Set notification  │  2. Trigger detected  │                        │
     │    trigger = true)   │──────────────────────>│                        │
     │                      │                       │  3. Send FCM message   │
     │                      │                       │───────────────────────>│
     │                      │                       │                        │
     │                      │  4. Reset trigger     │  5. Display notification│
     │                      │<──────────────────────│                        │
```

## Setup Steps

### 1. Firebase Cloud Functions Setup

#### Install Firebase Tools
```bash
npm install -g firebase-tools
```

#### Login to Firebase
```bash
firebase login
```

#### Initialize Cloud Functions
```bash
cd medibox
firebase init functions
```

Select:
- Use an existing project (select your MediBox project)
- Language: JavaScript or TypeScript
- ESLint: Yes (recommended)
- Install dependencies: Yes

#### Create Cloud Function

Create `functions/index.js` with the following code:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Listen for notification triggers in any device
exports.sendMedicationNotification = functions.database
  .ref('/devices/{deviceId}/notificationTrigger')
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const triggerValue = change.after.val();
    
    // Only proceed if trigger is set to true
    if (!triggerValue || triggerValue !== true) {
      return null;
    }

    try {
      // Get device data
      const deviceSnapshot = await admin.database()
        .ref(`/devices/${deviceId}`)
        .once('value');
      
      const device = deviceSnapshot.val();
      
      if (!device || !device.guardianId) {
        console.log('No guardian found for device:', deviceId);
        return null;
      }

      // Get guardian's FCM token
      const userSnapshot = await admin.database()
        .ref(`/users/${device.guardianId}/fcmToken`)
        .once('value');
      
      const fcmToken = userSnapshot.val();
      
      if (!fcmToken) {
        console.log('No FCM token found for guardian:', device.guardianId);
        return null;
      }

      // Prepare notification message
      const message = {
        notification: {
          title: '💊 Medication Taken',
          body: `${device.patientName || 'Patient'} has taken their medication`,
        },
        data: {
          deviceId: deviceId,
          type: 'medication_taken',
          timestamp: Date.now().toString(),
        },
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'medication_alerts',
            priority: 'high',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send notification
      const response = await admin.messaging().send(message);
      console.log('Notification sent successfully:', response);

      // Reset the trigger
      await admin.database()
        .ref(`/devices/${deviceId}/notificationTrigger`)
        .set(false);

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Reset trigger even on error
      await admin.database()
        .ref(`/devices/${deviceId}/notificationTrigger`)
        .set(false);
      
      return null;
    }
  });

// Optional: Listen for missed medication (alarm timeout)
exports.sendMissedMedicationAlert = functions.database
  .ref('/devices/{deviceId}/lastAlarmTime')
  .onUpdate(async (change, context) => {
    const deviceId = context.params.deviceId;
    const newAlarmTime = change.after.val();
    
    if (!newAlarmTime) return null;

    // Wait 5 minutes to check if medication was taken
    await new Promise(resolve => setTimeout(resolve, 5 * 60 * 1000));

    try {
      // Check if alarm is still active
      const deviceSnapshot = await admin.database()
        .ref(`/devices/${deviceId}`)
        .once('value');
      
      const device = deviceSnapshot.val();
      
      if (!device || !device.alarmActive) {
        // Alarm was dismissed, medication was taken
        return null;
      }

      // Alarm still active - send missed medication alert
      if (!device.guardianId) return null;

      const userSnapshot = await admin.database()
        .ref(`/users/${device.guardianId}/fcmToken`)
        .once('value');
      
      const fcmToken = userSnapshot.val();
      if (!fcmToken) return null;

      const message = {
        notification: {
          title: '⚠️ Missed Medication',
          body: `${device.patientName || 'Patient'} has not taken their medication`,
        },
        data: {
          deviceId: deviceId,
          type: 'missed_medication',
          timestamp: Date.now().toString(),
        },
        token: fcmToken,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'medication_alerts',
            priority: 'max',
          },
        },
      };

      await admin.messaging().send(message);
      return true;
    } catch (error) {
      console.error('Error sending missed medication alert:', error);
      return null;
    }
  });
```

#### Deploy Cloud Functions
```bash
firebase deploy --only functions
```

### 2. Update Firebase Database Rules

Add these rules to allow Cloud Functions to write:

```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": "auth != null && (root.child('devices').child($deviceId).child('guardianId').val() == auth.uid)",
        ".write": "auth != null && (root.child('devices').child($deviceId).child('guardianId').val() == auth.uid)",
        "notificationTrigger": {
          ".write": "true"
        },
        "lastAlarmTime": {
          ".write": "true"
        }
      }
    },
    "users": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        ".write": "auth != null && auth.uid == $userId"
      }
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only database
```

### 3. Android Setup

#### Update AndroidManifest.xml
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <application>
        <!-- Notification Icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        
        <!-- Notification Color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
        
        <!-- Notification Channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="medication_alerts" />
    </application>
</manifest>
```

#### Create notification icon
Place a white icon (transparent background) at:
- `android/app/src/main/res/drawable/ic_notification.png`

Or create `android/app/src/main/res/drawable/ic_notification.xml`:
```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4M11,7V13H17V15H9V7H11Z"/>
</vector>
```

#### Create notification color
Create `android/app/src/main/res/values/colors.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#4CAF50</color>
</resources>
```

### 4. iOS Setup

#### Update Info.plist
Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

#### Enable Push Notifications
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" (check "Remote notifications")

#### Request notification permissions
The app will request permissions on first launch.

### 5. Testing

#### Test on Android
```bash
flutter run
```

#### Test notification flow:
1. Login to the app
2. Link a device
3. Trigger an alarm on ESP32 (set schedule or use manual test)
4. Press the button on ESP32
5. Guardian should receive notification

#### View Cloud Function logs:
```bash
firebase functions:log
```

#### Debug FCM token:
Check Firebase Console → Realtime Database → users → {userId} → fcmToken

### 6. Troubleshooting

#### No notification received
- Check FCM token is saved in Firebase Database
- Check Cloud Function logs: `firebase functions:log`
- Verify `google-services.json` is up to date
- Check notification permissions in device settings
- Ensure app is not in battery optimization mode

#### Notification not showing when app is closed
- Android: Check if "Show notifications" is enabled
- iOS: Check notification permissions in Settings
- Verify Background Modes are enabled

#### ESP32 not triggering notification
- Check Serial Monitor for Firebase write confirmation
- Verify device is online
- Check notificationTrigger value in Firebase Console

## Notification Types

The app supports these notification types:

1. **Medication Taken** (`medication_taken`)
   - Triggered when button pressed after alarm
   - Shows patient has taken medication

2. **Missed Medication** (`missed_medication`) - Optional
   - Triggered if alarm active for 5+ minutes
   - Alerts guardian of missed dose

3. **Device Offline** (Future enhancement)
   - Alert when device goes offline for extended period

4. **Low Battery** (Future enhancement)
   - Alert when battery below threshold

## Production Considerations

1. **Rate Limiting**: Cloud Functions have quotas
2. **Cost**: FCM is free, but Cloud Functions have limits
3. **Reliability**: Consider retry logic for failed notifications
4. **Privacy**: Ensure HIPAA compliance if needed
5. **Testing**: Test with multiple devices and guardians

## Next Steps

- [ ] Deploy Cloud Functions
- [ ] Test notifications on Android and iOS
- [ ] Add custom notification sounds
- [ ] Implement notification history
- [ ] Add notification preferences in app settings

---

**For support, check Firebase Console logs and ESP32 Serial Monitor.**
