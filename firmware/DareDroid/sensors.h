#ifndef SENSORS_H_
#define SENSORS_H_

#include <WProgram.h>

bool init_sensors();
int read_sensor(byte sensor);
void read_all_sensors();
int get_last_sensor_value(byte sensor);

#endif
