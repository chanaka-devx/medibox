# SMS Notifications Setup Guide

## Overview

MediBox now sends **automatic SMS alerts** to guardians when:
- ✅ **Pills are taken** - Confirmation message
- ⚠️ **Pills are missed** - Alert message

SMS notifications work **24/7** using **SMSAPI.LK** service integrated directly into the Flutter app.

---

## How It Works

```
ESP32 Device → Firebase Database → Flutter SMS Service → SMSAPI.LK → Guardian's Phone
```

1. **ESP32** writes to Firebase when pills are taken/missed
2. **Flutter SMS Service** watches Firebase in real-time
3. **SMSAPI.LK** delivers SMS to guardian's phone number

---

## Setup Instructions

### 1. Configure Guardian Phone Number

1. Open **MediBox app**
2. Tap **Profile** (person icon in navigation bar)
3. Tap **Edit Profile** button
4. Enter **Guardian Phone Number** (e.g., `94784562377`)
   - Use country code without `+` symbol
   - Example: `94784562377` for Sri Lanka
5. Tap **Save Changes**

The phone number is stored at: `users/{userId}/notifications/phoneNumber`

---

### 2. SMS Service Configuration

The SMS service is **already configured** in the app with:

- **API URL**: `https://dashboard.smsapi.lk/api/v3/sms/send`
- **API Token**: Pre-configured in `lib/services/sms_service.dart`
- **Sender ID**: `MediBox`

**Location**: `lib/services/sms_service.dart` (lines 12-14)

---

### 3. Automatic SMS Messages

#### When Pills Are Taken ✓
```
Medicine Taken ✓: The patient has taken their medication on time.
```

#### When Pills Are Missed ⚠️
```
Medicine Not Taken ⚠️: Missed morning medication
```
*(Compartment name: morning/afternoon/night)*

---

## Technical Implementation

### SMS Service Architecture

The SMS service runs automatically when the app is open:

**File**: `lib/services/sms_service.dart`

**Key Features**:
- ✅ Real-time Firebase database listeners
- ✅ Automatic phone number lookup from user profile
- ✅ HTTP API integration with SMSAPI.LK
- ✅ Error handling and logging
- ✅ Singleton pattern for app-wide use

### Database Structure

```
users/
  {userId}/
    notifications/
      phoneNumber: "94784562377"  ← Guardian phone
    devices: ["MEDIBOX001"]

devices/
  MEDIBOX001/
    notificationTrigger:
      triggered: true  ← Pills taken
    missedDose:
      missed: true     ← Pills missed
      compartment: "morning"
```

### Integration Points

1. **main.dart** (Line 147-148)
   ```dart
   final SmsService _smsService = SmsService();
   await _smsService.initialize(userId);
   ```

2. **profile_screen.dart** (Line 109)
   ```dart
   await database.child('users/$_userId/notifications/phoneNumber').set(phoneNumber);
   ```

3. **sms_service.dart** (Line 30)
   ```dart
   await _setupDeviceListener(userId, deviceId);
   ```

---

## SMS Delivery Flow

### Step 1: Database Trigger
ESP32 writes to Firebase:
```json
{
  "devices": {
    "MEDIBOX001": {
      "notificationTrigger": {
        "triggered": true
      }
    }
  }
}
```

### Step 2: SMS Service Detects Change
```dart
triggerRef.onValue.listen((event) {
  if (data['triggered'] == true) {
    await _sendPillTakenSMS(userId, deviceId);
  }
});
```

### Step 3: Phone Number Lookup
```dart
final phoneNumber = await _database
    .ref('users/$userId/notifications/phoneNumber')
    .get();
```

### Step 4: SMS API Call
```dart
await http.post(
  Uri.parse('https://dashboard.smsapi.lk/api/v3/sms/send'),
  headers: {
    'Authorization': 'Bearer 218|KAb...',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'recipient': phoneNumber,
    'sender_id': 'MediBox',
    'message': 'Medicine Taken ✓: ...'
  }),
);
```

---

## Important Notes

### ⚠️ App Must Be Running

The SMS service works **only when the MediBox app is open** because:
- Flutter apps can't run background services on iOS/Android without additional setup
- Firebase listeners disconnect when app is closed

### 🔄 For 24/7 Operation

To receive SMS even when app is closed, you need to:

**Option 1: Use Firebase Cloud Functions (Requires Blaze Plan)**
- Deploy server-side functions
- Runs independently of mobile app
- See: `functions/index.js`

**Option 2: Use Background Service Plugin**
- Add `flutter_background_service` package
- Configure for Android/iOS background execution
- More complex setup required

---

## Testing

### 1. Test Pills Taken SMS

1. Open MediBox app
2. Trigger manual dispense from device screen
3. Press physical button on ESP32 within 10 seconds
4. Guardian should receive SMS: `Medicine Taken ✓: ...`

### 2. Test Missed Dose SMS

1. Open MediBox app
2. Wait for scheduled alarm time
3. Don't press button (let it timeout)
4. Guardian should receive SMS: `Medicine Not Taken ⚠️: ...`

### 3. Check Logs

Open VS Code Debug Console to see:
```
🔔 Initializing SMS Service...
📱 Found 1 devices
📡 Setting up listener for device: MEDIBOX001
✅ SMS Service initialized successfully
📬 Pill taken notification for MEDIBOX001
✅ SMS sent to 94784562377
   Message: Medicine Taken ✓: The patient has taken their medication on time.
```

---

## Troubleshooting

### SMS Not Sending

**Check 1: Phone Number Configured?**
```dart
// Profile screen → Guardian Phone Number field
// Should have value like: 94784562377
```

**Check 2: App Running?**
```
The SMS service only works when the app is open
```

**Check 3: SMS Service Initialized?**
```dart
// Check logs for:
✅ SMS Service initialized successfully
```

**Check 4: API Token Valid?**
```dart
// lib/services/sms_service.dart line 13
static const String _apiToken = '218|KAbOqPZjfTTbRurszfFUAuRtDXCfeeSYlYb7Tsl1';
```

### Wrong Phone Number Format

❌ **Incorrect**: `+94 78 456 2377` (spaces, plus sign)  
✅ **Correct**: `94784562377` (digits only with country code)

### SMS Quota Exceeded

SMSAPI.LK has limits per account:
- Check account balance
- Verify sender ID is approved
- Review API response errors

---

## Cost Information

**SMSAPI.LK Pricing** (as of 2024):
- Local SMS: ~LKR 0.25 per message
- International SMS: Varies by country

**Estimated Monthly Cost**:
- 3 doses/day × 30 days = 90 confirmations
- Assuming 10% missed = 9 alerts
- Total: ~100 SMS/month = ~LKR 25/month

---

## Security

### API Token Protection

✅ **Currently**: Token hardcoded in source code (OK for private app)  
⚠️ **For Production**: Move to environment variables or Firebase Remote Config

### Phone Number Privacy

- Phone numbers stored in Firebase Realtime Database
- Protected by Firebase security rules
- Only authenticated users can read/write own data

---

## Future Improvements

1. **Background Service**: Enable SMS when app is closed
2. **SMS Templates**: Customizable message formats
3. **Multi-Language**: Support Sinhala/Tamil messages
4. **Delivery Reports**: Track SMS delivery status
5. **Fallback Numbers**: Multiple guardian contacts

---

## Summary

✅ **What's Configured**:
- SMS service integrated into Flutter app
- SMSAPI.LK API configured with valid token
- Database listeners for pill events
- Phone number management in profile

⚠️ **Limitations**:
- Works only when app is open
- Requires guardian phone number in profile
- Depends on SMSAPI.LK service availability

🎯 **Next Steps**:
1. Enter guardian phone number in Profile
2. Keep app open for testing
3. Trigger pill events from device
4. Verify SMS delivery

For 24/7 operation, consider upgrading to Firebase Blaze plan and deploying Cloud Functions (see `functions/index.js`).
