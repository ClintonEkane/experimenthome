#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// =============================================================================
// CONFIGURATION — fill in your credentials before uploading
// =============================================================================

const char* WIFI_SSID     = "clinton";
const char* WIFI_PASSWORD = "clinton1";

const char* MQTT_BROKER   = "147bea8727e745e8993c3928a1f4199f.s1.eu.hivemq.cloud";  // e.g. abc123.s1.eu.hivemq.cloud
const int   MQTT_PORT     = 8883;
const char* MQTT_USERNAME = "experimenthome";
const char* MQTT_PASSWORD = "Experimenthome1";
const char* MQTT_CLIENT_ID = "esp32_ohmslaw_station1";

// =============================================================================
// MQTT TOPICS
// =============================================================================

const char* TOPIC_CONTROL = "experiments/ohms-law/stations/station-1/control";
const char* TOPIC_CURRENT = "experiments/ohms-law/stations/station-1/current";
const char* TOPIC_STATUS  = "experiments/ohms-law/stations/station-1/status";
const char* TOPIC_SESSION = "experiments/ohms-law/stations/station-1/session";

// LWT message — broker publishes this if ESP32 disconnects ungracefully
const char* LWT_MESSAGE   = "{\"online\":false,\"reason\":\"lwt\"}";

// =============================================================================
// PIN DEFINITIONS
// =============================================================================

// Relay module — active LOW (LOW = relay closed, HIGH = relay open)
// D25→IN1, D26→IN2, D27→IN3, D14→IN4
const int RELAY_PINS[4] = {25, 26, 27, 14};

// ACS712 current sensor analog output — D34
const int ACS712_PIN = 34;

// Built-in blue LED — GPIO2 (HIGH = on, LOW = off)
const int LED_PIN = 2;

// =============================================================================
// CIRCUIT CONSTANTS
// =============================================================================

// Resistor values (Ohms) corresponding to relay 1, 2, 3, 4
const int RESISTOR_VALUES[4] = {100, 220, 470, 1000};

// ACS712 20A module: sensitivity = 100 mV/A, zero-current output = 2.5V
const float ACS712_SENSITIVITY_MV_PER_A = 100.0;
const float ACS712_ZERO_VOLTAGE         = 2.5;

// ADC samples to average per reading (reduces ESP32 ADC noise)
const int ADC_SAMPLES = 100;

// =============================================================================
// TIMING
// =============================================================================

const unsigned long WIFI_RETRY_INTERVAL_MS      = 5000;  // retry Wi-Fi every 5s when disconnected
const unsigned long HEARTBEAT_INTERVAL_MS       = 5000;  // publish status every 5s
const unsigned long CURRENT_PUBLISH_INTERVAL_MS = 1000;  // publish current every 1s

// =============================================================================
// STATE
// =============================================================================

bool experimentRunning = false;
int  activeRelayIndex  = 0;  // 0=100Ω, 1=220Ω, 2=470Ω, 3=1kΩ

unsigned long lastHeartbeatMs     = 0;
unsigned long lastCurrentPublishMs = 0;

// =============================================================================
// MQTT CLIENT
// =============================================================================

WiFiClientSecure wifiClient;
PubSubClient     mqttClient(wifiClient);

// =============================================================================
// RELAY HELPERS
// =============================================================================

void openAllRelays() {
  for (int i = 0; i < 4; i++) {
    digitalWrite(RELAY_PINS[i], HIGH); // HIGH = open (active LOW module)
  }
}

void closeRelay(int index) {
  openAllRelays();                        // ensure only one relay is ever closed
  digitalWrite(RELAY_PINS[index], LOW);  // LOW = closed
}

// =============================================================================
// ACS712 CURRENT READING
// =============================================================================

float readCurrentMa() {
  long sum = 0;
  for (int i = 0; i < ADC_SAMPLES; i++) {
    sum += analogRead(ACS712_PIN);
    delayMicroseconds(100);
  }
  float avgAdc    = sum / (float)ADC_SAMPLES;
  float voltage   = (avgAdc / 4095.0) * 3.3;
  float currentA  = (voltage - ACS712_ZERO_VOLTAGE) / (ACS712_SENSITIVITY_MV_PER_A / 1000.0);
  float currentMa = currentA * 1000.0;
  return max(0.0f, currentMa); // clamp negative noise to 0
}

// =============================================================================
// MQTT CALLBACK — handles incoming control commands
// =============================================================================

void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  // Parse JSON payload
  StaticJsonDocument<128> doc;
  DeserializationError err = deserializeJson(doc, payload, length);
  if (err) return;

  const char* action = doc["action"];
  if (!action) return;

  if (strcmp(action, "start") == 0) {
    experimentRunning = true;
    closeRelay(activeRelayIndex);
    Serial.printf("Experiment started — relay %d (%dΩ)\n",
                  activeRelayIndex + 1, RESISTOR_VALUES[activeRelayIndex]);

  } else if (strcmp(action, "stop") == 0) {
    experimentRunning = false;
    openAllRelays();
    Serial.println("Experiment stopped — all relays open");

  } else if (strcmp(action, "select_resistor") == 0) {
    int value = doc["value"];
    for (int i = 0; i < 4; i++) {
      if (RESISTOR_VALUES[i] == value) {
        activeRelayIndex = i;
        if (experimentRunning) closeRelay(i);
        Serial.printf("Resistor selected: %dΩ (relay %d)\n", value, i + 1);
        break;
      }
    }
  }
}

// =============================================================================
// WIFI
// =============================================================================

void blinkLed(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(delayMs);
    digitalWrite(LED_PIN, LOW);
    delay(delayMs);
  }
}

void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.printf("Connecting to Wi-Fi: %s\n", WIFI_SSID);

  while (WiFi.status() != WL_CONNECTED) {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    // Poll for up to 5 seconds; blink LED while waiting
    unsigned long attemptStart = millis();
    while (WiFi.status() != WL_CONNECTED &&
           millis() - attemptStart < WIFI_RETRY_INTERVAL_MS) {
      blinkLed(1, 200);
      Serial.print(".");
    }

    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\nNo connection — retrying in 5s...");
      WiFi.disconnect();
      delay(WIFI_RETRY_INTERVAL_MS);
    }
  }

  Serial.printf("\nWi-Fi connected. IP: %s\n", WiFi.localIP().toString().c_str());
}

// =============================================================================
// MQTT CONNECT (with LWT registration)
// =============================================================================

void connectMqtt() {
  wifiClient.setInsecure(); // skip TLS cert verification (acceptable for demo)

  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  mqttClient.setBufferSize(512);

  Serial.print("Connecting to MQTT broker...");
  while (!mqttClient.connected()) {
    blinkLed(5, 100); // blink 5 times rapidly during each connection attempt

    bool connected = mqttClient.connect(
      MQTT_CLIENT_ID,
      MQTT_USERNAME,
      MQTT_PASSWORD,
      TOPIC_SESSION,   // LWT topic
      0,               // LWT QoS
      true,            // LWT retain
      LWT_MESSAGE      // LWT payload — broker fires this on ungraceful disconnect
    );

    if (connected) {
      Serial.println(" connected.");
      mqttClient.subscribe(TOPIC_CONTROL);
      Serial.printf("Subscribed to: %s\n", TOPIC_CONTROL);
      digitalWrite(LED_PIN, HIGH); // LED steady on — fully connected
    } else {
      Serial.printf(" failed (rc=%d). Retrying in 3s...\n", mqttClient.state());
      blinkLed(10, 150); // blink while waiting 3s before retry
    }
  }
}

// =============================================================================
// PUBLISH HELPERS
// =============================================================================

void publishHeartbeat() {
  StaticJsonDocument<64> doc;
  doc["online"]    = true;
  doc["timestamp"] = millis() / 1000;

  char buf[64];
  serializeJson(doc, buf);
  mqttClient.publish(TOPIC_STATUS, buf);
}

void publishCurrent() {
  float currentMa = readCurrentMa();

  StaticJsonDocument<64> doc;
  doc["current_mA"] = round(currentMa * 100.0) / 100.0; // 2 decimal places
  doc["timestamp"]  = millis() / 1000;

  char buf[64];
  serializeJson(doc, buf);
  mqttClient.publish(TOPIC_CURRENT, buf);

  Serial.printf("Current: %.2f mA\n", currentMa);
}

// =============================================================================
// SETUP
// =============================================================================

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- ESP32 Remote Lab Station 1 ---");

  // Initialise LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW); // LED off at boot until fully connected

  // Initialise relay pins — all open at boot, stay open until user starts experiment
  for (int i = 0; i < 4; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], HIGH); // HIGH = open
  }
  Serial.println("All relays open — waiting for experiment start command");

  analogReadResolution(12); // ESP32 ADC: 12-bit (0-4095)

  connectWifi();
  connectMqtt();

  Serial.println("Setup complete. Waiting for commands...");
}

// =============================================================================
// LOOP
// =============================================================================

void loop() {
  // Reconnect Wi-Fi first if dropped — retries every 5 seconds
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_PIN, LOW);
    Serial.println("Wi-Fi lost — reconnecting...");
    connectWifi();
  }

  // Reconnect MQTT only once Wi-Fi is up
  if (!mqttClient.connected()) {
    Serial.println("MQTT disconnected — reconnecting...");
    connectMqtt();
  }

  mqttClient.loop(); // process incoming messages

  unsigned long now = millis();

  // Publish heartbeat every 5 seconds
  if (now - lastHeartbeatMs >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatMs = now;
    publishHeartbeat();
  }

  // Publish current reading every 1 second (only while experiment is running)
  if (experimentRunning && (now - lastCurrentPublishMs >= CURRENT_PUBLISH_INTERVAL_MS)) {
    lastCurrentPublishMs = now;
    publishCurrent();
  }
}
