const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// SMSAPI.LK Configuration
const SMS_API_URL = "https://dashboard.smsapi.lk/api/v3/sms/send";
const SMS_API_TOKEN = functions.config().smsapi?.token || "218|KAbOqPZjfTTbRurszfFUAuRtDXCfeeSYlYb7Tsl1";
const SMS_SENDER_ID = "MediBox";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to send FCM V1 notifications
 * Called by ESP32 device when medication events occur
 *
 * HTTP Endpoint: POST /sendNotification
 *
 * Request Body:
 * {
 *   "deviceId": "MEDIBOX001",
 *   "title": "Medicine Taken ✓",
 *   "body": "The patient has taken their medication on time.",
 *   "type": "pill_taken"
 * }
 */
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS for all origins (you can restrict this later)
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  // Handle preflight request
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const {deviceId, title, body, type} = req.body;

    // Validate required fields
    if (!deviceId || !title || !body || !type) {
      res.status(400).json({
        success: false,
        error: "Missing required fields: deviceId, title, body, type",
      });
      return;
    }

    // Get the guardian's FCM token from Firebase Database
    const deviceRef = admin.database().ref(`devices/${deviceId}`);
    const snapshot = await deviceRef.once("value");

    if (!snapshot.exists()) {
      res.status(404).json({
        success: false,
        error: `Device ${deviceId} not found`,
      });
      return;
    }

    const deviceData = snapshot.val();
    const fcmToken = deviceData.guardianFcmToken;

    if (!fcmToken) {
      res.status(400).json({
        success: false,
        error: "No FCM token found for this device",
      });
      return;
    }

    // Build FCM message using V1 API format
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
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "medibox_alerts",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // Send the message using Firebase Admin SDK
    const response = await admin.messaging().send(message);

    console.log("Successfully sent notification:", response);

    // Get guardian phone number from user who owns this device
    const guardianPhone = await getGuardianPhone(deviceId);
    if (guardianPhone) {
      await sendSMS(guardianPhone, title, body);
    }

    // Return success response
    res.status(200).json({
      success: true,
      messageId: response,
      sentTo: fcmToken.substring(0, 20) + "...",
    });
  } catch (error) {
    console.error("Error sending notification:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Alternative: Database trigger function (automatic)
 * Listens to database changes and sends notifications automatically
 *
 * Triggers when: /devices/{deviceId}/notificationTrigger is updated
 */
exports.onNotificationTrigger = functions.database
    .ref("/devices/{deviceId}/notificationTrigger")
    .onUpdate(async (change, context) => {
      const deviceId = context.params.deviceId;
      const newData = change.after.val();

      // Check if triggered
      if (!newData || !newData.triggered) {
        return null;
      }

      try {
        // Get device data and FCM token
        const deviceRef = admin.database().ref(`devices/${deviceId}`);
        const snapshot = await deviceRef.once("value");
        const deviceData = snapshot.val();
        const fcmToken = deviceData.guardianFcmToken;

        if (!fcmToken) {
          console.error(`No FCM token for device ${deviceId}`);
          return null;
        }

        // Send notification
        const message = {
          token: fcmToken,
          notification: {
            title: "Medicine Taken ✓",
            body: "The patient has taken their medication on time.",
          },
          data: {
            deviceId: deviceId,
            type: "pill_taken",
            timestamp: (newData.timestamp || Date.now()).toString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "medibox_alerts",
              sound: "default",
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log("Auto-notification sent:", response);

        // Get guardian phone number from user who owns this device
        const guardianPhone = await getGuardianPhone(deviceId);
        if (guardianPhone) {
          await sendSMS(guardianPhone, "Medicine Taken ✓", "The patient has taken their medication on time.");
        }

        // Reset trigger after sending
        await change.after.ref.update({triggered: false});

        return response;
      } catch (error) {
        console.error("Error in auto-notification:", error);
        return null;
      }
    });

/**
 * Database trigger for missed dose alerts
 *
 * Triggers when: /devices/{deviceId}/missedDose is updated
 */
exports.onMissedDose = functions.database
    .ref("/devices/{deviceId}/missedDose")
    .onUpdate(async (change, context) => {
      const deviceId = context.params.deviceId;
      const newData = change.after.val();

      if (!newData || !newData.missed) {
        return null;
      }

      try {
        const deviceRef = admin.database().ref(`devices/${deviceId}`);
        const snapshot = await deviceRef.once("value");
        const deviceData = snapshot.val();
        const fcmToken = deviceData.guardianFcmToken;

        if (!fcmToken) {
          console.error(`No FCM token for device ${deviceId}`);
          return null;
        }

        const compartment = newData.compartment || "scheduled";

        const message = {
          token: fcmToken,
          notification: {
            title: "Medicine Not Taken ⚠️",
            body: `Missed ${compartment} medication`,
          },
          data: {
            deviceId: deviceId,
            type: "missed_dose",
            compartment: compartment,
            timestamp: newData.timestamp || Date.now().toString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "medibox_alerts",
              sound: "default",
              priority: "max",
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log("Missed dose alert sent:", response);

        // Get guardian phone number from user who owns this device
        const guardianPhone = await getGuardianPhone(deviceId);
        if (guardianPhone) {
          await sendSMS(guardianPhone, "Medicine Not Taken ⚠️", `Missed ${compartment} medication`);
        }

        await change.after.ref.update({missed: false});

        return response;
      } catch (error) {
        console.error("Error sending missed dose alert:", error);
        return null;
      }
    });

/**
 * Helper function to get guardian phone number from user who owns the device
 */
async function getGuardianPhone(deviceId) {
  try {
    // Get all users
    const usersRef = admin.database().ref("users");
    const usersSnapshot = await usersRef.once("value");
    
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
        const phoneNumber = userData.phoneNumber;
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
 * Helper function to send SMS via SMSAPI.LK
 */
async function sendSMS(phoneNumber, title, body) {
  if (SMS_API_TOKEN === "218|KAbOqPZjfTTbRurszfFUAuRtDXCfeeSYlYb7Tsl1 ") {
    console.log("SMS API token not configured - skipping SMS");
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
      console.log(`SMS sent to ${phoneNumber}: ${smsMessage}`);
    } else {
      console.error(`SMS failed: ${response.data.message}`);
    }
  } catch (error) {
    console.error("Error sending SMS:", error.response?.data?.message || error.message);
  }
}
