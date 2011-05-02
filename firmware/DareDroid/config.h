#ifndef CONFIG_H_
#define CONFIG_H_

// Define this if we want debug output on serial
#define DEBUG
// Define this if we're running on an Arduino simulator board
#define SIMULATOR
// Define this if we're using the ADS7828 sensor
//#define USE_ADS7828

#include <avr/io.h>

#define IO_PORT	PORTD
#define IO_DDR	DDRD
#define IO_PIN	PIND

#define SW1		PD5 // Arduino pin 5
#define LS1		PD6 // Arduino pin 6
#define LS2		PD7 // Arduino pin 7
#define LED1 6
#define LED2 7

#define ADBAT	0
#define ADPRES	1

#define PCF8574_ADDR 0x38
#define PCF8591_ADDR 0x48
#define ADS7828_ADDR 0x48

#endif


