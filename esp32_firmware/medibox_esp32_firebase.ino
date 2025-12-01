#include <WiFi.h>
#include <ArduinoOTA.h>
#include <time.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

// --------------------------------------
// WIFI + OTA SETTINGS
// --------------------------------------
const char* ssid     = "Pixel_2002";
const char* password = "GPXL2025";

// NTP Settings
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 19800; // GMT+5:30
const int   daylightOffset_sec = 0;

// --------------------------------------
// FIREBASE CONFIGURATION
// --------------------------------------
// TODO: Replace with your Firebase project details
#define FIREBASE_HOST "medibox-foe-default-rtdb.firebaseio.com"
#define API_KEY "AIzaSyB1H1F5DPPLEdy7UTEZBEXUniHXGxxa7W0"
#define DEVICE_ID "MEDIBOX001"

// Firebase objects
FirebaseData fbdo;
FirebaseData streamFbdo; // Separate object for streaming
FirebaseAuth auth;
FirebaseConfig config;
String dbPath = "/devices/" + String(DEVICE_ID);

bool firebaseConnected = false;
bool scheduleStreamActive = false;

// --------------------------------------
// ALARM TIMES (Synced from Firebase)
// --------------------------------------
const int NUM_MOTORS = 3;

// Morning, Afternoon, Evening (Default values)
int alarmHour[NUM_MOTORS]   = { 11, 11, 11 };
int alarmMinute[NUM_MOTORS] = { 30, 35, 37 };

int currentStage = 0;
int lastDay = -1;

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
void setupFirebase();
void syncScheduleFromFirebase();
void updateStatusToFirebase();
void parseTimeString(String timeStr, int& hour, int& minute);
void checkRemoteCommands();
void handleManualDispense(int motorIndex);
int getBatteryLevel();
void setupFirebaseStream();
void handleScheduleStreamUpdate();
void initializeCurrentStage();

// --------------------------------------
// SETUP
// --------------------------------------
void setup() {
  Serial.begin(115200);

  // WIFI
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while(WiFi.status() != WL_CONNECTED){
    delay(500);
    Serial.print(".");
  }
  //Serial.println("\nWiFi connected!");

  // OTA setup
  ArduinoOTA.setHostname("ESP32_Pillbox");
  ArduinoOTA.onStart([]() { Serial.println("OTA Start"); });
  ArduinoOTA.onEnd([]() { Serial.println("\nOTA End"); });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("OTA Progress: %u%%\r", (progress / (total / 100)));
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("OTA Error[%u]: ", error);
    if(error == OTA_AUTH_ERROR) Serial.println("Auth Failed");
    else if(error == OTA_BEGIN_ERROR) Serial.println("Begin Failed");
    else if(error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
    else if(error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
    else if(error == OTA_END_ERROR) Serial.println("End Failed");
  });
  ArduinoOTA.begin();

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

  // Setup Firebase
  setupFirebase();
  
  // Initial sync and setup stream
  if(firebaseConnected){
    syncScheduleFromFirebase();
    initializeCurrentStage(); // Determine which stage we should be at
    updateStatusToFirebase();
    setupFirebaseStream(); // Start listening for real-time updates
  }

  Serial.println("System Ready...");
}

// --------------------------------------
// MAIN LOOP
// --------------------------------------
void loop() 
{
  ArduinoOTA.handle(); // handle OTA in main loop

  int h, m, s, day;
  getLocalTimeNow(h, m, s, day);

  static unsigned long lastPrint = 0;
  if(millis() - lastPrint > 1000){
    lastPrint = millis();
    Serial.printf("Time: %02d:%02d:%02d | Stage: %d\n", h, m, s, currentStage);
  }

  // Handle real-time schedule updates from Firebase stream
  if(firebaseConnected && scheduleStreamActive){
    handleScheduleStreamUpdate();
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
    Serial.println("New Day → Reset to Stage 0");
    if(firebaseConnected){
      updateStatusToFirebase();
    }
  }

  if(currentStage >= NUM_MOTORS){
    return;
  }

  // Check for alarm
  if(h == alarmHour[currentStage] &&
     m == alarmMinute[currentStage] &&
     s == 0){

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
    Serial.println("Waiting 30 seconds for button...");
    bool pressed = waitForButtonWithin(30000);

    if(pressed){
      Serial.println("Button pressed → Rotating motor");
      rotateMotor45(currentStage, true);
      releaseMotor(currentStage);
      shortAckBeep();
    } 
    else {
      Serial.println("No button press → Motor NOT rotated");
    }

    // Move to next stage
    currentStage++;
    Serial.printf("Stage Completed → Next Stage = %d\n", currentStage);
    
    // Update status to Firebase
    if(firebaseConnected){
      updateStatusToFirebase();
    }
  }
}

// --------------------------------------
// FIREBASE SETUP
// --------------------------------------
void setupFirebase(){
  Serial.println("\n=== Firebase Setup ===");
  
  config.api_key = API_KEY;
  config.database_url = FIREBASE_HOST;
  
  // Anonymous authentication
  Serial.println("Signing in anonymously...");
  if(Firebase.signUp(&config, &auth, "", "")){
    Serial.println("✓ Firebase authentication successful");
    firebaseConnected = true;
  } else {
    Serial.printf("✗ Firebase auth failed: %s\n", config.signer.signupError.message.c_str());
    firebaseConnected = false;
    return;
  }

  config.token_status_callback = tokenStatusCallback;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("✓ Firebase initialized");
}

// --------------------------------------
// SYNC SCHEDULE FROM FIREBASE
// --------------------------------------
void syncScheduleFromFirebase(){
  if(!firebaseConnected) return;
  
  Serial.println("\n📥 Syncing schedule from Firebase...");
  
  String schedulePath = dbPath + "/schedule";
  
  if(Firebase.RTDB.getJSON(&fbdo, schedulePath)){
    FirebaseJson &json = fbdo.jsonObject();
    
    FirebaseJsonData morning, afternoon, night;
    
    // Parse morning time
    if(json.get(morning, "morning")){
      String morningTime = morning.stringValue;
      parseTimeString(morningTime, alarmHour[0], alarmMinute[0]);
      Serial.printf("  Morning: %s (%02d:%02d)\n", morningTime.c_str(), alarmHour[0], alarmMinute[0]);
    }
    
    // Parse afternoon time
    if(json.get(afternoon, "afternoon")){
      String afternoonTime = afternoon.stringValue;
      parseTimeString(afternoonTime, alarmHour[1], alarmMinute[1]);
      Serial.printf("  Afternoon: %s (%02d:%02d)\n", afternoonTime.c_str(), alarmHour[1], alarmMinute[1]);
    }
    
    // Parse night time
    if(json.get(night, "night")){
      String nightTime = night.stringValue;
      parseTimeString(nightTime, alarmHour[2], alarmMinute[2]);
      Serial.printf("  Night: %s (%02d:%02d)\n", nightTime.c_str(), alarmHour[2], alarmMinute[2]);
    }
    
    Serial.println("✓ Schedule synced successfully");
  } else {
    Serial.printf("✗ Failed to sync schedule: %s\n", fbdo.errorReason().c_str());
  }
}

// --------------------------------------
// UPDATE STATUS TO FIREBASE
// --------------------------------------
void updateStatusToFirebase(){
  if(!firebaseConnected) return;
  
  String statusPath = dbPath + "/status";
  
  FirebaseJson json;
  json.set("online", true);
  json.set("lastSync", String(millis() / 1000));
  json.set("currentStage", currentStage);
  json.set("batteryLevel", getBatteryLevel());
  
  // Add medication status
  json.set("morning/completed", currentStage > 0);
  json.set("afternoon/completed", currentStage > 1);
  json.set("night/completed", currentStage > 2);
  
  if(Firebase.RTDB.setJSON(&fbdo, statusPath, &json)){
    Serial.println("✓ Status updated to Firebase");
  } else {
    Serial.printf("✗ Failed to update status: %s\n", fbdo.errorReason().c_str());
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
// CHECK REMOTE COMMANDS
// --------------------------------------
void checkRemoteCommands(){
  if(!firebaseConnected) return;

  // Check for manual dispense command
  String manualPath = dbPath + "/manualDispense";
  if(Firebase.RTDB.getJSON(&fbdo, manualPath)){
    FirebaseJson &json = fbdo.jsonObject();
    FirebaseJsonData triggered, compartment;
    
    if(json.get(triggered, "triggered") && triggered.boolValue){
      if(json.get(compartment, "compartment")){
        String comp = compartment.stringValue;
        int motorIndex = -1;
        
        if(comp == "morning") motorIndex = 0;
        else if(comp == "afternoon") motorIndex = 1;
        else if(comp == "night") motorIndex = 2;
        
        if(motorIndex >= 0){
          Serial.printf("Manual dispense triggered: %s (motor %d)\n", comp.c_str(), motorIndex);
          handleManualDispense(motorIndex);
          
          // Clear the command
          Firebase.RTDB.deleteNode(&fbdo, manualPath);
        }
      }
    }
  }

  // Check for silence alarm command
  String silencePath = dbPath + "/silenceAlarm";
  if(Firebase.RTDB.getJSON(&fbdo, silencePath)){
    FirebaseJson &json = fbdo.jsonObject();
    FirebaseJsonData silenced;
    
    if(json.get(silenced, "silenced") && silenced.boolValue){
      Serial.println("Silence alarm command received");
      alarmSilenced = true;
      noTone(BUZZER_PIN);
      
      // Clear the command
      Firebase.RTDB.deleteNode(&fbdo, silencePath);
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

// --------------------------------------
// SETUP FIREBASE STREAM FOR REAL-TIME UPDATES
// --------------------------------------
void setupFirebaseStream(){
  if(!firebaseConnected) return;
  
  String schedulePath = dbPath + "/schedule";
  
  Serial.println("\n🔥 Setting up Firebase real-time stream...");
  
  if(!Firebase.RTDB.beginStream(&streamFbdo, schedulePath)){
    Serial.printf("✗ Stream setup failed: %s\n", streamFbdo.errorReason().c_str());
    scheduleStreamActive = false;
  } else {
    Serial.println("✓ Firebase stream active - listening for schedule changes");
    scheduleStreamActive = true;
  }
}

// --------------------------------------
// HANDLE SCHEDULE STREAM UPDATES
// --------------------------------------
void handleScheduleStreamUpdate(){
  if(!Firebase.RTDB.readStream(&streamFbdo)){
    Serial.printf("Stream read error: %s\n", streamFbdo.errorReason().c_str());
    
    // Try to reconnect stream if it failed
    if(!streamFbdo.httpConnected()){
      Serial.println("Stream disconnected, reconnecting...");
      setupFirebaseStream();
    }
    return;
  }

  if(streamFbdo.streamAvailable()){
    Serial.println("\n📥 Schedule change detected!");
    
    if(streamFbdo.dataType() == "json"){
      FirebaseJson &json = streamFbdo.jsonObject();
      FirebaseJsonData morning, afternoon, night;
      
      // Parse morning time
      if(json.get(morning, "morning")){
        String morningTime = morning.stringValue;
        parseTimeString(morningTime, alarmHour[0], alarmMinute[0]);
        Serial.printf("  Morning updated: %s (%02d:%02d)\n", morningTime.c_str(), alarmHour[0], alarmMinute[0]);
      }
      
      // Parse afternoon time
      if(json.get(afternoon, "afternoon")){
        String afternoonTime = afternoon.stringValue;
        parseTimeString(afternoonTime, alarmHour[1], alarmMinute[1]);
        Serial.printf("  Afternoon updated: %s (%02d:%02d)\n", afternoonTime.c_str(), alarmHour[1], alarmMinute[1]);
      }
      
      // Parse night time
      if(json.get(night, "night")){
        String nightTime = night.stringValue;
        parseTimeString(nightTime, alarmHour[2], alarmMinute[2]);
        Serial.printf("  Night updated: %s (%02d:%02d)\n", nightTime.c_str(), alarmHour[2], alarmMinute[2]);
      }
      
      Serial.println("✓ Schedule synced in real-time!");
      
      // Recalculate current stage based on new schedule
      initializeCurrentStage();
      
      // Update status to confirm sync
      updateStatusToFirebase();
    }
  }
}

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
