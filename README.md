# Digital-Steteschope
void setup() {
  // Start serial communication at 74880 baud rate
  Serial.begin(112500);
  // Configure A6 pin as an input for reading analog signals
  pinMode(A5, INPUT);
}
void loop() {
  // Read the analog value from pin A6 (0-1023)
  uint16_t value = analogRead(A5);
  // Wait until there is enough space in the serial buffer to write two bytes
  while (Serial.availableForWrite() < 2);
  // Send the higher byte of the value (MSB)
  Serial.write(value >> 8);
  // Send the lower byte of the value (LSB)
  Serial.write(value & 0xFF);
  // Wait for 200 microseconds before the next reading
  delayMicroseconds(500);
}

