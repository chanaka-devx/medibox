#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --------------------------------------
// WIFI + OTA SETTINGS
// --------------------------------------
Preferences preferences;
String wifiSSID = "";
String wifiPassword = "";
bool wifiConfigured = false;

// NTP Settings
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 19800; // GMT+5:30
const int   daylightOffset_sec = 0;

// --------------------------------------
// FIREBASE CONFIGURATION (REST API)
// --------------------------------------
#define FIREBASE_HOST "https://medibox-foe-default-rtdb.firebaseio.com"
#define DEVICE_ID "MEDIBOX001"
String dbPath = String(FIREBASE_HOST) + "/devices/" + DEVICE_ID;

// Cloud Function Configuration
#define CLOUD_FUNCTION_URL "https://us-central1-medibox-foe.cloudfunctions.net/sendNotification"
String guardianFcmToken = "";  // Stored for reference only, Cloud Function will load it

bool firebaseConnected = false;
unsigned long lastScheduleCheck = 0;
const unsigned long SCHEDULE_CHECK_INTERVAL = 10000; // Check schedule every 10s
String lastScheduleHash = ""; // Track schedule changes

// --------------------------------------
// ALARM TIMES (Synced from Firebase)
// --------------------------------------
const int NUM_MOTORS = 3;

// Morning, Afternoon, Evening (Default values)
int alarmHour[NUM_MOTORS]   = { 11, 11, 11 };
int alarmMinute[NUM_MOTORS] = { 30, 35, 37 };

int currentStage = 0;
int lastDay = -1;
bool alarmTriggered = false; // Prevent alarm retriggering

// --------------------------------------
// BUZZER & BUTTON
// --------------------------------------
const int BUZZER_PIN = 32; 
const int BUTTON_PIN = 33; // button -> GND, INPUT_PULLUP

// --------------------------------------
// BATTERY MONITORING
// --------------------------------------
const int BATTERY_PIN = 34; // ADC pin for battery voltage
const float BATTERY_MAX_VOLTAGE = 4.2; // Max voltage for LiPo battery
const float BATTERY_MIN_VOLTAGE = 3.0; // Min safe voltage

// --------------------------------------
// STEPPER MOTOR CONFIG
// --------------------------------------
const int motorPins[NUM_MOTORS][4] = {
  {14, 27, 26, 25},   // Motor 0
  {19, 18,  5, 17},   // Motor 1
  {16,  4, 23, 13}    // Motor 2
};

const int STEPS_PER_REV    = 4096;
const int STEPS_PER_45_DEG = STEPS_PER_REV / 8;

const int stepCount = 8;
const int stepSequence[stepCount][4] = {
  {1,0,0,0},
  {1,1,0,0},
  {0,1,0,0},
  {0,1,1,0},
  {0,0,1,0},
  {0,0,1,1},
  {0,0,0,1},
  {1,0,0,1}
};

int currentStepIndex[NUM_MOTORS] = {0,0,0};

// Remote control flags
bool alarmSilenced = false;
unsigned long lastRemoteCheck = 0;
const unsigned long REMOTE_CHECK_INTERVAL = 2000; // Check every 2 seconds

// BLE Provisioning
#define BLE_SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHAR_SSID_UUID      "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BLE_CHAR_PASSWORD_UUID  "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e"
#define BLE_CHAR_STATUS_UUID    "d8de624e-140f-4a22-8594-e2216b84a5f2"
#define BLE_CHAR_RESET_UUID     "a3c87500-8ed3-4bdf-8a39-a01bebede295"

BLEServer* pServer = NULL;
BLECharacteristic* pStatusCharacteristic = NULL;
bool bleClientConnected = false;
bool newWifiCredentials = false;

// --------------------------------------
// FIREBASE REST API FUNCTIONS
// --------------------------------------
String httpGET(String path) {
  if(WiFi.status() != WL_CONNECTED) return "";
  HTTPClient http;
  http.begin(path + ".json");
  http.setTimeout(5000);
  int httpCode = http.GET();
  String payload = "";
  if (httpCode == HTTP_CODE_OK) {
    payload = http.getString();
  }
  http.end();
  return payload;
}

bool httpPUT(String path, String jsonData) {
  if(WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  http.begin(path + ".json");
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.PUT(jsonData);
  http.end();
  return (httpCode == HTTP_CODE_OK);
}

bool httpDELETE(String path) {
  if(WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  http.begin(path + ".json");
  int httpCode = http.sendRequest("DELETE");
  http.end();
  return (httpCode == HTTP_CODE_OK);
}

// --------------------------------------
// FCM NOTIFICATION FUNCTIONS (via Cloud Function)
// --------------------------------------
bool sendFCMNotification(String title, String body, String type){
  if(WiFi.status() != WL_CONNECTED) return false;
  
  HTTPClient http;
  http.begin(CLOUD_FUNCTION_URL);
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<512> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["title"] = title;
  doc["body"] = body;
  doc["type"] = type;
  
  String jsonData;
  serializeJson(doc, jsonData);
  
  Serial.println("Sending notification via Cloud Function...");
  int httpCode = http.POST(jsonData);
  
  if(httpCode == HTTP_CODE_OK || httpCode == 200){
    String response = http.getString();
    Serial.println("✓ Notification sent successfully");
    Serial.println("Response: " + response);
  } else {
    Serial.printf("✗ Cloud Function error: %d\n", httpCode);
    String response = http.getString();
    Serial.println("Error response: " + response);
  }
  
  http.end();
  return (httpCode == HTTP_CODE_OK || httpCode == 200);
}

void loadGuardianFcmToken(){
  if(!firebaseConnected) return;
  
  // Load FCM device token (optional - for reference only)
  // Cloud Function will load the token from database when needed
  String response = httpGET(dbPath + "/guardianFcmToken");
  if(response.length() > 5){
    guardianFcmToken = response;
    guardianFcmToken.replace("\"", "");
    Serial.println("✓ Guardian FCM token loaded (for reference)");
  } else {
    Serial.println("Note: FCM token not in database yet - open the app first");
  }
}

// --------------------------------------
// FUNCTION DECLARATIONS
// --------------------------------------
void rotateMotor45(int motorIndex, bool clockwise);
void stepMotor(int motorIndex, int stepsToMove, bool clockwise);
void setStep(int motorIndex, int seqIndex);
void releaseMotor(int motorIndex);
void beepPattern10s();
bool waitForButtonWithin(unsigned long timeoutMs);
void shortAckBeep();
void getLocalTimeNow(int &h, int &m, int &s, int &day);
void syncSchedule();
void updateStatus();
void parseTimeString(String timeStr, int& hour, int& minute);
void checkRemoteCommands();
void handleManualDispense(int motorIndex);
int getBatteryLevel();
void initializeCurrentStage();
void loadWifiCredentials();
void saveWifiCredentials(String ssid, String password);
void setupBLE();
bool connectToWiFi();
void handleBLEProvisioning();

// --------------------------------------
// SETUP
// --------------------------------------
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== MEDIBOX ESP32 Starting ===");

  // Load saved WiFi credentials
  loadWifiCredentials();
  
  // Try to connect to WiFi
  if(wifiConfigured){
    Serial.println("Found saved WiFi credentials, attempting connection...");
    if(!connectToWiFi()){
      Serial.println("Failed to connect. Starting BLE provisioning...");
      setupBLE();
    }
  } else {
    Serial.println("No WiFi credentials found. Starting BLE provisioning...");
    setupBLE();
  }

  // NTP SYNC
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  delay(1000);

  int h, m, s, d;
  getLocalTimeNow(h, m, s, d);
  lastDay = d;

  // Stepper motor pin setup
  for(int mtr=0; mtr<NUM_MOTORS; mtr++){
    for(int c=0; c<4; c++){
      pinMode(motorPins[mtr][c], OUTPUT);
      digitalWrite(motorPins[mtr][c], LOW);
    }
  }

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Battery monitoring
  pinMode(BATTERY_PIN, INPUT);

  // Initial Firebase sync
  if(WiFi.status() == WL_CONNECTED){
    firebaseConnected = true;
    loadGuardianFcmToken();  // Load FCM token for push notifications
    syncSchedule();
    initializeCurrentStage();
    updateStatus();
  }

  Serial.println("System Ready...");
}

// --------------------------------------
// MAIN LOOP
// --------------------------------------
void loop() 
{
  // Handle BLE provisioning if not connected to WiFi
  if(!wifiConfigured || WiFi.status() != WL_CONNECTED){
    handleBLEProvisioning();
    return;
  }

  int h, m, s, day;
  getLocalTimeNow(h, m, s, day);

  static unsigned long lastPrint = 0;
  if(millis() - lastPrint > 1000){
    lastPrint = millis();
    Serial.printf("Time: %02d:%02d:%02d | Stage: %d\n", h, m, s, currentStage);
  }

  // Check schedule updates periodically
  if(firebaseConnected && (millis() - lastScheduleCheck > SCHEDULE_CHECK_INTERVAL)){
    syncSchedule();
    lastScheduleCheck = millis();
  }

  // Check for remote control commands
  if(firebaseConnected && (millis() - lastRemoteCheck > REMOTE_CHECK_INTERVAL)){
    checkRemoteCommands();
    lastRemoteCheck = millis();
  }

  // Reset stage at midnight
  if(day != lastDay){
    lastDay = day;
    currentStage = 0;
    alarmTriggered = false;
    Serial.println("New Day → Reset to Stage 0");
    if(firebaseConnected){
      updateStatus();
    }
  }

  if(currentStage >= NUM_MOTORS){
    return;
  }

  // Check for alarm
  if(h == alarmHour[currentStage] &&
     m == alarmMinute[currentStage]){
    
    // Trigger alarm only once per minute
    if(!alarmTriggered){
      alarmTriggered = true;
      
      Serial.printf("ALARM TRIGGERED → Stage %d\n", currentStage);

      // Reset silence flag for new alarm
      alarmSilenced = false;

      // 1) Ring buzzer (unless silenced remotely)
      unsigned long alarmStart = millis();
      while(millis() - alarmStart < 10000 && !alarmSilenced){
        // Check for silence command during alarm
        if(firebaseConnected && (millis() - lastRemoteCheck > 1000)){
          checkRemoteCommands();
          lastRemoteCheck = millis();
        }
        
        if(!alarmSilenced){
          // Play short beep
          tone(BUZZER_PIN, 1500);
          delay(100);
          noTone(BUZZER_PIN);
          delay(100);
        }
      }

      if(alarmSilenced){
        Serial.println("Alarm silenced remotely");
        noTone(BUZZER_PIN);
      }

      // 2) Wait for button press
      Serial.println("Waiting 30 minutes for button...");
      bool pressed = waitForButtonWithin(1800000); 

      if(pressed){
        Serial.println("Button pressed → Rotating motor");
        rotateMotor45(currentStage, true);
        releaseMotor(currentStage);
        shortAckBeep();
        
        // Trigger notification to guardian
        if(firebaseConnected){
          Serial.println("Triggering guardian notification...");
          
          // Get current Unix timestamp (seconds since epoch)
          time_t now;
          time(&now);
          
          // Send FCM push notification
          bool notifSent = sendFCMNotification(
            "Medicine Taken ✓",
            "The patient has taken their medication on time.",
            "pill_taken"
          );
          
          // Also update database for history
          StaticJsonDocument<128> notifDoc;
          notifDoc["triggered"] = true;
          notifDoc["timestamp"] = (long long)now * 1000; // Convert to milliseconds
          
          String notifData;
          serializeJson(notifDoc, notifData);
          
          if(httpPUT(dbPath + "/notificationTrigger", notifData)){
            Serial.println("✓ Notification trigger sent to database");
          } else {
            Serial.println("✗ Failed to send notification trigger");
          }
        }
      } 
      else {
        Serial.println("No button press → Motor NOT rotated");
        
        // Trigger missed dose notification
        if(firebaseConnected){
          Serial.println("Triggering missed dose alert...");
          
          // Get current time for timestamp
          struct tm timeinfo;
          char timeStr[25];
          if(getLocalTime(&timeinfo)){
            strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%S", &timeinfo);
          } else {
            strcpy(timeStr, "");
          }
          
          // Determine compartment name
          String compartment;
          if(currentStage == 0) compartment = "morning";
          else if(currentStage == 1) compartment = "afternoon";
          else if(currentStage == 2) compartment = "night";
          else compartment = "unknown";
          
          // Send FCM push notification
          String alertMsg = "Missed " + compartment + " medication";
          bool notifSent = sendFCMNotification(
            "Medicine Not Taken ⚠️",
            alertMsg,
            "missed_dose"
          );
          
          // Also update database for history
          StaticJsonDocument<256> missedDoc;
          missedDoc["missed"] = true;
          missedDoc["compartment"] = compartment;
          missedDoc["timestamp"] = String(timeStr);
          
          String missedData;
          serializeJson(missedDoc, missedData);
          
          if(httpPUT(dbPath + "/missedDose", missedData)){
            Serial.println("✓ Missed dose alert sent to database");
          } else {
            Serial.println("✗ Failed to send missed dose alert");
          }
        }
      }

      // Move to next stage
      currentStage++;
      Serial.printf("Stage Completed → Next Stage = %d\n", currentStage);
      
      // Update status to Firebase
      if(firebaseConnected){
        updateStatus();
      }
    }
  } else {
    // Reset trigger flag when we're not in alarm time
    alarmTriggered = false;
  }
}

// Firebase setup not needed with REST API - using direct HTTP calls

// --------------------------------------
// SYNC SCHEDULE FROM FIREBASE (REST API)
// --------------------------------------
void syncSchedule(){
  if(!firebaseConnected) return;
  
  String response = httpGET(dbPath + "/schedule");
  
  if(response.length() > 10){
    // Check if schedule actually changed
    if(response == lastScheduleHash){
      return; // No changes, skip processing
    }
    
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if(!error){
      bool scheduleChanged = false;
      
      if(doc.containsKey("morning")){
        String morningTime = doc["morning"].as<String>();
        int oldHour = alarmHour[0], oldMin = alarmMinute[0];
        parseTimeString(morningTime, alarmHour[0], alarmMinute[0]);
        if(oldHour != alarmHour[0] || oldMin != alarmMinute[0]){
          scheduleChanged = true;
          Serial.printf("Morning: %s\n", morningTime.c_str());
        }
      }
      if(doc.containsKey("afternoon")){
        String afternoonTime = doc["afternoon"].as<String>();
        int oldHour = alarmHour[1], oldMin = alarmMinute[1];
        parseTimeString(afternoonTime, alarmHour[1], alarmMinute[1]);
        if(oldHour != alarmHour[1] || oldMin != alarmMinute[1]){
          scheduleChanged = true;
          Serial.printf("Afternoon: %s\n", afternoonTime.c_str());
        }
      }
      if(doc.containsKey("night")){
        String nightTime = doc["night"].as<String>();
        int oldHour = alarmHour[2], oldMin = alarmMinute[2];
        parseTimeString(nightTime, alarmHour[2], alarmMinute[2]);
        if(oldHour != alarmHour[2] || oldMin != alarmMinute[2]){
          scheduleChanged = true;
          Serial.printf("Night: %s\n", nightTime.c_str());
        }
      }
      
      if(scheduleChanged){
        lastScheduleHash = response;
        Serial.println("✓ Schedule synced - RECALCULATING STAGE");
        initializeCurrentStage();
        updateStatus();
      }
    }
  }
}

// --------------------------------------
// UPDATE STATUS TO FIREBASE (REST API)
// --------------------------------------
void updateStatus(){
  if(!firebaseConnected) return;
  
  StaticJsonDocument<256> doc;
  doc["online"] = true;
  doc["currentStage"] = currentStage;
  doc["batteryLevel"] = getBatteryLevel();
  
  JsonObject morning = doc.createNestedObject("morning");
  morning["completed"] = currentStage > 0;
  
  JsonObject afternoon = doc.createNestedObject("afternoon");
  afternoon["completed"] = currentStage > 1;
  
  JsonObject night = doc.createNestedObject("night");
  night["completed"] = currentStage > 2;
  
  String jsonData;
  serializeJson(doc, jsonData);
  
  if(httpPUT(dbPath + "/status", jsonData)){
    Serial.println("✓ Status updated");
  }
}

// --------------------------------------
// PARSE TIME STRING (HH:MM format)
// --------------------------------------
void parseTimeString(String timeStr, int& hour, int& minute){
  int colonIndex = timeStr.indexOf(':');
  if(colonIndex > 0){
    hour = timeStr.substring(0, colonIndex).toInt();
    minute = timeStr.substring(colonIndex + 1).toInt();
  }
}

// --------------------------------------
// GET TIME FROM ESP32 CLOCK
// --------------------------------------
void getLocalTimeNow(int &h, int &m, int &s, int &day)
{
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }
  h   = timeinfo.tm_hour;
  m   = timeinfo.tm_min;
  s   = timeinfo.tm_sec;
  day = timeinfo.tm_mday;
}

// --------------------------------------
// STEPPER FUNCTIONS
// --------------------------------------
void rotateMotor45(int motorIndex, bool clockwise){
  stepMotor(motorIndex, STEPS_PER_45_DEG, clockwise);
}

void stepMotor(int motorIndex, int stepsToMove, bool clockwise){
  for(int i=0; i<stepsToMove; i++){
    currentStepIndex[motorIndex] += clockwise ? 1 : -1;

    if(currentStepIndex[motorIndex] >= stepCount) currentStepIndex[motorIndex] = 0;
    if(currentStepIndex[motorIndex] < 0)           currentStepIndex[motorIndex] = stepCount - 1;

    setStep(motorIndex, currentStepIndex[motorIndex]);
    delay(2);
  }
}

void setStep(int motorIndex, int seqIndex){
  for(int c=0; c<4; c++){
    digitalWrite(motorPins[motorIndex][c], stepSequence[seqIndex][c]);
  }
}

void releaseMotor(int motorIndex){
  for(int c=0; c<4; c++){
    digitalWrite(motorPins[motorIndex][c], LOW);
  }
}

// --------------------------------------
// BUZZER FUNCTIONS
// --------------------------------------
void beepPattern10s(){
  const int freqs[] = { 1200,1500,1800,2200,1800,1500 };
  const int durs[]  = { 120,120,120,200,120,200 };
  const int count = sizeof(freqs)/sizeof(freqs[0]);

  unsigned long start = millis();
  
  while(millis() - start < 10000){
    for(int i=0; i<count; i++){
      if(millis() - start >= 10000) break;
      tone(BUZZER_PIN, freqs[i]);
      delay(durs[i]);
      noTone(BUZZER_PIN);
      delay(40);
    }
  }
}

void shortAckBeep(){
  tone(BUZZER_PIN, 2000);
  delay(200);
  noTone(BUZZER_PIN);
}

// --------------------------------------
// WAIT FOR BUTTON
// --------------------------------------
bool waitForButtonWithin(unsigned long timeoutMs){
  unsigned long start = millis();
  int lastState = digitalRead(BUTTON_PIN);

  while(millis() - start < timeoutMs){
    int state = digitalRead(BUTTON_PIN);

    if(lastState == HIGH && state == LOW){
      delay(20);
      if(digitalRead(BUTTON_PIN) == LOW){
        return true;
      }
    }

    lastState = state;
  }

  return false;
}

// --------------------------------------
// CHECK REMOTE COMMANDS (REST API)
// --------------------------------------
void checkRemoteCommands(){
  if(!firebaseConnected) return;

  // Check for manual dispense command
  String response = httpGET(dbPath + "/manualDispense");
  if(response.length() > 10){
    StaticJsonDocument<256> doc;
    deserializeJson(doc, response);
    
    if(doc["triggered"].as<bool>()){
      String comp = doc["compartment"].as<String>();
      int motorIndex = -1;
      
      if(comp == "morning") motorIndex = 0;
      else if(comp == "afternoon") motorIndex = 1;
      else if(comp == "night") motorIndex = 2;
      
      if(motorIndex >= 0){
        Serial.printf("Manual dispense: %s\n", comp.c_str());
        handleManualDispense(motorIndex);
        httpDELETE(dbPath + "/manualDispense");
      }
    }
  }

  // Check for silence alarm command
  response = httpGET(dbPath + "/silenceAlarm");
  if(response.length() > 10){
    StaticJsonDocument<128> doc;
    deserializeJson(doc, response);
    
    if(doc["silenced"].as<bool>()){
      Serial.println("Alarm silenced");
      alarmSilenced = true;
      noTone(BUZZER_PIN);
      httpDELETE(dbPath + "/silenceAlarm");
    }
  }
}

// --------------------------------------
// HANDLE MANUAL DISPENSE
// --------------------------------------
void handleManualDispense(int motorIndex){
  Serial.printf("Dispensing from motor %d...\n", motorIndex);
  
  // Rotate motor 45 degrees
  rotateMotor45(motorIndex, true);
  releaseMotor(motorIndex);
  
  // Confirmation beep
  shortAckBeep();
  
  Serial.println("Manual dispense completed");
}

// --------------------------------------
// GET BATTERY LEVEL
// --------------------------------------
int getBatteryLevel(){
  // Read analog value (0-4095 for 12-bit ADC)
  int rawValue = analogRead(BATTERY_PIN);
  
  // Convert to voltage (ESP32 ADC reference is 3.3V)
  // Using voltage divider: Vout = Vin * R2/(R1+R2)
  // For direct connection or adjust according to your voltage divider
  float voltage = (rawValue / 4095.0) * 3.3 * 2; // *2 if using 1:1 voltage divider
  
  // Calculate percentage
  float percentage = ((voltage - BATTERY_MIN_VOLTAGE) / (BATTERY_MAX_VOLTAGE - BATTERY_MIN_VOLTAGE)) * 100.0;
  
  // Constrain to 0-100%
  if(percentage > 100) percentage = 100;
  if(percentage < 0) percentage = 0;
  
  Serial.printf("Battery: %d%% (%.2fV)\n", (int)percentage, voltage);
  
  return (int)percentage;
}

// Firebase streams not needed with REST API - using periodic polling

// --------------------------------------
// INITIALIZE CURRENT STAGE ON STARTUP
// --------------------------------------
void initializeCurrentStage(){
  int h, m, s, day;
  getLocalTimeNow(h, m, s, day);
  
  Serial.println("\n⏰ Checking current time against schedule...");
  Serial.printf("Current time: %02d:%02d\n", h, m);
  
  // Convert current time to minutes since midnight
  int currentMinutes = h * 60 + m;
  
  // Find the next upcoming alarm
  int nextAlarmIndex = -1;
  int nearestFutureTime = 9999; // Large number
  
  for(int i = 0; i < NUM_MOTORS; i++){
    int alarmMinutes = alarmHour[i] * 60 + alarmMinute[i];
    Serial.printf("Alarm %d: %02d:%02d (%d minutes)\n", i, alarmHour[i], alarmMinute[i], alarmMinutes);
    
    // Check if this alarm is in the future and closer than previous candidates
    if(alarmMinutes > currentMinutes && alarmMinutes < nearestFutureTime){
      nearestFutureTime = alarmMinutes;
      nextAlarmIndex = i;
    }
  }
  
  // Set current stage to the next alarm index
  if(nextAlarmIndex >= 0){
    currentStage = nextAlarmIndex;
    Serial.printf("✓ Next upcoming alarm: %02d:%02d (Stage %d)\n", 
                  alarmHour[nextAlarmIndex], alarmMinute[nextAlarmIndex], nextAlarmIndex);
  } else {
    currentStage = NUM_MOTORS; // All alarms passed
    Serial.println("✓ All alarms for today have passed (Stage 3)");
  }
}

// --------------------------------------
// LOAD WIFI CREDENTIALS FROM STORAGE
// --------------------------------------
void loadWifiCredentials(){
  preferences.begin("medibox", false);
  wifiSSID = preferences.getString("ssid", "");
  wifiPassword = preferences.getString("password", "");
  preferences.end();
  
  if(wifiSSID.length() > 0){
    wifiConfigured = true;
    Serial.println("✓ WiFi credentials loaded from storage");
  } else {
    wifiConfigured = false;
    Serial.println("⚠ No WiFi credentials stored");
  }
}

// --------------------------------------
// SAVE WIFI CREDENTIALS TO STORAGE
// --------------------------------------
void saveWifiCredentials(String ssid, String password){
  preferences.begin("medibox", false);
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.end();
  
  wifiSSID = ssid;
  wifiPassword = password;
  wifiConfigured = true;
  
  Serial.println("✓ WiFi credentials saved to storage");
}

// --------------------------------------
// CONNECT TO WIFI
// --------------------------------------
bool connectToWiFi(){
  if(wifiSSID.length() == 0) return false;
  
  Serial.printf("Connecting to WiFi: %s\n", wifiSSID.c_str());
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  
  int attempts = 0;
  while(WiFi.status() != WL_CONNECTED && attempts < 20){
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if(WiFi.status() == WL_CONNECTED){
    Serial.println("\n✓ WiFi connected!");
    Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
    return true;
  } else {
    Serial.println("\n✗ WiFi connection failed");
    return false;
  }
}

// --------------------------------------
// BLE SERVER CALLBACKS
// --------------------------------------
class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleClientConnected = true;
    Serial.println("📱 BLE Client Connected");
  }

  void onDisconnect(BLEServer* pServer) {
    bleClientConnected = false;
    Serial.println("📱 BLE Client Disconnected");
    // Restart advertising
    pServer->getAdvertising()->start();
  }
};

// BLE Characteristic Callbacks for SSID
class SSIDCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if(value.length() > 0){
      wifiSSID = String(value.c_str());
      Serial.printf("📝 Received SSID: %s\n", wifiSSID.c_str());
    }
  }
};

// BLE Characteristic Callbacks for Password
class PasswordCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if(value.length() > 0){
      wifiPassword = String(value.c_str());
      Serial.println("📝 Received Password: ********");
      newWifiCredentials = true;
    }
  }
};

// BLE Characteristic Callbacks for Reset
class ResetCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if(value.length() > 0 && String(value.c_str()) == "RESET"){
      Serial.println("🔄 WiFi reset requested via BLE");
      
      // Clear saved credentials
      preferences.begin("medibox", false);
      preferences.clear();
      preferences.end();
      
      wifiConfigured = false;
      
      // Confirmation beeps
      for(int i = 0; i < 3; i++){
        tone(BUZZER_PIN, 2000);
        delay(200);
        noTone(BUZZER_PIN);
        delay(200);
      }
      
      pStatusCharacteristic->setValue("RESET_OK");
      pStatusCharacteristic->notify();
      
      Serial.println("✓ WiFi credentials cleared!");
    }
  }
};

// --------------------------------------
// SETUP BLE PROVISIONING
// --------------------------------------
void setupBLE(){
  Serial.println("\n🔵 Starting BLE Provisioning Mode...");
  
  BLEDevice::init("MEDIBOX_SETUP");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
  
  // SSID Characteristic
  BLECharacteristic *pSSIDChar = pService->createCharacteristic(
    BLE_CHAR_SSID_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pSSIDChar->setCallbacks(new SSIDCallbacks());
  
  // Password Characteristic
  BLECharacteristic *pPasswordChar = pService->createCharacteristic(
    BLE_CHAR_PASSWORD_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pPasswordChar->setCallbacks(new PasswordCallbacks());
  
  // Status Characteristic (Read/Notify)
  pStatusCharacteristic = pService->createCharacteristic(
    BLE_CHAR_STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatusCharacteristic->addDescriptor(new BLE2902());
  pStatusCharacteristic->setValue("WAITING");
  
  // Reset Characteristic (Write)
  BLECharacteristic *pResetChar = pService->createCharacteristic(
    BLE_CHAR_RESET_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pResetChar->setCallbacks(new ResetCallbacks());
  
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("✓ BLE Advertising started");
  Serial.println("📱 Open your app to configure WiFi");
}

// --------------------------------------
// HANDLE BLE PROVISIONING IN LOOP
// --------------------------------------
void handleBLEProvisioning(){
  if(newWifiCredentials){
    newWifiCredentials = false;
    
    Serial.println("\n🔄 Attempting to connect with new credentials...");
    pStatusCharacteristic->setValue("CONNECTING");
    pStatusCharacteristic->notify();
    
    if(connectToWiFi()){
      // Success!
      saveWifiCredentials(wifiSSID, wifiPassword);
      
      pStatusCharacteristic->setValue("CONNECTED");
      pStatusCharacteristic->notify();
      
      Serial.println("✓ WiFi configured successfully!");
      
      // Stop BLE and continue with normal operation
      delay(2000);
      BLEDevice::deinit();
      
      // Continue with setup
      setupOTAAndFirebase();
    } else {
      // Failed
      pStatusCharacteristic->setValue("FAILED");
      pStatusCharacteristic->notify();
      
      Serial.println("✗ Failed to connect. Try again.");
      wifiConfigured = false;
    }
  }
  
  delay(100);
}

// --------------------------------------
// SETUP FIREBASE (after WiFi connected)
// --------------------------------------
void setupOTAAndFirebase(){
  // NTP SYNC
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  delay(1000);

  int h, m, s, d;
  getLocalTimeNow(h, m, s, d);
  lastDay = d;

  // Initial Firebase sync
  firebaseConnected = true;
  syncSchedule();
  initializeCurrentStage();
  updateStatus();

  Serial.println("✓ System Ready!");
}
