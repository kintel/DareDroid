#ifndef VALVES_H_
#define VALVES_H_

#define VALVES		8
#define VALVE(__x)	(1 << (__x))
#define ALL_VALVES	0xff
#define NO_VALVES	0x00

bool init_valves();
void open_valves(uint8_t mask);
void close_valves(uint8_t mask);
void set_valves(uint8_t mask);
void flip_valves();

#define close_all_valves()	set_valves(NO_VALVES)
#define open_all_valves()	set_valves(ALL_VALVES)

#endif
