// UNCOMMENT TO ENABLE FUNCTIONS
// #define SIMUL
#define MQTT
// #define PROCESSING

#include <Arduino.h>

#ifdef MQTT
// MQTT defines
#include <ESP8266WiFi.h>
#include <PubSubClient.h>

const char *ssid = "Lautz";                      // use your network's ssid
const char *password = "password";             // use your network's password
const char *mqtt_server = "node02.myqtthub.com"; // use mqtt server address
const char *mqtt_user = "esp";
const char *mqtt_pwd = "password";
const uint16_t mqtt_server_port = 1883;         // and port
const char *mqtt_channel_sub = "prj_dwnstream"; // and channel to sub to
const char *mqtt_channel_pub = "prj_upstream";  // and channel to pub to

WiFiClient espClient;
PubSubClient client(espClient);

uint8_t prev_connection_state = 0;
// N.A. | N.A. | N.A. | N.A. | N.A. | N.A. | MQTT | WIFI
uint8_t connection_state = 0;
uint32_t time_conn_led = 0;

// REVIEW
// #endif
#define MSGDELAY 3000 // 3s message delay
uint32_t last_message_mqtt = 0;
// #ifdef MQTT

// net related functions
void keep_alive_mqtt();
void connect_wifi();
void reconnect_mqtt_broker();
void callback(char *topic, byte *payload, unsigned int length);
#endif

// Time constants define
#define PUMPTIME 300000  // 5m pump max time of continuous operation
#define VALVETIME 30000  // 30s valve continuous time of operation with T2E = 1
#define VALVEOFF 3600000 // 1h valve cooldown in case T2E remains 0

// IN defines
#define pinT3F 14 // GPIO14 <-> D5  (safe)
#define pinT2F 10 // GPIO10 <-> SD3 (note:1 at boot)
#define pinT2E 9  // GPIO9  <-> SD2 (note:1 at boot)
// OUT defines
#define pinV 5    // GPIO12 <-> D6  (safe)
#define pinP 12   // GPIO5  <-> D1  (safe)
#define pinLED 13 // GPIO13 <-> D7  (safe)
// NOTE BUILTIN_LED is GPIO2

uint16_t cs; // countdown seconds
uint32_t last_cs_ts;

// state variable for each signal (both IN and OUT)
uint8_t sT3F, sT2F, sT2E = 0;
uint8_t last_sent_state = 0;

// boolean states
bool sLED_BIN = 0, sLED = 0;
bool pump_is_on = 0;
bool valve_is_on = 0;

// time variables
uint32_t time_pump_on;
uint32_t time_pump_off;

uint32_t time_valve_on;
uint32_t time_valve_off;

unsigned long last_time;

uint8_t prev_machine_state = 0;
uint8_t machine_state = 0;
// N.A.| N.A. | N.A. | T3F | T2F | T2E | P | V

#ifdef PROCESSING
uint8_t devState = 0;
uint8_t ds;
String binaryData = "";
#endif

// function prototypes
void read_inputs();
void check_behaviour();
void update_state();
void compute_led();
void apply_outputs();

// helper/utility functions
// void turn_off_pump_INT();
void update_counter(uint32_t &counter);
void pump_logic();
void valve_logic();

// led functions
uint32_t time_led = 0;
const unsigned long period_led = 1000;
int8_t dc_todo = -1;
void LED_Toggle(int LED, bool &led_state);
// void LED_Blink(int LED, bool &led_state, uint32_t &ltl, double period_multiplier, int dc_fractions);

void setup()
{
  // put your setup code here, to run once:
  pinMode(pinT3F, INPUT_PULLUP);
  pinMode(pinT2F, INPUT_PULLUP);
  pinMode(pinT2E, INPUT_PULLUP);
  // attachInterrupt(digitalPinToInterrupt(pinT2E), turn_off_pump_INT, FALLING);

  pinMode(pinV, OUTPUT);
  pinMode(pinP, OUTPUT);
  pinMode(pinLED, OUTPUT);
  pinMode(BUILTIN_LED, OUTPUT);

  Serial.begin(115200);
  delay(500);

#ifdef MQTT
  connect_wifi();
  delay(500);

  client.setServer(mqtt_server, mqtt_server_port);
  client.setCallback(callback);
  delay(500);
#endif

  Serial.println("");
  Serial.println("Starting...");
  last_cs_ts = millis();
  sLED_BIN = false;

  last_time = millis();
}

void loop()
{
  // put your main code here, to run repeatedly:
#ifdef MQTT
  keep_alive_mqtt();
#endif
  // reading inputs
  read_inputs();

  // do some stuff
  check_behaviour();

  update_state();

  // applying outputs to pins or to simulator
  compute_led();
  apply_outputs();

  last_time = millis();

  if (prev_machine_state != machine_state)
    prev_machine_state = machine_state;

#ifdef MQTT
  if (prev_connection_state != connection_state)
    prev_connection_state = connection_state;
#endif
}

void read_inputs()
{

#ifdef SIMUL

  uint8_t rc, rn;
  if (Serial.available() > 0)
  {
    rc = Serial.read();
    if (rc >= '0' & rc <= '9')
    {
      rn = rc - '0';
      sT3F = (rn & 0x04) >> 2;
      sT2F = (rn & 0x02) >> 1;
      sT2E = (rn & 0x01);
    }
  }

#elif defined(PROCESSING)

  if (Serial.available() > 0)
  {
    ds = (Serial.readStringUntil('\n').toInt());
  }

  binaryData = String(ds, BIN);

  // update inputs
  sT2E = (binaryData[0] == '1');
  sT2F = (binaryData[1] == '1');
  sT3F = (binaryData[2] == '1');

#else

  sT2E = digitalRead(pinT2E);
  sT2F = digitalRead(pinT2F);
  sT3F = digitalRead(pinT3F);

#endif
}

void check_behaviour()
{
  // timing for seconds...
  // if ((millis() - last_cs_ts) >= 1000)
  // {
  //   last_cs_ts = millis();
  //   if (cs > 0)
  //     cs -= 1;
  //   sLED_BIN = !sLED_BIN;
  // }

  pump_logic();

  valve_logic();

  // just copying INs to OUTs
  // sLED = sT3F;
  // sV = sT2F;
  // sP = sT2E;
}

// LED SYSTEM
void update_state()
{
  // N.A. | N.A. | N.A. | T3F | T2F | T2E | P | V
  machine_state = (sT3F << 4) | (sT2F << 3) | (sT2E << 2) | (pump_is_on << 1) | (valve_is_on << 0);

#ifdef MQTT
  // N.A. | N.A. | N.A. | N.A. | N.A. | N.A. | MQTT | WIFI
  connection_state = (client.connected() << 1) | ((WiFi.status() == WL_CONNECTED) << 0);
#endif
}

void compute_led()
{
  if (!pump_is_on && valve_is_on)
  {
    // 000x xx01 LED1 BLINK ---___---___-- ... machine_state 2
    // if (prev_machine_state != machine_state)
    // {
    //   Serial.println("machine state 2");
    // }
    // LED_Blink(pinLED, sLED, time_led, 0.3, 1);
    LED_Blink(pinLED, sLED, time_led, 0.3, 1);
  }
  if (pump_is_on)
  {
    if (!sT2E)
    {
      // 000x x01x LED1 BLINK -_-__-_-__-_-_ ... machine_state 3
      // if (prev_machine_state != machine_state)
      // {
      //   Serial.println("machine state 3");
      // }
      // LED_Blink(pinLED, sLED, time_led, 1, 2);
      LED_Blink(pinLED, sLED, time_led, 1, 2);
    }
    else
    {
      if (valve_is_on)
      {
        // 000x x111  LED1 BLINK -_-_-_-_-_-_-_ ...machine_state 4
        // if (prev_machine_state != machine_state)
        // {
        //   Serial.println("machine state 4");
        // }
        // LED_Blink(pinLED, sLED, time_led, 1, 1);
        LED_Blink(pinLED, sLED, time_led, 1, 1);
      }
      else
      {
        // 000x x110  LED1 BLINK --__--__--__-- ...machine_state 5
        // if (prev_machine_state != machine_state)
        // {
        //   Serial.println("machine state 5");
        // }
        // LED_Blink(pinLED, sLED, time_led, 0.6, 1);
        LED_Blink(pinLED, sLED, time_led, 0.6, 1);
      }
    }
  }
  if (!sT2E && sT2F)
  {
    // 000x 10xx LED1 BLINK -_-_-__-_-_-__ ... machine_state 6
    // if (prev_machine_state != machine_state)
    // {
    //   Serial.println("machine state 6");
    // }
    // LED_Blink(pinLED, sLED, time_led, 1, 3);
    LED_Blink(pinLED, sLED, time_led, 1, 3);
  }
  else if (!pump_is_on && !valve_is_on)
  {
    // 000x xx00 LED1 ON    -------------- ... machine_state 1
    // if (prev_machine_state != machine_state)
    // {
    //   Serial.println("machine state 1");
    // }
    // LED_Toggle(pinLED, sLED);
    if (!sLED)
    {
      LED_Toggle(pinLED, sLED);
    }
  }

#ifdef MQTT
  if ((WiFi.status() == WL_CONNECTED))
  {
    if (client.connected())
    {
      // xxxx xx11 LED2 ON    -------------- ... wifi_state
      if (!sLED_BIN)
      {
        LED_Toggle(BUILTIN_LED, sLED_BIN);
      }
    }
    else
    {
      // xxxx xx10 LED2 BLINK --__--__--__-- ... wifi_state
      LED_Blink(BUILTIN_LED, sLED_BIN, time_conn_led, 0.6, 1);
    }
  }
  else
  {
    if (client.connected())
    {
      // xxxx xx01 LED2 BLINK -_-__-_-__-_-_ ... wifi_state
      LED_Blink(BUILTIN_LED, sLED_BIN, time_conn_led, 1, 2);
    }
    else
    {
      // xxxx xx00 LED2 BLINK -_-_-_-_-_-_-_ ... wifi_state
      LED_Blink(BUILTIN_LED, sLED_BIN, time_conn_led, 1, 1);
    }
  }
#endif
}

void apply_outputs()
{
#ifdef SIMUL
  // send also INPUT states, for verification on "terminal side"
  uint8_t sn = (sLED << 5) | (sT3F << 2) | (sT2F << 1) | (sT2E);
  if (last_sent_state != sn)
  {
    Serial.println(sn);
    last_sent_state = sn;
  }

#elif defined(MQTT)
  // send string to mqtt server
  // N.A. | N.A. | N.A. | T3F | T2F | T2E | P | V
  // if (last_message_mqtt >= MSGDELAY || (prev_machine_state != machine_state))
  if ((prev_machine_state != machine_state))
  {
    // last_message_mqtt = 0;
    char *payload = uint8_to_binary(machine_state);

    client.publish(mqtt_channel_pub, (char *)payload);

    // also send string throught serial
    Serial.println(mqtt_channel_pub);
    Serial.println(payload);
  }
  // update_counter(last_message_mqtt);

#elif defined(PROCESSING)

  devState = (pump_is_on << 4) | (valve_is_on << 3);
  Serial.println(devState);
  delay(2000);

#else
  // digitalWrite(pinLED, sLED);
  if ((prev_machine_state != machine_state))
  {
    Serial.println(machine_state, BIN);
  }

#endif
  digitalWrite(pinV, valve_is_on);
  digitalWrite(pinP, pump_is_on);
  // this line is commented before and put here, in order to have
  // at least the status LED
  // digitalWrite(pinLED, sLED);
  // digitalWrite(BUILTIN_LED, sLED_BIN);
}

//////////////////////////////////
// FSM BEHAVIOUR
//////////////////////////////////
// void turn_off_pump_INT()
// {
//   // turn off pump here if interupt is needed
//   update_counter(time_pump_on);
//   pump_is_on = 0;
//   digitalWrite(pinP, pump_is_on);
// }

void update_counter(uint32_t &counter)
{
  counter += (millis() - last_time);
}

void pump_logic()
{
  // logic for pump
  if (pump_is_on == 1)
  {
    // passing of time check
    update_counter(time_pump_on);

    if (time_pump_on >= PUMPTIME || sT2E == 0 || sT3F == 1)
    {
      pump_is_on = 0;
    }
  }
  else
  {
    // passing of time check
    if (time_pump_off < time_pump_on)
    {
      update_counter(time_pump_off);
    }

    if (time_pump_off >= time_pump_on && sT3F == 0 && sT2E == 1)
    {
      pump_is_on = 1;
      time_pump_off = 0;
      time_pump_on = 0;
    }
  }
}

void valve_logic()
{
  // logic for valve
  if (valve_is_on == 1)
  {
    // passing of time check
    if (time_valve_on < VALVETIME)
    {
      update_counter(time_valve_on);
    }
    if (time_valve_on >= VALVETIME && sT2E == 0)
    {
      time_valve_on = VALVEOFF;
      valve_is_on = 0;
    }
    if (sT2F == 1)
    {
      time_valve_on = 0;
      valve_is_on = 0;
    }
  }
  else
  {
    // passing of time check
    if (time_valve_on >= VALVEOFF)
    {
      if (time_valve_off < time_valve_on)
      {
        update_counter(time_valve_off);
      }
    }
    if (time_valve_off >= time_valve_on && sT2F == 0)
    {
      valve_is_on = 1;
      time_valve_off = 0;
      time_valve_on = 0;
    }
  }
}

// LED SYSTEM
void LED_Toggle(int LED, bool &led_state)
{
  led_state = !led_state;
  digitalWrite(LED, led_state);
}

// period_multiplier and dc_fractions must normally be 1
void LED_Blink(int LED, bool &led_state, uint32_t &ltl, double period_multiplier, int dc_fractions)
{
  update_counter(ltl);
  if (prev_machine_state != machine_state)
  {
    if (led_state == 0)
    {
      LED_Toggle(LED, led_state);
    }
    dc_todo = dc_fractions;
    ltl = 0;
  }

  if (led_state == 0 && dc_todo <= 0)
  {
    if (ltl >= period_led * period_multiplier)
    {
      LED_Toggle(LED, led_state);
      dc_todo = dc_fractions;
      ltl = 0;
    }
  }
  else
  {
    if (ltl >= ((period_led * period_multiplier) / dc_fractions) && dc_todo > 0)
    {
      LED_Toggle(LED, led_state);
      ltl = 0;
      if (led_state == 0)
      {
        dc_todo -= 1;
      }
    }
  }
}

#ifdef MQTT
//////////////////////////////////
// WIFI
//////////////////////////////////
void connect_wifi()
{
  if (WiFi.status() != WL_CONNECTED)
  {
    delay(10);
    // We start by connecting to a WiFi network
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(ssid);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);

    while (WiFi.status() != WL_CONNECTED)
    {
      delay(500);
      Serial.print(".");
    }

    randomSeed(micros());

    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
  }
}

void reconnect_mqtt_broker()
{
  // Loop until we're reconnected
  while (!client.connected())
  {
    connect_wifi();

    Serial.print("Attempting MQTT connection...");
    // Create a random client ID
    String clientId = "ESP8266Client-";
    // clientId += String(random(0xffff), HEX);                     // COMMENT TO USE ONLINE BROKER
    // Attempt to connect
    // if (client.connect(clientId.c_str()) {                       // COMMENT TO USE ONLINE BROKER
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pwd))
    { // UNCOMMENT TO USE ONLINE BROKER
      Serial.println("connected");
      // Once connected, publish an announcement...
      // client.publish("TEST", "hello world");
      // ... or resubscribe
      client.subscribe(mqtt_channel_sub);
    }
    else
    {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

void callback(char *topic, byte *payload, unsigned int length)
{
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  char *text;
  for (int i = 0; i < length; i++)
  {
    Serial.print((char)payload[i]);
    text += (char)payload[i];
  }
  Serial.println();
  client.publish(mqtt_channel_pub, text);
}

void keep_alive_mqtt()
{
  if (!client.connected())
  {
    reconnect_mqtt_broker();
  }
  client.loop();
}
#endif

char *uint8_to_binary(uint8_t value)
{
  char *binary_str = new char[9]; // Allocate space for 8 bits + '\0'
  binary_str[8] = '\0';           // Set the terminating null character

  for (int i = 7; i >= 0; i--)
  {
    binary_str[i] = (value & 0x01) ? '1' : '0'; // Extract the i-th bit
    value >>= 1;                                // Shift the value right by one bit
  }

  return binary_str;
}
