/*
  DareDroid firmware

  This is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
  
  Copyright 2010-2011 Marius Kintel <marius@kintel.net>

  Arduino simulator connector:
  1 - GND Black
  2 - SDA Yellow
  3 - SCL Blue
  4 - Vcc Red
 */

#include "config.h"
#include "valves.h"
#include "sensors.h"

#include <Wire.h>

#define USE_IR_SENSORS

#define SENSOR_LEVEL_1 20
#define SENSOR_LEVEL_2 40
#define SENSOR_LEVEL_3 60
#define SENSOR_LEVEL_4 80
#define SENSOR_LEVEL_5 100
#define PROXIMITY_ALERT_THRESHOLD SENSOR_LEVEL_5

// Valve & LED mapping
#define JUICE_VALVE       VALVE(0)
#define VODKA_VALVE       VALVE(1)
#define HEART_LED_VALVE   VALVE(2)
#define BLUE_LED_1_VALVE  VALVE(3)
#define BLUE_LED_2_VALVE  VALVE(4)
#define WHITE_LED_1_VALVE VALVE(5)
#define WHITE_LED_2_VALVE VALVE(6)
#define RED_LED_VALVE     VALVE(7)

// Sensor mapping
#define IR_SENSOR_1             0
#define IR_SENSOR_2             1
#define DISPENSER_BUTTON_SENSOR 2
#define RESET_BUTTON_SENSOR     3

// Timers in milliseconds
// Roboexotica opening timing
#define JUICE_TIME 15000
#define VODKA_TIME 15000
// New accufuser timing
// #define JUICE_TIME 6000
// #define VODKA_TIME 6000

#define RED_LED_ON_TIME  50
#define RED_LED_OFF_TIME 50
#define HEART_LED_ON_TIME  100
#define HEART_LED_OFF_TIME 500

#define BUTTON_MAX 10
#define PROXIMITY_MAX 500

enum SystemState {
  STATE_OFF,
  STATE_ACTIVE,
  STATE_DARE,
  STATE_FREEZE
};
byte system_state = STATE_OFF;
byte previous_state = STATE_OFF;

byte production_state = 0;
#define PRODUCING_JUICE   0x01
#define PRODUCED_JUICE    0x02
#define PRODUCING_VODKA  0x04
#define PRODUCED_VODKA   0x08

byte drinks_produced = 0;

byte events = 0;
#define DISPENSER_BUTTON_DOWN    0x01
#define DISPENSER_BUTTON_CLICKED 0x02
#define RESET_BUTTON_DOWN        0x04
#define RESET_BUTTON_CLICKED     0x08
#define PROXIMITY_ALERT          0x10

unsigned long currtime;
enum {
  JUICE_TIMEOUT = 0,
  VODKA_TIMEOUT = 1,
  RED_LED_TIMEOUT = 4,
  HEART_LED_TIMEOUT = 6
};
unsigned long timeouts[7] = {0,0,0,0,0,0,0};

#define DISPENSER_BUTTON_ID 0
#define RESET_BUTTON_ID 1
#define PROXIMITY_ALERT_ID 2
uint16_t button_counters[3] = {0,0,0};

enum LedIds {
  HEART_LED,
  BLUE_LED_1,
  BLUE_LED_2,
  WHITE_LED_1,
  WHITE_LED_2,
  RED_LED,
};
enum LedStates {
  LED_OFF,
  LED_ON,
  LED_BLINK_OFF,
  LED_BLINK_ON
};
byte led_states[6] = {LED_OFF, LED_OFF, LED_OFF, LED_OFF, LED_OFF, LED_OFF};

byte current_proximity = 0;

/*!
  Sets LED state and initialized timeouts for blinking.
  Doesn't touch the LEDs, call handle_leds() for that.
 */
void set_LED_state(byte led, byte state)
{
  if (led_states[led] != state) {
    led_states[led] = state;
// #ifdef SIMULATOR
//     Serial.print("LED ");
//     Serial.print(led, DEC);
//     Serial.print(": ");
//     Serial.println(state, DEC);
// #endif  
  }
  // if (state == LED_BLINK_OFF || state == LED_BLINK_ON) {
  //   switch (led) {
  //   case RED_LED:
  //     timeouts[RED_LED_TIMEOUT] = millis() + RED_LED_ON_TIME;
  //     break;
  //   case HEART_LED:
  //     timeouts[HEART_LED_TIMEOUT] = millis() + HEART_LED_ON_TIME;
  //     break;
  //   }
  // }
}

void activateLED(int led, bool on)
{
  switch (led) {
  case HEART_LED:
    set_valves(HEART_LED_VALVE, on);
#ifdef DEBUG    
    Serial.print("RED_LED "); Serial.println(on, DEC);
#endif
    break;
  case BLUE_LED_1:
    set_valves(BLUE_LED_1_VALVE, on);
#ifdef DEBUG    
    Serial.print("BLUE_LED_1 "); Serial.println(on, DEC);
#endif
    break;
  case BLUE_LED_2:
    set_valves(BLUE_LED_2_VALVE, on);
#ifdef DEBUG    
    Serial.print("BLUE_LED_2 "); Serial.println(on, DEC);
#endif
    break;
  case WHITE_LED_1:
    set_valves(WHITE_LED_1_VALVE, on);
#ifdef DEBUG    
    Serial.print("WHITE_LED_1 "); Serial.println(on, DEC);
#endif
    break;
  case WHITE_LED_2:
    set_valves(WHITE_LED_2_VALVE, on);
#ifdef DEBUG    
    Serial.print("WHITE_LED_2 "); Serial.println(on, DEC);
#endif
    break;
  case RED_LED:
    set_valves(RED_LED_VALVE, on);
#ifdef DEBUG    
    Serial.print("RED_LED "); Serial.println(on, DEC);
#endif
    break;
  }
}

/*!
  Set the actual LEDs based on state.
*/
void handle_leds()
{
  switch (led_states[RED_LED]) {
  case LED_OFF:
  case LED_BLINK_OFF:
    activateLED(RED_LED_VALVE, false);
    break;
  case LED_ON:
  case LED_BLINK_ON:
    activateLED(RED_LED_VALVE, true);
    break;
  }

  // switch (led_states[HEART_LED]) {
  // case LED_OFF:
  // case LED_BLINK_OFF:
  //   activateLED(HEART_LED_VALVE, false);
  //   break;
  // case LED_ON:
  // case LED_BLINK_ON:
  //   activateLED(HEART_LED_VALVE, true);
  //   break;
  // }
}

enum Substance {
  JUICE,
  VODKA,
};

/*!
  Start producing a substance -> turn on valves, start timers, update HEART LED
*/
void start_production(byte substance)
{
  switch (substance) {
  case JUICE:
    open_valves(JUICE_VALVE);
#ifdef DEBUG
    Serial.println("JUICE 1");
#endif
    timeouts[JUICE_TIMEOUT] = millis() + JUICE_TIME;
    production_state |= PRODUCING_JUICE;
    break;
  case VODKA:
    open_valves(VODKA_VALVE);
#ifdef DEBUG
    Serial.println("VODKA 1");
#endif
    timeouts[VODKA_TIMEOUT] = millis() + VODKA_TIME;
    production_state |= PRODUCING_VODKA;
    break;
  }
  set_LED_state(HEART_LED, LED_BLINK_OFF);
}

/*!
  Stop producing a substance -> turn off valves, update HEART LED
*/
void stop_production(byte substance)
{
  switch (substance) {
  case JUICE:
    close_valves(JUICE_VALVE);
#ifdef DEBUG
    Serial.println("JUICE 0");
#endif
    production_state |= PRODUCED_JUICE;
    production_state &= ~PRODUCING_JUICE;
    break;
  case VODKA:
    close_valves(VODKA_VALVE);
#ifdef DEBUG
    Serial.println("VODKA 0");
#endif
    production_state |= PRODUCED_VODKA;
    production_state &= ~PRODUCING_VODKA;
    break;
  }

  // If nothing is currently producing, turn off cup LED
  if (!(production_state & (PRODUCING_JUICE | PRODUCING_VODKA))) {
    set_LED_state(HEART_LED, LED_OFF);
  }
}

/*!
  Manage all timer events
 */
void handle_timers()
{
  currtime = millis();

  // Handle blinking LEDs
#if 0
  if (led_states[RED_LED] == LED_BLINK_ON &&
      currtime > timeouts[RED_LED_TIMEOUT]) {
    set_LED_state(RED_LED, LED_BLINK_OFF);
    timeouts[RED_LED_TIMEOUT] = currtime + RED_LED_OFF_TIME;
  }
  else if (led_states[RED_LED] == LED_BLINK_OFF &&
      currtime > timeouts[RED_LED_TIMEOUT]) {
    set_LED_state(RED_LED, LED_BLINK_ON);
    timeouts[RED_LED_TIMEOUT] = currtime + RED_LED_ON_TIME;
  }

  if (led_states[GREEN_LED] == LED_BLINK_ON &&
      currtime > timeouts[GREEN_LED_TIMEOUT]) {
    set_LED_state(GREEN_LED, LED_BLINK_OFF);
    timeouts[GREEN_LED_TIMEOUT] = currtime + GREEN_LED_OFF_TIME;
  }
  else if (led_states[GREEN_LED] == LED_BLINK_OFF &&
      currtime > timeouts[GREEN_LED_TIMEOUT]) {
    set_LED_state(GREEN_LED, LED_BLINK_ON);
    timeouts[GREEN_LED_TIMEOUT] = currtime + GREEN_LED_ON_TIME;
  }
#endif

  if (led_states[HEART_LED] == LED_BLINK_ON &&
      currtime > timeouts[HEART_LED_TIMEOUT]) {
    set_LED_state(HEART_LED, LED_BLINK_OFF);
    timeouts[HEART_LED_TIMEOUT] = currtime + HEART_LED_OFF_TIME;
  }
  else if (led_states[HEART_LED] == LED_BLINK_OFF &&
      currtime > timeouts[HEART_LED_TIMEOUT]) {
    set_LED_state(HEART_LED, LED_BLINK_ON);
    timeouts[HEART_LED_TIMEOUT] = currtime + HEART_LED_ON_TIME;
  }
  
  // Handle valve timers

  if ((production_state & PRODUCING_JUICE) &&
      (currtime > timeouts[JUICE_TIMEOUT])) {
    stop_production(JUICE); 
  }
  if ((production_state & PRODUCING_VODKA) &&
      (currtime > timeouts[VODKA_TIMEOUT])) {
    stop_production(VODKA); 
  }

  // Freeze timer
  // FIXME: No freeze for now
  // if ((system_state == STATE_FREEZE) &&
  //     (currtime > timeouts[FREEZE_TIMEOUT])) {
  //   set_state(STATE_OFF);
  // }  
  // if ((system_state == STATE_FREEZE) &&
  //     (events & PAD_EVENT)) {
  //   set_state(STATE_OFF);
  // }
}

/*!
  Sets system state and updates indicators
 */
void set_state(byte newstate)
{
  if (system_state != newstate) {
#ifdef DEBUG
    Serial.print("State "); Serial.println(newstate, DEC);
#endif
  }
  switch (newstate) {
  case STATE_OFF:
    close_valves(ALL_VALVES);
    production_state = 0;
    button_counters[DISPENSER_BUTTON_ID] = button_counters[RESET_BUTTON_ID] = 0;
    break;
  case STATE_ACTIVE:
    // set_LED_state(RED_LED, LED_BLINK_ON);
    // set_LED_state(CUP_LED, LED_OFF);
    break;
  case STATE_DARE:
    break;
  case STATE_FREEZE:
    set_LED_state(RED_LED, LED_BLINK_OFF);
    break;
  }
  system_state = newstate;
}

/*!
  Read all inputs, debounce and create events
*/
void handle_inputs()
{
  read_all_sensors(); // Samples all analog inputs

#ifdef USE_IR_SENSORS
  // Find closest object
  current_proximity = max(get_last_sensor_value(IR_SENSOR_1), 
                          get_last_sensor_value(IR_SENSOR_2));
  set_LED_state(BLUE_LED_1, (current_proximity > SENSOR_LEVEL_1) ? LED_ON : LED_OFF);
  set_LED_state(BLUE_LED_2, (current_proximity > SENSOR_LEVEL_2) ? LED_ON : LED_OFF);
  set_LED_state(WHITE_LED_1, (current_proximity > SENSOR_LEVEL_3) ? LED_ON : LED_OFF);
  set_LED_state(WHITE_LED_2, (current_proximity > SENSOR_LEVEL_4) ? LED_ON : LED_OFF);
  set_LED_state(RED_LED, (current_proximity > SENSOR_LEVEL_5) ? LED_ON : LED_OFF);

  // "Debounce" sensor reading
  if (current_proximity > PROXIMITY_ALERT_THRESHOLD) {
    if (button_counters[PROXIMITY_ALERT_ID] < PROXIMITY_MAX) {
      button_counters[PROXIMITY_ALERT_ID]++;
    }
    if (button_counters[PROXIMITY_ALERT_ID] == PROXIMITY_MAX) {
      events |= PROXIMITY_ALERT;
    }
  }
  else {
    if (button_counters[PROXIMITY_ALERT_ID] > 0) {
      button_counters[PROXIMITY_ALERT_ID]--;
    }
    if (button_counters[PROXIMITY_ALERT_ID] == 0) {
      events &= ~PROXIMITY_ALERT;
    }
  }
#endif // USE_IR_SENSORS


  // Debounce buttons events

  if (button_counters[DISPENSER_BUTTON_ID] == 0) events &= ~DISPENSER_BUTTON_CLICKED;
  if (get_last_sensor_value(DISPENSER_BUTTON_SENSOR) < 50) {
    if (button_counters[DISPENSER_BUTTON_ID] < BUTTON_MAX) {
      button_counters[DISPENSER_BUTTON_ID]++;
    }
    if (button_counters[DISPENSER_BUTTON_ID] == BUTTON_MAX) {
      events |= DISPENSER_BUTTON_DOWN;
    }
  }
  else {
    if (button_counters[DISPENSER_BUTTON_ID] > 0) {
      button_counters[DISPENSER_BUTTON_ID]--;
    }
    if (button_counters[DISPENSER_BUTTON_ID] == 0) {
      if (events & DISPENSER_BUTTON_DOWN) {
        events |= DISPENSER_BUTTON_CLICKED;
#ifdef DEBUG
        Serial.println("Button 1");
#endif
      }
      events &= ~DISPENSER_BUTTON_DOWN;
    }
  }

  if (button_counters[RESET_BUTTON_ID] == 0) events &= ~RESET_BUTTON_CLICKED;
  if (get_last_sensor_value(RESET_BUTTON_SENSOR) < 50) {
    if (button_counters[RESET_BUTTON_ID] < BUTTON_MAX) {
      button_counters[RESET_BUTTON_ID]++;
    }
    if (button_counters[RESET_BUTTON_ID] == BUTTON_MAX) {
      events |= RESET_BUTTON_DOWN;
    }
  }
  else {
    if (button_counters[RESET_BUTTON_ID] > 0) {
      button_counters[RESET_BUTTON_ID]--;
    }
    if (button_counters[RESET_BUTTON_ID] == 0) {
      if (events & RESET_BUTTON_DOWN) {
        events |= RESET_BUTTON_CLICKED;
#ifdef DEBUG
        Serial.println("Reset 1");
#endif
      }
      events &= ~RESET_BUTTON_DOWN;
    }
  }

  // FIXME: Workaround for missing IR sensors, use same button for milk, 
  // but don't activate booze while milk is running
#ifndef USE_IR_SENSORS
  if (events & DISPENSER_BUTTON_EVENT) {
    events |= PROXIMITY_EVENT;
  }
  else {
    events &= ~PROXIMITY_EVENT;
  }
#endif // USE_IR_SENSORS
}

void setup()
{
  Serial.begin(57600);
  Serial.println("DareDroid!");

  // Turn off board status LEDs
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);

  Wire.begin();
  delay(10);
  
  bool valves_ok = init_valves();
  bool sensors_ok = init_sensors();
  close_valves(ALL_VALVES);

  // Briefly pulse LEDs to indicate sensor status
  if (valves_ok) IO_PORT |= (_BV(LS1));
#ifdef DEBUG
  else Serial.println("init_valves() failed");
#endif
  if (sensors_ok) IO_PORT |= (_BV(LS2));
#ifdef DEBUG
  else Serial.println("init_sensors() failed");
#endif
  if (valves_ok && sensors_ok) {
    delay(800);
    IO_PORT &= ~(_BV(LS1) | _BV(LS2));
  } else {
    Serial.println("DareDroid init error");
    // Loop while blinking LEDs on sensor error
    for (;;) {
      if (!valves_ok) IO_PORT |= (_BV(LS1));
      if (!sensors_ok) IO_PORT |= (_BV(LS2));
      delay(500);
      IO_PORT &= ~(_BV(LS1) | _BV(LS2));
      delay(300);
    }
  }
  Serial.println("DareDroid ready");

  // System will be deactivated initially
  set_state(STATE_OFF);
}

/*!
  Call this to provide a heartbeat in the form of a blinking LED
*/
void heartbeat()
{
  static unsigned long next_heartbeat = 0;
  unsigned long currtime = millis();
  if (currtime > next_heartbeat) {
    if (IO_PORT & _BV(LS1)) {
      IO_PORT &= ~_BV(LS1);
      next_heartbeat = currtime + 900;
    }
    else {
      IO_PORT |= _BV(LS1);
      next_heartbeat = currtime + 100;
    }
  }
}

void loop()
{
  heartbeat();
  handle_inputs();
  handle_leds();
  handle_timers();


  //
  // State management
  //

  // Proximity alert overrides everything
  if ((events & PROXIMITY_ALERT) && (system_state != STATE_FREEZE)) {
    previous_state = system_state;
    set_state(STATE_FREEZE);
  }
  else if (system_state == STATE_FREEZE) {
    set_state(previous_state);
  }
  else {
    if (events & RESET_BUTTON_CLICKED) {
      if (system_state == STATE_OFF) set_state(STATE_ACTIVE);
      else set_state(STATE_OFF);
    }

    // If all has been produced, set back state to ACTIVE
    if ((production_state & (PRODUCED_JUICE | PRODUCED_VODKA)) ==
        (PRODUCED_JUICE | PRODUCED_VODKA)) {
      set_state(STATE_ACTIVE);
      drinks_produced++;
    }
    if (system_state == STATE_ACTIVE && (events & DISPENSER_BUTTON_CLICKED)) {
      set_state(STATE_DARE);
      start_production(JUICE);
    }
    if (system_state == STATE_DARE && (events & DISPENSER_BUTTON_CLICKED)) {
      // Produce vodka if not already done
      if (production_state & PRODUCED_JUICE) {
        if (!(production_state & (PRODUCING_VODKA | PRODUCED_VODKA))) {
          start_production(VODKA);
        }
      }
    }
  }
}
