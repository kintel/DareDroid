#ifndef VALVES_H_
#define VALVES_H_

#define VALVES		8
#define VALVE(__x)	(1 << (__x))
#define ALL_VALVES	0xff

bool init_valves();
#define open_valves(mask) set_valves(mask, true)
#define close_valves(mask) set_valves(mask, false)
void set_valves(uint8_t mask, bool on);
void flip_valves();

#endif
