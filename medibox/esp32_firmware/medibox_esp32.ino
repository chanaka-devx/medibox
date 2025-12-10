/*
 * MediBox ESP32 Firmware
 * Smart Medical Pillbox System
 * 
 * Hardware Requirements:
 * - ESP32 Development Board
 * - DS3231 RTC Module (I2C)
 * - Stepper Motor + Driver (or Servo)
 * - Buzzer (Active or Passive)
 * - LEDs (3x - Morning/Afternoon/Night indicators)
 * - Push Button (for pill taking confirmation)
 * - Power Supply (5V/12V depending on motor)
 * 
 * Pin Configuration:
 * - DS3231 RTC: SDA=GPIO21, SCL=GPIO22
 * - Stepper Motor: STEP=GPIO25, DIR=GPIO26, ENABLE=GPIO27
 * - Buzzer: GPIO32
 * - LED Morning: GPIO12
 * - LED Afternoon: GPIO14
 * - LED Night: GPIO13
 * - Button: GPIO33 (with pull-up resistor)
 * 
 * Libraries Required:
 * - WiFi.h (built-in)
 * - Firebase_ESP_Client.h (by Mobizt)
 * - RTClib.h (by Adafruit)
 * - AccelStepper.h (optional, for stepper motor)
 * 
 * Installation:
 * 1. Install Arduino IDE or PlatformIO
 * 2. Install ESP32 board support
 * 3. Install required libraries via Library Manager
 * 4. Update WiFi credentials and Firebase config
 * 5. Upload to ESP32
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <RTClib.h>
#include <Wire.h>

// Provide the token generation process info
#include "addons/TokenHelper.h"
// Provide the RTDB payload printing info and other helper functions
#include "addons/RTDBHelper.h"

// ============ CONFIGURATION ============

// WiFi Credentials
#define WIFI_SSID "MCM_Network"
#define WIFI_PASSWORD "1111####"

// Firebase Configuration
#define FIREBASE_HOST "medibox-foe.firebaseio.com"
#define API_KEY "AIzaSyB1H1F5DPPLEdy7UTEZBEXUniHXGxxa7W0"
#define DATABASE_URL "https://medibox-foe-default-rtdb.firebaseio.com"

// Device Configuration - CHANGE THIS FOR EACH DEVICE
#define DEVICE_ID "MEDIBOX001"  // Unique device identifier for testing

// Pin Definitions
#define PIN_RTC_SDA 21
#define PIN_RTC_SCL 22
#define PIN_MOTOR_STEP 25
#define PIN_MOTOR_DIR 26
#define PIN_MOTOR_ENABLE 27
#define PIN_BUZZER 32
#define PIN_LED_MORNING 12
#define PIN_LED_AFTERNOON 14
#define PIN_LED_NIGHT 13
#define PIN_BUTTON 33

// Timing Constants
#define STEPS_PER_DISPENSE 200  // Steps for 45° rotation (adjust based on motor)
#define ALARM_DURATION 60000    // Alarm duration in ms (1 minute)
#define MISSED_DOSE_TIMEOUT 300000  // 5 minutes
#define SYNC_INTERVAL 5000      // Firebase sync interval (5 seconds)
#define HEARTBEAT_INTERVAL 30000 // Update online status every 30 seconds

// ============ GLOBAL VARIABLES ============

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// RTC object
RTC_DS3231 rtc;

// Schedule variables
String morningTime = "08:00";
String afternoonTime = "13:00";
String nightTime = "20:00";

// State variables
bool alarmActive = false;
unsigned long alarmStartTime = 0;
String currentCompartment = "";
bool buttonPressed = false;
unsigned long lastSyncTime = 0;
unsigned long lastHeartbeatTime = 0;

// ============ SETUP ============

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== MediBox ESP32 Starting ===\n");
  
  // Initialize pins
  pinMode(PIN_MOTOR_STEP, OUTPUT);
  pinMode(PIN_MOTOR_DIR, OUTPUT);
  pinMode(PIN_MOTOR_ENABLE, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED_MORNING, OUTPUT);
  pinMode(PIN_LED_AFTERNOON, OUTPUT);
  pinMode(PIN_LED_NIGHT, OUTPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  
  // Disable motor initially
  digitalWrite(PIN_MOTOR_ENABLE, HIGH);
  
  // Initialize I2C for RTC
  Wire.begin(PIN_RTC_SDA, PIN_RTC_SCL);
  
  // Initialize RTC
  if (!rtc.begin()) {
    Serial.println("ERROR: RTC not found!");
    while (1);  // Halt
  }
  
  if (rtc.lostPower()) {
    Serial.println("RTC lost power, setting time to compile time");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }
  
  Serial.println("RTC initialized");
  
  // Connect to WiFi
  connectWiFi();
  
  // Initialize Firebase
  initFirebase();
  
  // Initial sync
  syncScheduleFromFirebase();
  updateOnlineStatus(true);
  
  Serial.println("\n=== Setup Complete ===\n");
}

// ============ MAIN LOOP ============

void loop() {
  unsigned long currentMillis = millis();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, reconnecting...");
    connectWiFi();
  }
  
  // Periodic Firebase sync
  if (currentMillis - lastSyncTime >= SYNC_INTERVAL) {
    syncScheduleFromFirebase();
    checkManualDispense();
    checkSilenceAlarm();
    lastSyncTime = currentMillis;
  }
  
  // Heartbeat - update online status
  if (currentMillis - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    updateOnlineStatus(true);
    lastHeartbeatTime = currentMillis;
  }
  
  // Get current time
  DateTime now = rtc.now();
  String currentTime = formatTime(now.hour(), now.minute());
  
  // Check if it's time to dispense pills
  if (!alarmActive) {
    if (currentTime == morningTime) {
      startAlarm("morning");
    } else if (currentTime == afternoonTime) {
      startAlarm("afternoon");
    } else if (currentTime == nightTime) {
      startAlarm("night");
    }
  }
  
  // Handle active alarm
  if (alarmActive) {
    handleAlarm(currentMillis);
  }
  
  delay(100);  // Small delay to prevent excessive looping
}

// ============ WIFI FUNCTIONS ============

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi Connection Failed!");
  }
}

// ============ FIREBASE FUNCTIONS ============

void initFirebase() {
  Serial.println("Initializing Firebase...");
  
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Sign in anonymously (or use device-specific token)
  auth.user.email = "";
  auth.user.password = "";
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Firebase initialized");
}

void syncScheduleFromFirebase() {
  String path = String("/devices/") + DEVICE_ID + "/schedule";
  
  if (Firebase.RTDB.getJSON(&fbdo, path.c_str())) {
    FirebaseJson &json = fbdo.jsonObject();
    
    FirebaseJsonData result;
    if (json.get(result, "morning")) {
      morningTime = result.stringValue;
    }
    if (json.get(result, "afternoon")) {
      afternoonTime = result.stringValue;
    }
    if (json.get(result, "night")) {
      nightTime = result.stringValue;
    }
    
    Serial.println("Schedule synced:");
    Serial.println("  Morning: " + morningTime);
    Serial.println("  Afternoon: " + afternoonTime);
    Serial.println("  Night: " + nightTime);
  }
}

void updateOnlineStatus(bool online) {
  String path = String("/devices/") + DEVICE_ID + "/status";
  
  FirebaseJson json;
  json.set("online", online);
  json.set("lastSyncTime", getCurrentTimestamp());
  
  Firebase.RTDB.updateNode(&fbdo, path.c_str(), &json);
}

void updateLastDispensed(String compartment) {
  String path = String("/devices/") + DEVICE_ID + "/status/lastDispensed";
  String timestamp = getCurrentTimestamp();
  
  Firebase.RTDB.setString(&fbdo, path.c_str(), timestamp.c_str());
  
  Serial.println("Last dispensed updated: " + timestamp);
  
  // Trigger notification for guardian
  sendPillTakenNotification(compartment);
}

void sendPillTakenNotification(String compartment) {
  String path = String("/devices/") + DEVICE_ID + "/notifications/pillTaken";
  
  FirebaseJson json;
  json.set("triggered", true);
  json.set("compartment", compartment);
  json.set("timestamp", getCurrentTimestamp());
  json.set("type", "pill_taken");
  
  Firebase.RTDB.set(&fbdo, path.c_str(), &json);
  
  Serial.println("Pill taken notification triggered for: " + compartment);
  
  // Auto-clear after 5 seconds
  delay(5000);
  Firebase.RTDB.deleteNode(&fbdo, path.c_str());
}

void sendMissedDoseAlert(String compartment) {
  String path = String("/devices/") + DEVICE_ID + "/alerts";
  
  FirebaseJson json;
  json.set("missedDose", true);
  json.set("missedDoseTime", compartment);
  json.set("timestamp", getCurrentTimestamp());
  json.set("message", "Missed " + compartment + " medication");
  
  Firebase.RTDB.updateNode(&fbdo, path.c_str(), &json);
  
  Serial.println("Missed dose alert sent for: " + compartment);
  
  // Trigger notification for guardian
  sendMissedDoseNotification(compartment);
}

void sendMissedDoseNotification(String compartment) {
  String path = String("/devices/") + DEVICE_ID + "/notifications/missedDose";
  
  FirebaseJson json;
  json.set("triggered", true);
  json.set("compartment", compartment);
  json.set("timestamp", getCurrentTimestamp());
  json.set("type", "missed_dose");
  
  Firebase.RTDB.set(&fbdo, path.c_str(), &json);
  
  Serial.println("Missed dose notification triggered for: " + compartment);
}

void clearAlerts() {
  String path = String("/devices/") + DEVICE_ID + "/alerts";
  Firebase.RTDB.deleteNode(&fbdo, path.c_str());
}

void checkManualDispense() {
  String path = String("/devices/") + DEVICE_ID + "/manualDispense";
  
  if (Firebase.RTDB.getJSON(&fbdo, path.c_str())) {
    FirebaseJson &json = fbdo.jsonObject();
    FirebaseJsonData result;
    
    if (json.get(result, "triggered") && result.boolValue) {
      if (json.get(result, "compartment")) {
        String compartment = result.stringValue;
        Serial.println("Manual dispense triggered for: " + compartment);
        
        // Dispense pills
        dispensePills(compartment);
        
        // Clear the manual dispense flag
        Firebase.RTDB.deleteNode(&fbdo, path.c_str());
      }
    }
  }
}

void checkSilenceAlarm() {
  String path = String("/devices/") + DEVICE_ID + "/silenceAlarm/silenced";
  
  if (Firebase.RTDB.getBool(&fbdo, path.c_str())) {
    if (fbdo.boolData()) {
      Serial.println("Alarm silenced remotely");
      stopAlarm();
    }
  }
}

// ============ ALARM FUNCTIONS ============

void startAlarm(String compartment) {
  Serial.println("=== ALARM STARTED: " + compartment + " ===");
  
  alarmActive = true;
  alarmStartTime = millis();
  currentCompartment = compartment;
  buttonPressed = false;
  
  // Turn on appropriate LED
  turnOnLED(compartment);
  
  // Start buzzer
  tone(PIN_BUZZER, 2000);  // 2kHz tone
}

void handleAlarm(unsigned long currentMillis) {
  // Check button press
  if (digitalRead(PIN_BUTTON) == LOW) {
    if (!buttonPressed) {
      buttonPressed = true;
      Serial.println("Button pressed - dispensing pills");
      
      // Stop alarm
      stopAlarm();
      
      // Dispense pills
      dispensePills(currentCompartment);
      
      // Update Firebase
      updateLastDispensed(currentCompartment);
      clearAlerts();
    }
  }
  
  // Check timeout
  if (currentMillis - alarmStartTime >= MISSED_DOSE_TIMEOUT) {
    Serial.println("Missed dose timeout!");
    
    // Stop alarm
    stopAlarm();
    
    // Send missed dose alert
    sendMissedDoseAlert(currentCompartment);
  }
  
  // Pulse buzzer (beep pattern)
  if ((currentMillis / 500) % 2 == 0) {
    tone(PIN_BUZZER, 2000);
  } else {
    noTone(PIN_BUZZER);
  }
}

void stopAlarm() {
  alarmActive = false;
  noTone(PIN_BUZZER);
  turnOffAllLEDs();
  Serial.println("Alarm stopped");
}

// ============ MOTOR CONTROL ============

void dispensePills(String compartment) {
  Serial.println("Dispensing pills from: " + compartment);
  
  // Enable motor
  digitalWrite(PIN_MOTOR_ENABLE, LOW);
  
  // Set direction (clockwise)
  digitalWrite(PIN_MOTOR_DIR, HIGH);
  
  // Rotate motor
  for (int i = 0; i < STEPS_PER_DISPENSE; i++) {
    digitalWrite(PIN_MOTOR_STEP, HIGH);
    delayMicroseconds(1000);
    digitalWrite(PIN_MOTOR_STEP, LOW);
    delayMicroseconds(1000);
  }
  
  // Disable motor
  digitalWrite(PIN_MOTOR_ENABLE, HIGH);
  
  Serial.println("Pills dispensed successfully");
}

// ============ LED FUNCTIONS ============

void turnOnLED(String compartment) {
  turnOffAllLEDs();
  
  if (compartment == "morning") {
    digitalWrite(PIN_LED_MORNING, HIGH);
  } else if (compartment == "afternoon") {
    digitalWrite(PIN_LED_AFTERNOON, HIGH);
  } else if (compartment == "night") {
    digitalWrite(PIN_LED_NIGHT, HIGH);
  }
}

void turnOffAllLEDs() {
  digitalWrite(PIN_LED_MORNING, LOW);
  digitalWrite(PIN_LED_AFTERNOON, LOW);
  digitalWrite(PIN_LED_NIGHT, LOW);
}

// ============ UTILITY FUNCTIONS ============

String formatTime(int hour, int minute) {
  String h = (hour < 10) ? "0" + String(hour) : String(hour);
  String m = (minute < 10) ? "0" + String(minute) : String(minute);
  return h + ":" + m;
}

String getCurrentTimestamp() {
  DateTime now = rtc.now();
  char timestamp[25];
  sprintf(timestamp, "%04d-%02d-%02dT%02d:%02d:%02d",
          now.year(), now.month(), now.day(),
          now.hour(), now.minute(), now.second());
  return String(timestamp);
}
