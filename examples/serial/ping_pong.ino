/*
 * Arduino Ping/Pong Serial Example
 *
 * This sketch listens for "ping" messages on the serial port
 * and responds with "pong".
 *
 * Upload this sketch to your Arduino, then run ping_pong.q
 *
 * Compatible with: Arduino Uno, Nano, Mega, Leonardo, etc.
 */

const int LED_PIN = LED_BUILTIN;  // Built-in LED (usually pin 13)
const long BAUD_RATE = 9600;

String inputBuffer = "";

void setup() {
  // Initialize serial communication
  Serial.begin(BAUD_RATE);

  // Initialize LED pin
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Wait for serial port to connect
  while (!Serial) {
    ; // Wait for serial port to connect (needed for native USB boards)
  }

  // Send startup message
  Serial.println("Arduino Ping/Pong Ready!");

  // Blink LED 3 times to indicate ready
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

void loop() {
  // Check if data is available on serial port
  while (Serial.available() > 0) {
    char inChar = (char)Serial.read();

    // Add character to buffer
    if (inChar == '\n' || inChar == '\r') {
      // End of line - process the message
      if (inputBuffer.length() > 0) {
        processMessage(inputBuffer);
        inputBuffer = "";  // Clear buffer
      }
    } else {
      inputBuffer += inChar;
    }
  }
}

void processMessage(String message) {
  // Trim whitespace
  message.trim();

  // Check if message is "ping"
  if (message.equalsIgnoreCase("ping")) {
    // Blink LED to show activity
    digitalWrite(LED_PIN, HIGH);

    // Send pong response
    Serial.println("pong");
    Serial.flush();  // Ensure data is sent

    // Keep LED on briefly
    delay(50);
    digitalWrite(LED_PIN, LOW);
  } else {
    // Unknown message - send error
    Serial.print("ERROR: Unknown command '");
    Serial.print(message);
    Serial.println("'");
  }
}
