// Graphing sketch
 
 
// This program takes ASCII-encoded strings
// from the serial port at 9600 baud and graphs them. It expects values in the
// range 0 to 1023, followed by a newline, or newline and carriage return
 
// Created 20 Apr 2005
// Updated 18 Jan 2008
// by Tom Igoe
// This example code is in the public domain.
 
import processing.serial.*;
 
Serial myPort;        // The serial port
int xPos = 1;         // horizontal position of the graph

int SENSOR_LEVEL_1 = 20;
int SENSOR_LEVEL_2 = 40;
int SENSOR_LEVEL_3 = 60;
int SENSOR_LEVEL_4 = 80;
int SENSOR_LEVEL_5 = 100;

void setup () {
  // set the window size:
  size(1200, 1000);        
 
  // List all the available serial ports
  println(Serial.list());
  // I know that the first port in the serial list on my mac
  // is always my  Arduino, so I open Serial.list()[0].
  // Open whatever port is the one you're using.
  myPort = new Serial(this, Serial.list()[0], 57600);
  // don't generate a serialEvent() unless you get a newline character:
  myPort.bufferUntil('\n');
  // set inital background:
  clear();
}

void draw () {
  // everything happens in the serialEvent()
}

int mapsensorval(float val) {
  return int(map(val, 0, 255, 0, height*1.5));
}

void clear() {
  background(0);
  stroke(255);
  line(0, height-mapsensorval(25), width, height-mapsensorval(25));
  line(0, height-mapsensorval(50), width, height-mapsensorval(50));
  line(0, height-mapsensorval(100), width, height-mapsensorval(100));
  line(0, height-mapsensorval(150), width, height-mapsensorval(150));
}

float current_proximity = 0;
void drawLEDs() {
  Boolean[] leds = {false, false, false, false, false};
  leds[0] = (current_proximity > SENSOR_LEVEL_1);
  leds[1] = (current_proximity > SENSOR_LEVEL_2);
  leds[2] = (current_proximity > SENSOR_LEVEL_3);
  leds[3] = (current_proximity > SENSOR_LEVEL_4);
  leds[4] = (current_proximity > SENSOR_LEVEL_5);

  stroke(0,0,0,255);
  if (leds[0]) fill(0,0,255);
  else fill(0);
  ellipse(10,30,16,16);
  if (leds[1]) fill(0,0,255);
  else fill(0);
  ellipse(30,30,16,16);
  if (leds[2]) fill(255);
  else fill(0);
  ellipse(50,30,16,16);
  if (leds[3]) fill(255);
  else fill(0);
  ellipse(70,30,16,16);
  if (leds[4]) fill(255,0,0);
  else fill(0);
  ellipse(90,30,16,16);
}
 
void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');

  Boolean button = (inString.charAt(0) == 'B');
  Boolean reset = (inString.charAt(1) == 'R');
  inString = inString.substring(2);
 
  if (inString != null) {
    // trim off any whitespace:
    inString = trim(inString);
    // convert to an int and map to the screen height:

    float[] numbers = float(split(inString, " "));

    current_proximity = max(numbers[0], numbers[1]);
    drawLEDs();

    int sensor1 = mapsensorval(numbers[0]);
    int sensor2 = mapsensorval(numbers[1]);

    if (button) {
      stroke(255,255,255);
      fill(255);
    }
    else {
      stroke(0,0,0);
      fill(0);
    }
    ellipse(10,10,16,16);
    if (reset) {
      stroke(255,0,0);
      fill(255,0,0);
    }
    else {
      stroke(0,0,0);
      fill(0);
    }
    ellipse(30,10,16,16);
 
    // draw the line:
    stroke(0,34,255, 128);
    line(xPos, height, xPos, height - sensor1);
    stroke(255,34,0, 128);
    line(xPos, height, xPos, height - sensor2);
 
    // at the edge of the screen, go back to the beginning:
    if (xPos >= width) {
      xPos = 0;
      clear();
    } 
    else {
      // increment the horizontal position:
      xPos++;
    }
  }
}

