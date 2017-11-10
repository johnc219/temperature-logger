// Target chip: MSP430G2553
// Test launchpad: Rev. 1.4

// Measures temperature readings.
//
// TMP36 sensor -> 10-bit ADC
// .1uF ceramic bypass cap between Vcc and GND
// added to reduce effects of RFI

const byte inputSensor = 6;
const byte led = 14;
const int baudRate = 9600; // bps
const byte on = 'O';
const byte off = 'F';

unsigned int reading;
String msg;
byte incomingByte;
boolean transmitting;
int celsius;

String getMessage(int celsius) {
  return String("{\"celsius\": ") + String(celsius) + "}";
}

// Convert 10-bit ADC values to celsius.
int getCelsius(unsigned int reading) {
  // Apply Horner's method to multiply by (357/1023) => (Vcc/ADC-resolution)
  // Vcc experimentally measure as 3.57V.
  // @see TMP36 datasheet Vout to Celsius linear equation
  int value;
  value = (value >> 1) + reading;
  value = (value >> 2) + reading;
  value = (value >> 2) + reading;
  value = (value >> 2) + reading;
  value = (value >> 3) + reading;
  value = (value >> 1) + reading;
  value = (value >> 2) + reading;
  value = (value >> 2);

  value = value - 50;

  return value;
}

void setup() {
  pinMode(inputSensor, INPUT);
  pinMode(led, OUTPUT);

  // Hardware UART
  Serial.begin(baudRate);
  Serial.flush();

  // Initialize with no transmission
  transmitting = false;

  // Ensure led is off
  digitalWrite(led, LOW);
}

void loop() {
  if (Serial.available() > 0) {
    incomingByte = Serial.read();

    if (incomingByte == on) {
      transmitting = true;
      Serial.flush();
    }

    if (incomingByte == off) {
      transmitting = false;
      Serial.flush();
    }
  }

  if (transmitting) {
    digitalWrite(led, HIGH);
    celsius = getCelsius(analogRead(inputSensor));
    msg = getMessage(celsius);
    Serial.println(msg);

    delay(50);
    digitalWrite(led, LOW);
    delay(950);
  }
}
