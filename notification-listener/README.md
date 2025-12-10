# MediBox Notification Listener

A local script to send FCM push notifications and SMS alerts when ESP32 updates the database.

## Why this script?

Cloud Functions require Firebase Blaze (paid) plan. This script provides the same functionality by running on your computer.

## Features

- ✅ FCM Push Notifications (to mobile app)
- ✅ SMS Alerts (to guardian's phone)
- ✅ Real-time database monitoring
- ✅ Automatic notification sending

## Setup

1. Install dependencies:
```bash
npm install
```

2. Download Firebase Admin SDK credentials:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json` in this directory

3. Configure SMS (optional):
   - Get API token from https://dashboard.smsapi.lk/
   - Update in `notificationListener.js`:
   ```javascript
   const SMS_API_TOKEN = "49|YOUR_ACTUAL_TOKEN_HERE";
   const SMS_SENDER_ID = "MediBox";
   ```

4. Add phone number to database:
   - Firebase Console → Database → devices/MEDIBOX001
   - Add field: `guardianPhone: "94771234567"`

5. Run the script:
```bash
npm start
```

## How it works

- Listens to Firebase Database changes in real-time
- When ESP32 updates `notificationTrigger` or `missedDose`
- Sends FCM push notification to app
- Sends SMS to guardian's phone (if configured)
- Works even when app is closed!

## Configuration

**SMS is optional.** If you don't configure SMS:
- Push notifications will still work
- Only SMS will be skipped

To disable SMS completely:
- Keep `SMS_API_TOKEN` as `"YOUR_SMSAPI_TOKEN_HERE"`
- Or remove `guardianPhone` from database

## For Production

Upgrade to Firebase Blaze plan and deploy Cloud Functions instead.

See `SMS_SETUP.md` for detailed SMS configuration.
