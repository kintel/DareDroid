/*
  DareDroid firmware

  This is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
  
  Copyright 2010 Marius Kintel <marius@kintel.net>

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

//#define USE_IR_SENSORS

// Valve & LED mapping
#define MILK_VALVES   VALVE(0) | VALVE(1)
#define VODKA_VALVES  VALVE(2)
#define KAHLUA_VALVES VALVE(3)
#define RED_LED_VALVE VALVE(5)
#define GREEN_LED_VALVE  VALVE(6)
#define CUP_LED_VALVE VALVE(7)

// Sensor mapping
#define IR_SENSOR_1          5
#define IR_SENSOR_2          4
#define IR_SENSOR_3          6
#define IR_SENSOR_4          7
#define VODKA_BUTTON_SENSOR  0
#define KAHLUA_BUTTON_SENSOR 0
#define MILK_BUTTON_SENSOR   1

// Timers in milliseconds
// Roboexotica opening timing
#define MILK_TIME 15000
#define VODKA_TIME 15000
#define KAHLUA_TIME 15000
// New accufuser timing
// #define MILK_TIME 6000
// #define VODKA_TIME 6000
// #define KAHLUA_TIME 6000

#define RED_LED_ON_TIME  100
#define RED_LED_OFF_TIME 900
#define GREEN_LED_ON_TIME  100
#define GREEN_LED_OFF_TIME 900
#define CUP_LED_ON_TIME  100
#define CUP_LED_OFF_TIME 500
#define SHUTDOWN_TIME 120000

#define PROXIMITY_THRESHOLD       30
#define PROXIMITY_ALERT_THRESHOLD 80

#define BUTTON_MAX 10
#define PROXIMITY_MAX 500

byte system_state = 0;
enum SystemState {
  STATE_OFF,
  STATE_ACTIVE,
  STATE_RUNNING,
  STATE_SHUTDOWN
};

byte production_state = 0;
#define PRODUCING_MILK   0x01
#define PRODUCED_MILK    0x02
#define PRODUCING_VODKA  0x04
#define PRODUCED_VODKA   0x08
#define PRODUCING_KAHLUA 0x10
#define PRODUCED_KAHLUA  0x20

byte drinks_produced = 0;

byte events = 0;
#define MILK_BUTTON_EVENT   0x01
#define VODKA_BUTTON_EVENT  0x02
#define KAHLUA_BUTTON_EVENT 0x04
#define PROXIMITY_EVENT     0x08
#define PROXIMITY_ALERT     0x10

unsigned long currtime;
enum {
  MILK_TIMEOUT = 0,
  VODKA_TIMEOUT = 1,
  KAHLUA_TIMEOUT = 2,
  SHUTDOWN_TIMEOUT = 3,
  RED_LED_TIMEOUT = 4,
  GREEN_LED_TIMEOUT = 5,
  CUP_LED_TIMEOUT = 6
};
unsigned long timeouts[7] = {0,0,0,0,0,0,0};

#define MILK_BUTTON_ID 0
#define VODKA_BUTTON_ID 1
#define KAHLUA_BUTTON_ID 2
#define PROXIMITY_ID 3
#define PROXIMITY_ALERT_ID 4
uint16_t button_counters[5] = {0,0,0,0,0};

enum LedIds {
  RED_LED,
  GREEN_LED,
  CUP_LED
};
enum LedStates {
  LED_OFF,
  LED_ON,
  LED_BLINK_OFF,
  LED_BLINK_ON
};
byte led_states[3] = {LED_OFF, LED_OFF, LED_OFF};

/*!
  Sets LED state and initialized timeouts for blinking.
  Doesn't touch the LEDs, call handle_leds() for that.
 */
void set_LED_state(byte led, byte state)
{
  led_states[led] = state;
  if (state == LED_BLINK_OFF || state == LED_BLINK_ON) {
    switch (led) {
    case RED_LED:
      timeouts[RED_LED_TIMEOUT] = millis() + RED_LED_ON_TIME;
      break;
    case GREEN_LED:
      timeouts[GREEN_LED_TIMEOUT] = millis() + GREEN_LED_ON_TIME;
      break;
    case CUP_LED:
      timeouts[CUP_LED_TIMEOUT] = millis() + CUP_LED_ON_TIME;
      break;
    }
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
    close_valves(RED_LED_VALVE);
    break;
  case LED_ON:
  case LED_BLINK_ON:
    open_valves(RED_LED_VALVE);
    break;
  }

  switch (led_states[GREEN_LED]) {
  case LED_OFF:
  case LED_BLINK_OFF:
    close_valves(GREEN_LED_VALVE);
    break;
  case LED_ON:
  case LED_BLINK_ON:
    open_valves(GREEN_LED_VALVE);
    break;
  }

  switch (led_states[CUP_LED]) {
  case LED_OFF:
  case LED_BLINK_OFF:
    close_valves(CUP_LED_VALVE);
    break;
  case LED_ON:
  case LED_BLINK_ON:
    open_valves(CUP_LED_VALVE);
    break;
  }
}

enum Substance {
  MILK,
  VODKA,
  KAHLUA
};

/*!
  Start producing a substance -> turn on valves, start timers, update CUP LED
*/
void start_production(byte substance)
{
  switch (substance) {
  case MILK:
    open_valves(MILK_VALVES);
    timeouts[MILK_TIMEOUT] = millis() + MILK_TIME;
    production_state |= PRODUCING_MILK;
    break;
  case VODKA:
    open_valves(VODKA_VALVES);
    timeouts[VODKA_TIMEOUT] = millis() + VODKA_TIME;
    production_state |= PRODUCING_VODKA;
    break;
  case KAHLUA:
    open_valves(KAHLUA_VALVES);
    timeouts[KAHLUA_TIMEOUT] = millis() + KAHLUA_TIME;
    production_state |= PRODUCING_KAHLUA;
    break;
  }
  set_LED_state(CUP_LED, LED_BLINK_OFF);
}

/*!
  Stop producing a substance -> turn off valves, update CUP LED
*/
void stop_production(byte substance)
{
  switch (substance) {
  case MILK:
    close_valves(MILK_VALVES);
    production_state |= PRODUCED_MILK;
    production_state &= ~PRODUCING_MILK;
    break;
  case VODKA:
    close_valves(VODKA_VALVES);
    production_state |= PRODUCED_VODKA;
    production_state &= ~PRODUCING_VODKA;
    break;
  case KAHLUA:
    close_valves(KAHLUA_VALVES);
    production_state |= PRODUCED_KAHLUA;
    production_state &= ~PRODUCING_KAHLUA;
    break;
  }

  // If nothing is currently producing, turn off cup LED
  if (!(production_state & (PRODUCING_MILK | PRODUCING_VODKA | PRODUCING_KAHLUA))) {
    set_LED_state(CUP_LED, LED_OFF);
  }
}

/*!
  Manage all timer events
 */
void handle_timers()
{
  currtime = millis();

  // Handle blinking LEDs

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

  if (led_states[CUP_LED] == LED_BLINK_ON &&
      currtime > timeouts[CUP_LED_TIMEOUT]) {
    set_LED_state(CUP_LED, LED_BLINK_OFF);
    timeouts[CUP_LED_TIMEOUT] = currtime + CUP_LED_OFF_TIME;
  }
  else if (led_states[CUP_LED] == LED_BLINK_OFF &&
      currtime > timeouts[CUP_LED_TIMEOUT]) {
    set_LED_state(CUP_LED, LED_BLINK_ON);
    timeouts[CUP_LED_TIMEOUT] = currtime + CUP_LED_ON_TIME;
  }
  
  // Handle valve timers

  if ((production_state & PRODUCING_MILK) &&
      (currtime > timeouts[MILK_TIMEOUT])) {
    stop_production(MILK); 
  }
  if ((production_state & PRODUCING_VODKA) &&
      (currtime > timeouts[VODKA_TIMEOUT])) {
    stop_production(VODKA); 
  }
  if ((production_state & PRODUCING_KAHLUA) &&
      (currtime > timeouts[KAHLUA_TIMEOUT])) {
    stop_production(KAHLUA); 
  }

  // Shutdown timer
  // FIXME: No shutdown for now
  // if ((system_state == STATE_SHUTDOWN) &&
  //     (currtime > timeouts[SHUTDOWN_TIMEOUT])) {
  //   set_state(STATE_OFF);
  // }  
  // if ((system_state == STATE_SHUTDOWN) &&
  //     (events & PAD_EVENT)) {
  //   set_state(STATE_OFF);
  // }
}

/*!
  Sets system state and updates indicators
 */
void set_state(byte newstate)
{
  switch (newstate) {
  case STATE_OFF:
    production_state = 0;
    set_LED_state(RED_LED, LED_BLINK_ON);
    set_LED_state(GREEN_LED, LED_BLINK_ON);
    set_LED_state(CUP_LED, LED_OFF);
    button_counters[MILK_BUTTON_ID] = button_counters[VODKA_BUTTON_ID] = button_counters[KAHLUA_BUTTON_ID] = 0;
    break;
  case STATE_ACTIVE:
    set_LED_state(RED_LED, LED_BLINK_ON);
    set_LED_state(GREEN_LED, LED_BLINK_ON);
    set_LED_state(CUP_LED, LED_OFF);
    break;
  case STATE_RUNNING:
    break;
  case STATE_SHUTDOWN:
    set_LED_state(RED_LED, LED_BLINK_OFF);
    set_LED_state(GREEN_LED, LED_OFF);
    set_LED_state(CUP_LED, LED_OFF);
    timeouts[SHUTDOWN_TIMEOUT] = millis() + SHUTDOWN_TIME;
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
  byte max_ir_value = max(get_last_sensor_value(IR_SENSOR_1), get_last_sensor_value(IR_SENSOR_2));
  max_ir_value = max(max_ir_value, get_last_sensor_value(IR_SENSOR_3));
  max_ir_value = max(max_ir_value, get_last_sensor_value(IR_SENSOR_4));

  if (max_ir_value > PROXIMITY_ALERT_THRESHOLD) {
    events |= PROXIMITY_ALERT;
    events &= ~PROXIMITY_EVENT;
  }
  else if (max_ir_value > PROXIMITY_THRESHOLD) {
    events |= PROXIMITY_EVENT;
    events &= ~PROXIMITY_ALERT;
  }

  // Debounce sensor reading
  if (max_ir_value > PROXIMITY_ALERT_THRESHOLD) {
    if (button_counters[PROXIMITY_ALERT_ID] < PROXIMITY_MAX) {
      button_counters[PROXIMITY_ALERT_ID]++;
    }
    if (button_counters[PROXIMITY_ALERT_ID] == PROXIMITY_MAX) {
      events |= PROXIMITY_ALERT;
      events &= ~PROXIMITY_EVENT;
    }
  }
  else {
    if (button_counters[PROXIMITY_ALERT_ID] > 0) {
      button_counters[PROXIMITY_ALERT_ID]--;
    }
    if (button_counters[PROXIMITY_ALERT_ID] == 0) {
      events &= ~PROXIMITY_ALERT;
    }

    if (max_ir_value > PROXIMITY_THRESHOLD) {
      if (button_counters[PROXIMITY_ID] < PROXIMITY_MAX) {
        button_counters[PROXIMITY_ID]++;
      }
      if (button_counters[PROXIMITY_ID] == PROXIMITY_MAX) {
        events |= PROXIMITY_EVENT;
      }
    }
    else {
      if (button_counters[PROXIMITY_ID] > 0) {
        button_counters[PROXIMITY_ID]--;
      }
      if (button_counters[PROXIMITY_ID] == 0) {
        events &= ~PROXIMITY_EVENT;
      }
    }
  }
#endif // USE_IR_SENSORS

  // Debounce buttons and trigger button events
  if (get_last_sensor_value(MILK_BUTTON_SENSOR) < 50) {
    if (button_counters[MILK_BUTTON_ID] < BUTTON_MAX) {
      button_counters[MILK_BUTTON_ID]++;
    }
    if (button_counters[MILK_BUTTON_ID] == BUTTON_MAX) {
      events |= MILK_BUTTON_EVENT;
    }
  }
  else {
    if (button_counters[MILK_BUTTON_ID] > 0) {
      button_counters[MILK_BUTTON_ID]--;
    }
    if (button_counters[MILK_BUTTON_ID] == 0) {
      events &= ~MILK_BUTTON_EVENT;
    }
  }

  if (get_last_sensor_value(VODKA_BUTTON_SENSOR) < 50) {
    if (button_counters[VODKA_BUTTON_ID] < BUTTON_MAX) {
      button_counters[VODKA_BUTTON_ID]++;
    }
    if (button_counters[VODKA_BUTTON_ID] == BUTTON_MAX) {
      events |= VODKA_BUTTON_EVENT;
    }
  }
  else {
    if (button_counters[VODKA_BUTTON_ID] > 0) {
      button_counters[VODKA_BUTTON_ID]--;
    }
    if (button_counters[VODKA_BUTTON_ID] == 0) {
      events &= ~VODKA_BUTTON_EVENT;
    }
  }

  if (get_last_sensor_value(KAHLUA_BUTTON_SENSOR) < 50) {
    if (button_counters[KAHLUA_BUTTON_ID] < BUTTON_MAX) {
      button_counters[KAHLUA_BUTTON_ID]++;
    }
    if (button_counters[KAHLUA_BUTTON_ID] == BUTTON_MAX) {
      events |= KAHLUA_BUTTON_EVENT;
    }
  }
  else {
    if (button_counters[KAHLUA_BUTTON_ID] > 0) {
      button_counters[KAHLUA_BUTTON_ID]--;
    }
    if (button_counters[KAHLUA_BUTTON_ID] == 0) {
      events &= ~KAHLUA_BUTTON_EVENT;
    }
  }

  // FIXME: Workaround for missing IR sensors, use same button for milk, 
  // but don't activate booze while milk is running
#ifndef USE_IR_SENSORS
  if (events & MILK_BUTTON_EVENT) {
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
  Serial.println("Boozebabe!");

  // Turn off board status LEDs
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);

  Wire.begin();
  delay(10);
  
  bool valves_ok = init_valves();
  bool sensors_ok = init_sensors();
  close_all_valves();

  // Briefly pulse LEDs to indicate sensor status
  if (valves_ok) IO_PORT |= (_BV(LS1));
  if (sensors_ok) IO_PORT |= (_BV(LS2));
  if (valves_ok && sensors_ok) {
    delay(800);
    IO_PORT &= ~(_BV(LS1) | _BV(LS2));
  } else {
    Serial.println("Boozebabe init error");
    // Loop while blinking LEDs on sensor error
    for (;;) {
      if (!valves_ok) IO_PORT |= (_BV(LS1));
      if (!sensors_ok) IO_PORT |= (_BV(LS2));
      delay(500);
      IO_PORT &= ~(_BV(LS1) | _BV(LS2));
      delay(300);
    }
  }
  Serial.println("Boozebabe ready");

  // System will be deactivated initially
  set_state(STATE_OFF);
  // FIXME: Workaround: Always in ON state
  set_state(STATE_ACTIVE);
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

  // Proximity alert overrides everything
  if (events & PROXIMITY_ALERT) {
    set_state(STATE_SHUTDOWN);
  }
  else {
    // If all has been produced, set back state to OFF
    if ((production_state & (PRODUCED_MILK | PRODUCED_VODKA | PRODUCED_KAHLUA)) ==
        (PRODUCED_MILK | PRODUCED_VODKA | PRODUCED_KAHLUA)) {
      //      set_state(STATE_OFF);
      // FIXME: Workaround: always on
      set_state(STATE_OFF);
      set_state(STATE_ACTIVE);
      drinks_produced++;
    }
    // FIXME: Workaround: Disable pad
    // if (events & PAD_EVENT) {
    //   if (system_state == STATE_OFF) set_state(STATE_ACTIVE);
    //   else set_state(STATE_OFF);
    // }
    if (system_state == STATE_ACTIVE && (events & PROXIMITY_EVENT)) {
      set_state(STATE_RUNNING);
      start_production(MILK);
    }
    if (system_state == STATE_RUNNING && (events & VODKA_BUTTON_EVENT)) {
      // Produce vodka if not already done

      // FIXME: Workaround for missing IR sensors, use same button for milk, 
      // but don't activate booze while milk is running
#ifndef USE_IR_SENSORS
      if (production_state & PRODUCED_MILK) {
#endif
        if (!(production_state & (PRODUCING_VODKA | PRODUCED_VODKA))) {
          start_production(VODKA);
        }
#ifndef USE_IR_SENSORS
      }
#endif
    }
    if (system_state == STATE_RUNNING && (events & KAHLUA_BUTTON_EVENT)) {
      // Produce vodka if not already done

      // FIXME: Workaround for missing IR sensors, use same button for milk, 
      // but don't activate booze while milk is running
#ifndef USE_IR_SENSORS
      if (production_state & PRODUCED_MILK) {
#endif
        if (!(production_state & (PRODUCING_KAHLUA | PRODUCED_KAHLUA))) {
          start_production(KAHLUA);
        }
#ifndef USE_IR_SENSORS
      }
#endif
    }
  }
}
