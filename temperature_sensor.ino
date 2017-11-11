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

// Converts 10-bit ADC values to degrees celsius.
// Analog reference for ADC set to 2.5V for better precision and for
// better portability; The exact Vcc values can vary accross chips.
//
// Derivation:
//
// Vo = n * (Vref / 1023.0)
// c = (Vo - 500) / 10.0
//
// @see TMP36 datasheet Vout to Celsius linear equation
//
// The conversion uses Horner's method to multiply the ADC reading
// by (250/1023).
int getCelsius(unsigned int reading) {
  int value;
  value = (value >> 1) + reading;
  value = (value >> 1) + reading;
  value = (value >> 1) + reading;
  value = (value >> 4) + reading;
  value = (value >> 2) + reading;
  value = (value >> 1) + reading;
  value = (value >> 1) + reading;
  value = (value >> 1) + reading;
  value = (value >> 1) + reading;
  value = (value >> 3);

  value = value - 50;

  return value;
}

void setup() {
  analogReference(INTERNAL2V5);
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
