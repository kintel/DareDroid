/*
  DareDroid firmware

  This is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
  
  Copyright 2010 Marius Kintel <marius@kintel.net>
*/

#include "config.h"
#ifndef USE_ADS7828

#include "sensors.h"
#include <Wire.h>

int sensor_values[8];

// Returns true if OK, false if we cannot communicate with sensors
bool init_sensors()
{
  Wire.beginTransmission(PCF8591_ADDR);
  byte ret1 = Wire.endTransmission();
#ifndef SIMULATOR
  Wire.beginTransmission(PCF8591_ADDR + 1);
  byte ret2 = Wire.endTransmission();
#else
  byte ret2 = 0;
#endif
  return (ret1 == 0) && (ret2 == 0);
}

int read_sensor(byte sensor)
{
  sensor &= 0x07;
  byte address;
  byte channel;
  if (sensor <= 3) {
    address = PCF8591_ADDR;
    channel = sensor;
  }
  else {
    address = PCF8591_ADDR + 1;
    channel = sensor - 4;
  }

  Wire.beginTransmission(address);
  Wire.send(channel);
  Wire.endTransmission();
  Wire.requestFrom(address, byte(2));
  byte val = 0;
  if (Wire.available() >= 2) {
    Wire.receive(); // Previous sample
    val = sensor_values[sensor] = Wire.receive();
  }
  return val;
}

void read_all_sensors()
{
  for (byte chip=0;chip<2;chip++) {
    Wire.beginTransmission(PCF8591_ADDR + chip);
    Wire.send(0x04); // Auto-increment
    Wire.endTransmission();
    Wire.requestFrom(PCF8591_ADDR + chip, 5);
    if (Wire.available() >= 4) {
      Wire.receive(); // Previous sample
      for (byte i=0;i<4;i++) {
        sensor_values[i + chip*4] = Wire.receive();
      }
    }
  }
}

int get_last_sensor_value(byte sensor)
{
  return sensor_values[sensor & 0x07];
}

#endif
