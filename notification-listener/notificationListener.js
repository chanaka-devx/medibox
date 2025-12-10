const admin = require("firebase-admin");
const axios = require("axios");
const serviceAccount = require("./serviceAccountKey.json");

// SMSAPI.LK Configuration
const SMS_API_URL = "https://dashboard.smsapi.lk/api/v3/sms/send";
const SMS_API_TOKEN = "218|KAbOqPZjfTTbRurszfFUAuRtDXCfeeSYlYb7Tsl1";
const SMS_SENDER_ID = "MediBox";

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://medibox-foe-default-rtdb.firebaseio.com",
});

const db = admin.database();

console.log("✅ Notification Listener Started");
console.log("📡 Listening for database changes...");

/**
 * Helper function to get guardian phone number from user who owns the device
 */
async function getGuardianPhone(deviceId) {
  try {
    // Get all users
    const usersSnapshot = await db.ref("users").once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("No users found in database");
      return null;
    }

    // Find user who has this device
    const users = usersSnapshot.val();
    for (const userId in users) {
      const userData = users[userId];
      
      // Check if user has devices list
      if (userData.devices && userData.devices.includes(deviceId)) {
        // Found the user who owns this device
        const phoneNumber = userData.notifications?.phoneNumber;
        if (phoneNumber) {
          console.log(`Found guardian phone for device ${deviceId}: ${phoneNumber}`);
          return phoneNumber;
        }
      }
    }

    console.log(`No guardian phone found for device ${deviceId}`);
    return null;
  } catch (error) {
    console.error("Error getting guardian phone:", error);
    return null;
  }
}

/**
 * Listen for pill taken notifications
 */
db.ref("/devices").on("child_changed", async (snapshot) => {
  const deviceId = snapshot.key;
  const deviceData = snapshot.val();

  // Check for notification trigger
  if (deviceData.notificationTrigger && deviceData.notificationTrigger.triggered) {
    console.log(`\n📬 Notification trigger detected for ${deviceId}`);
    
    // Get guardian phone from user who owns this device
    const guardianPhone = await getGuardianPhone(deviceId);
    
    await sendNotification(
        deviceId,
        deviceData.guardianFcmToken,
        guardianPhone,
        "Medicine Taken ✓",
        "The patient has taken their medication on time.",
        "pill_taken",
    );

    // Reset trigger
    await db.ref(`/devices/${deviceId}/notificationTrigger/triggered`).set(false);
  }

  // Check for missed dose
  if (deviceData.missedDose && deviceData.missedDose.missed) {
    const compartment = deviceData.missedDose.compartment || "scheduled";
    console.log(`\n⚠️  Missed dose detected for ${deviceId} (${compartment})`);
    
    // Get guardian phone from user who owns this device
    const guardianPhone = await getGuardianPhone(deviceId);
    
    await sendNotification(
        deviceId,
        deviceData.guardianFcmToken,
        guardianPhone,
        "Medicine Not Taken ⚠️",
        `Missed ${compartment} medication`,
        "missed_dose",
    );

    // Reset trigger
    await db.ref(`/devices/${deviceId}/missedDose/missed`).set(false);
  }
});

/**
 * Send FCM notification and SMS
 */
async function sendNotification(deviceId, fcmToken, guardianPhone, title, body, type) {
  // Send FCM push notification
  if (fcmToken) {
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        deviceId: deviceId,
        type: type,
        timestamp: Date.now().toString(),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "medibox_alerts",
          sound: "default",
          priority: "high",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`✅ FCM Notification sent: ${response}`);
      console.log(`   Title: ${title}`);
      console.log(`   Body: ${body}`);
    } catch (error) {
      console.error(`❌ Error sending FCM notification:`, error.message);
    }
  } else {
    console.error(`❌ No FCM token for device ${deviceId}`);
  }

  // Send SMS notification
  if (guardianPhone) {
    await sendSMS(guardianPhone, title, body);
  } else {
    console.log(`ℹ️  No phone number configured for SMS`);
  }
}

/**
 * Send SMS via SMSAPI.LK
 */
async function sendSMS(phoneNumber, title, body) {
  if (SMS_API_TOKEN === "YOUR_SMSAPI_TOKEN_HERE") {
    console.log(`⚠️  SMS API token not configured - skipping SMS`);
    return;
  }

  try {
    const smsMessage = `${title}: ${body}`;
    
    const response = await axios.post(
        SMS_API_URL,
        {
          recipient: phoneNumber,
          sender_id: SMS_SENDER_ID,
          type: "plain",
          message: smsMessage,
        },
        {
          headers: {
            "Authorization": `Bearer ${SMS_API_TOKEN}`,
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        },
    );

    if (response.data.status === "success") {
      console.log(`✅ SMS sent to ${phoneNumber}`);
      console.log(`   Message: ${smsMessage}`);
    } else {
      console.error(`❌ SMS failed: ${response.data.message}`);
    }
  } catch (error) {
    console.error(`❌ Error sending SMS:`, error.response?.data?.message || error.message);
  }
}

// Handle process termination
process.on("SIGINT", () => {
  console.log("\n\n👋 Shutting down notification listener...");
  process.exit(0);
});
