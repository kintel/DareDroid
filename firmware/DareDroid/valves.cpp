/*
  DareDroid firmware

  This is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
  
  Copyright 2010 Marius Kintel <marius@kintel.net>
*/

#include <WProgram.h>
#include "valves.h"
#include "config.h"
#include <Wire.h>

uint8_t __valve_status;

#ifdef SIMULATOR
#define VALVEPIN_1 8
#define VALVEPIN_2 9
#define VALVEPIN_3 10
#define VALVEPIN_4 11
#define VALVEPIN_5 12
#define VALVEPIN_6 13
#define VALVEPIN_7 16
#define VALVEPIN_8 17

void send_valve_status(uint8_t status)
{
  digitalWrite(VALVEPIN_1, status & 0x01);
  digitalWrite(VALVEPIN_2, status & 0x02);
  digitalWrite(VALVEPIN_3, status & 0x04);
  digitalWrite(VALVEPIN_4, status & 0x08);
  digitalWrite(VALVEPIN_5, status & 0x10);
  digitalWrite(VALVEPIN_6, status & 0x20);
  digitalWrite(VALVEPIN_7, status & 0x40);
  digitalWrite(VALVEPIN_8, status & 0x80);
}
#else
void send_valve_status(uint8_t status)
{
  Wire.beginTransmission(PCF8574_ADDR);
  Wire.send(status);
  Wire.endTransmission();
}
#endif

// Returns true if OK, false if we cannot communicate with valves
bool init_valves()
{
#ifndef SIMULATOR
  Wire.beginTransmission(PCF8574_ADDR);
  return (Wire.endTransmission() == 0);
#else
  pinMode(VALVEPIN_1, OUTPUT);
  pinMode(VALVEPIN_2, OUTPUT);
  pinMode(VALVEPIN_3, OUTPUT);
  pinMode(VALVEPIN_4, OUTPUT);
  pinMode(VALVEPIN_5, OUTPUT);
  pinMode(VALVEPIN_6, OUTPUT);
  pinMode(VALVEPIN_7, OUTPUT);
  return true;
#endif
}

void set_valves(uint8_t mask, bool on)
{
  if (on) __valve_status |= mask;
  else __valve_status &= ~(mask);
  send_valve_status(__valve_status);
}

void flip_valves()
{
  __valve_status = ~(__valve_status);
  send_valve_status(__valve_status);
}
