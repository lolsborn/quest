# Serial Communication Examples

This directory contains examples of serial communication between Quest and hardware devices like Arduino.

## Examples

### 1. Serial Monitor (sermon.q)

A simple serial monitor that displays incoming data in real-time.

**Usage:**
```bash
quest sermon.q --port /dev/ttyUSB0
quest sermon.q --port COM3 --baud 115200
```

**Features:**
- Lists available serial ports
- Displays incoming text data
- Shows binary data as hex when not valid UTF-8
- Configurable baud rate (default: 9600)

### 2. Ping/Pong Protocol

Demonstrates bidirectional communication with Arduino.

**Files:**
- **ping_pong.q** - Quest script that sends "ping" and waits for "pong"
- **ping_pong.ino** - Arduino sketch that responds to "ping" with "pong"

---

## Quick Start: Serial Monitor

Want to quickly test serial communication? Use the serial monitor:

```bash
# List available ports and start monitoring
quest sermon.q --port /dev/ttyUSB0

# With custom baud rate
quest sermon.q --port COM3 --baud 115200
```

This will display all incoming serial data in real-time.

---

## Ping/Pong Setup

### Hardware Requirements

- Arduino board (Uno, Nano, Mega, Leonardo, etc.)
- USB cable to connect Arduino to computer

### Setup Instructions

#### 1. Upload Arduino Sketch

1. Open `ping_pong.ino` in the Arduino IDE
2. Select your board: **Tools → Board**
3. Select your port: **Tools → Port**
4. Click **Upload** button
5. Wait for "Done uploading" message

#### 2. Find Serial Port

The Arduino will be connected to a serial port. Common names:

- **macOS**: `/dev/cu.usbmodem*` or `/dev/cu.usbserial*`
- **Linux**: `/dev/ttyACM*` or `/dev/ttyUSB*`
- **Windows**: `COM3`, `COM4`, etc.

To find available ports, run the Quest script - it will list them at startup.

#### 3. Run Ping/Pong Script

Run the script with the `--port` argument to specify your serial port:

```bash
./target/release/quest examples/serial/ping_pong.q --port /dev/cu.usbmodem14101
```

Or on Windows:

```bash
quest.exe examples/serial/ping_pong.q --port COM3
```

To see available options:

```bash
./target/release/quest examples/serial/ping_pong.q --help
```

## Expected Output

```
Serial Ping/Pong Example
Available ports:
  - /dev/cu.usbmodem14101
  - /dev/cu.Bluetooth-Incoming-Port

Connecting to /dev/cu.usbmodem14101 at 9600 baud...
✓ Connected!
Waiting for Arduino to initialize...

--- Round 1 ---
→ Sending: ping
← Received: pong ✓
Waiting 3 seconds...

--- Round 2 ---
→ Sending: ping
← Received: pong ✓
Waiting 3 seconds...

[... continues for 10 rounds ...]

Done! Closing port...
✓ Port closed
```

## How It Works

### Quest Side (ping_pong.q)

1. Parses command-line arguments for `--port`
2. Lists available serial ports
3. Opens specified serial port at 9600 baud
4. Waits 2 seconds for Arduino to initialize
5. Sends "ping\n" (with newline)
6. Reads response with 1 second timeout
7. Expects "pong" response
8. Waits 3 seconds before next ping
9. Repeats 10 times

### Arduino Side (ping_pong.ino)

1. Opens serial port at 9600 baud
2. Blinks LED 3 times to indicate ready
3. Reads incoming serial data character by character
4. When newline received, checks if message is "ping"
5. If "ping", sends "pong\n" response and blinks LED
6. If unknown command, sends error message

## Troubleshooting

### "Error: No such file or directory"

- Arduino not connected or wrong port name
- Check available ports in the script output
- On Linux, you may need to add your user to the `dialout` group:
  ```bash
  sudo usermod -a -G dialout $USER
  ```
  Then log out and back in.

### "Error: Permission denied"

- On macOS/Linux, you may need to close Arduino IDE Serial Monitor
- Another program may be using the port
- Try unplugging and replugging the Arduino

### "Timeout waiting for response"

- Arduino sketch not uploaded correctly
- Wrong baud rate (must be 9600 on both sides)
- Arduino resetting during communication
- Try increasing the initialization wait time in the Quest script

### Arduino keeps resetting

- Some Arduino boards (like Uno) reset when serial connection opens
- The script waits 2 seconds for this - increase if needed
- DTR/RTS may be triggering reset - this is normal behavior

## Extending the Example

Try these modifications:

1. **Add more commands**: Extend the Arduino sketch to respond to other commands
2. **Binary protocol**: Use `b"..."` bytes literals for binary communication
3. **Bidirectional**: Have Arduino send data without Quest requesting it
4. **Sensors**: Have Arduino send sensor readings
5. **Control**: Send commands to control LEDs, motors, etc.

## Binary Protocol Example

Quest side:
```quest
# Send binary command
port.write(b"\xFF\x01\x42")

# Read binary response
let data = port.read(10)
let first_byte = data.get(0)
```

Arduino side:
```cpp
// Read binary data
if (Serial.available() >= 3) {
  byte cmd = Serial.read();
  byte param1 = Serial.read();
  byte param2 = Serial.read();

  // Process command...
}
```
