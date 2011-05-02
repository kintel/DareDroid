// Graphingstring sketch
 
 
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

PFont fontA;

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

  fontA = loadFont("SansSerif-24.vlw");
  textAlign(CENTER);
  textFont(fontA, 24);

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
}

void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');
  if (inString == null) return;
  println(inString);

  String[] tokens = split(inString, ' ');
  if (tokens.length != 2) return;
  int param = int(trim(tokens[1]));
  if (param == 0) fill(0);
  stroke(0,0,0,255);
  if (tokens[0].equals("State")) {
  }
  else if (tokens[0].equals("Button")) {
  }
  else if (tokens[0].equals("Reset")) {
  }
  else if (tokens[0].equals("JUICE")) {
    if (param == 1) {
      fill(255);
      stroke(255);
    }
    text("Juice", 200, 200);
  }
  else if (tokens[0].equals("VODKA")) {
    if (param == 1) fill(255);
    text("Vodka", 200, 220);
  }
  else if (tokens[0].equals("HEART_LED")) {
    if (param == 1) fill(255,0,255);
    ellipse(200, 300, 16,16);
  }
  else if (tokens[0].equals("BLUE_LED_1")) {
    if (param == 1) fill(0,0,255);
    ellipse(140,270,16,16);
  }
  else if (tokens[0].equals("BLUE_LED_2")) {
    if (param == 1) fill(0,0,255);
    ellipse(160,270,16,16);
  }
  else if (tokens[0].equals("WHITE_LED_1")) {
    if (param == 1) fill(255);
    ellipse(180,270,16,16);
  }
  else if (tokens[0].equals("WHITE_LED_2")) {
    if (param == 1) fill(255);
    ellipse(200,270,16,16);
  }
  else if (tokens[0].equals("RED_LED")) {
    if (param == 1) fill(255,0,0);
    ellipse(220,270,16,16);
  }
}

