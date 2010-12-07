/*
  DareDroid firmware

  This is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
  
  Copyright 2010 Marius Kintel <marius@kintel.net>
*/

#ifdef USE_ADS7828

#include "config.h"
#include "i2c_adc_ads7828.h"
#include "sensors.h"

int sensor_values[8];
i2c_adc_ads7828 adc;

byte sensors[8] = {
    adc.ku8DeviceID2 + adc.ku8DeviceCH0,
    adc.ku8DeviceID2 + adc.ku8DeviceCH1,
    adc.ku8DeviceID2 + adc.ku8DeviceCH2,
    adc.ku8DeviceID2 + adc.ku8DeviceCH3,
    adc.ku8DeviceID2 + adc.ku8DeviceCH4,
    adc.ku8DeviceID2 + adc.ku8DeviceCH5,
    adc.ku8DeviceID2 + adc.ku8DeviceCH6,
    adc.ku8DeviceID2 + adc.ku8DeviceCH7
};

// Returns true if OK, false if we cannot communicate with sensors
bool init_sensors()
{
  adc.begin();
  adc.setScale(sensors[7], 0, 255);
  Wire.beginTransmission(ADS7828_ADDR | i2c_adc_ads7828::ku8DeviceID2);
  byte ret = Wire.endTransmission();
  return (ret == 0);
}

int read_sensor(byte sensor)
{
  sensor &= 0x07;
  byte val = sensor_values[sensor] = adc.analogRead(sensors[sensor]);
  return val;
}

void read_all_sensors()
{
  for (byte i=0;i<8;i++) {
    sensor_values[i] = adc.analogRead(sensors[i]);
  }
}

int get_last_sensor_value(byte sensor)
{
  return sensor_values[sensor & 0x07];
}

#endif
