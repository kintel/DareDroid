void setup()
{
  Serial.begin(57600);
  Serial.println("sensor test");
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(8, OUTPUT);
  pinMode(9, OUTPUT);
  pinMode(10, OUTPUT);
  pinMode(11, OUTPUT);
  pinMode(12, OUTPUT);
  pinMode(13, OUTPUT);
}

void loop()
{
  digitalWrite(2, true);
  digitalWrite(3, true);
  digitalWrite(8, true);
  digitalWrite(9, true);
  digitalWrite(10, true);
  digitalWrite(11, true);
  digitalWrite(12, true);
  digitalWrite(13, true);
  delay(2000);
  digitalWrite(2, false);
  digitalWrite(3, false);
  digitalWrite(8, false);
  digitalWrite(9, false);
  digitalWrite(10, false);
  digitalWrite(11, false);
  digitalWrite(12, false);
  digitalWrite(13, false);
  delay(2000);

   // int s1 = analogRead(5);
   // Serial.println(s1, DEC);
   // delay(200);
}

