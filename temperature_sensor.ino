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
const int period = 1000; // ms
const byte decimalPlaces = 2;
const byte on = 'O';
const byte off = 'F';
const int refVoltage = 3300; // mV

unsigned int reading;
double milliVolts;
double degreesCelsius;
char message [100];
byte incomingByte;
boolean transmitting;

// Convert 10-bit ADC values to mV.
// Ref. is ~3.3V. May need to determine experimentally.
double calculateMilliVolts(unsigned int reading) {
  return (reading / 1023.0) * refVoltage;
}

// Convert milliVolts to degrees Celsius.
// TMP36 linear function: Vo = 10d + 500
double calculateCelsius(double milliVolts) {
  return (milliVolts - 500) / 10.0;
}

double calculateFahrenheit(double celsius) {
  return (celsius * 1.8) + 32
}

// Sets C-string {message} with JSON-formatted temperature data
int setMessage(char &message, double celsius, double fahrenheit) {
  return sprintf(message, "{\"celsius\": %.2f, \"fahrenheit\": %.2f}", celsius, fahrenheit)
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
    }

    if (incomingByte == off) {
      transmitting = false;
    }
  }

  if (transmitting) {
    digitalWrite(led, HIGH);

    reading = analogRead(inputSensor);
    milliVolts = calculateMilliVolts(reading);
    degreesCelsius = calculateCelsius(milliVolts);
    degreesFahrenheit = calculateFahrenheit(degreesCelsius);
    setMessage(message, degreesCelsius, degreesFahrenheit)
    Serial.println(message);

    delay(100);
    digitalWrite(led, LOW);
    delay(period - 100);
  }
}
