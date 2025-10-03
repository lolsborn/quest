# Serial Port Communication

The `std/serial` module provides cross-platform serial port communication for interfacing with Arduino, microcontrollers, modems, and other serial devices.

## Importing

```quest
use "std/serial" as serial
```

## Quick Start

```quest
use "std/serial" as serial

# List available ports
let ports = serial.available_ports()
ports.each(fun (port_info)
    puts(port_info["port_name"])
end)

# Open port
let port = serial.open("/dev/ttyUSB0", 9600)

# Write text
port.write("Hello\n")

# Read response
let data = port.read(100)
puts(data.decode())

# Close port
port.close()
```

## Functions

### available_ports()

List all available serial ports on the system.

**Returns:** Array of dictionaries with port information

```quest
let ports = serial.available_ports()
ports.each(fun (port_info)
    puts(port_info["port_name"] .. " (" .. port_info["type"] .. ")")
end)
```

Each port info dictionary contains:
- `port_name` - Device path (e.g., `/dev/ttyUSB0`, `COM3`)
- `type` - Port type (e.g., `"usb"`, `"pci"`, `"bluetooth"`)

**Example output:**
```
/dev/ttyUSB0 (usb)
/dev/ttyACM0 (usb)
/dev/cu.Bluetooth-Incoming-Port (bluetooth)
```

### open(port_name, baud_rate)

Open a serial port for communication.

**Parameters:**
- `port_name` (string) - Device path (e.g., `/dev/ttyUSB0`, `COM3`)
- `baud_rate` (number) - Communication speed (e.g., 9600, 115200)

**Returns:** SerialPort object

**Common baud rates:** 300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200

```quest
# Linux/macOS
let port = serial.open("/dev/ttyUSB0", 9600)

# Windows
let port = serial.open("COM3", 9600)

# High-speed connection
let fast_port = serial.open("/dev/ttyACM0", 115200)
```

**Errors:**
- Port doesn't exist
- Port already in use
- Insufficient permissions
- Invalid baud rate

```quest
try
    let port = serial.open("/dev/ttyUSB0", 9600)
catch e
    puts("Failed to open port: " .. e.message())
end
```

## SerialPort Methods

### write(data)

Send data to the serial port. Accepts both strings and bytes.

**Parameters:**
- `data` (String or Bytes) - Data to send

**Returns:** Number of bytes written

```quest
# Text protocol
let count = port.write("AT\r\n")
puts("Wrote " .. count._str() .. " bytes")

# Binary protocol
let packet = b"\xFF\x01\x42"
port.write(packet)
```

Strings are automatically encoded as UTF-8 bytes before sending.

### read(size)

Read up to `size` bytes from the serial port. Non-blocking - returns immediately with available data (may be less than requested).

**Parameters:**
- `size` (number) - Maximum number of bytes to read

**Returns:** Bytes object (may be empty if no data available)

```quest
# Read up to 100 bytes
let data = port.read(100)

if data.len() > 0
    puts("Received " .. data.len()._str() .. " bytes")
end
```

For text protocols, decode the bytes:

```quest
let response = port.read(100)
if response.len() > 0
    let text = response.decode()
    puts("Response: " .. text)
end
```

For binary protocols, inspect bytes directly:

```quest
let packet = port.read(10)
if packet.len() >= 3
    let cmd = packet.get(0)
    let status = packet.get(1)
    let length = packet.get(2)
    puts("Command: " .. cmd._str())
end
```

### flush()

Flush output buffer, ensuring all written data is transmitted before returning.

```quest
port.write("Important command\n")
port.flush()  # Wait until transmitted
```

Useful when timing is critical or before closing the port.

### bytes_available()

Check how many bytes are available to read without blocking.

**Returns:** Number of bytes in the receive buffer

```quest
let available = port.bytes_available()
if available > 0
    let data = port.read(available)
    # Process data
end
```

### clear_input()

Discard all data in the input (receive) buffer.

```quest
# Clear any stale data before sending command
port.clear_input()
port.write("STATUS\n")
let response = port.read(100)
```

### clear_output()

Discard all data in the output (transmit) buffer.

```quest
port.clear_output()
```

### clear_all()

Clear both input and output buffers.

```quest
# Reset communication
port.clear_all()
```

### close()

Close the serial port and release the resource.

```quest
port.close()
```

Always close ports when done. Use try/ensure for safety:

```quest
let port = serial.open("/dev/ttyUSB0", 9600)
try
    # Use port
    port.write("DATA\n")
ensure
    port.close()
end
```

## Communication Patterns

### Request-Response

Send a command and wait for response:

```quest
use "std/serial" as serial
use "std/time" as time

let port = serial.open("/dev/ttyUSB0", 9600)

# Send command
port.write("STATUS\n")
port.flush()

# Wait for response with timeout
let timeout_seconds = 2.0
let start = time.ticks_ms()

let response = b""
while time.ticks_ms() - start < timeout_seconds * 1000
    let data = port.read(100)
    if data.len() > 0
        response = response .. data
        if response.decode().ends_with("\n")
            break
        end
    end
    time.sleep(0.01)  # Small delay
end

if response.len() > 0
    puts("Got response: " .. response.decode().trim())
else
    puts("Timeout - no response")
end

port.close()
```

### Line-Based Protocol

Read until newline:

```quest
fun read_line(port, timeout_ms)
    let buffer = b""
    let start = time.ticks_ms()

    while time.ticks_ms() - start < timeout_ms
        let data = port.read(1)
        if data.len() > 0
            buffer = buffer .. data
            if data.get(0) == 10  # Newline
                return buffer.decode().trim()
            end
        end
        time.sleep(0.001)
    end

    return nil  # Timeout
end

let port = serial.open("/dev/ttyUSB0", 9600)
port.write("QUERY\n")
let response = read_line(port, 1000)
if response != nil
    puts("Response: " .. response)
end
```

### Binary Protocol with Fixed Headers

```quest
# Read fixed-size packet header
fun read_packet(port)
    # Wait for start marker (0xFF 0xFF)
    let buffer = b""

    while true
        let byte = port.read(1)
        if byte.len() == 0
            continue
        end

        buffer = buffer .. byte
        if buffer.len() >= 2
            if buffer.get(buffer.len() - 2) == 255 and buffer.get(buffer.len() - 1) == 255
                break
            end
        end
    end

    # Read command and length
    let cmd = port.read(1)
    let len = port.read(1)

    # Read payload
    let payload = b""
    let remaining = len.get(0)
    while remaining > 0
        let chunk = port.read(remaining)
        payload = payload .. chunk
        remaining = remaining - chunk.len()
    end

    return {
        "command": cmd.get(0),
        "payload": payload
    }
end
```

### Continuous Monitoring

```quest
use "std/serial" as serial
use "std/time" as time

let port = serial.open("/dev/ttyUSB0", 9600)

puts("Monitoring serial port (Ctrl+C to stop)...")

while true
    let data = port.read(100)
    if data.len() > 0
        puts("Received: " .. data.decode())
    end
    time.sleep(0.1)  # Check 10 times per second
end
```

## Platform-Specific Notes

### Linux

**Port naming:**
- USB-to-serial adapters: `/dev/ttyUSB0`, `/dev/ttyUSB1`, ...
- Arduino/ACM devices: `/dev/ttyACM0`, `/dev/ttyACM1`, ...

**Permissions:**
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Or set permissions temporarily
sudo chmod 666 /dev/ttyUSB0
```

### macOS

**Port naming:**
- USB-to-serial: `/dev/cu.usbserial-*`
- Arduino: `/dev/cu.usbmodem*`

**Finding ports:**
```bash
ls /dev/cu.*
```

### Windows

**Port naming:**
- `COM1`, `COM2`, `COM3`, ...

**Finding ports:**
- Device Manager → Ports (COM & LPT)
- Or use `serial.available_ports()`

## Common Devices

### Arduino

```quest
use "std/serial" as serial
use "std/time" as time

let port = serial.open("/dev/ttyACM0", 9600)

# Arduino resets when serial connection opens
time.sleep(2.0)  # Wait for bootloader

port.write("Hello Arduino\n")
let response = port.read(100).decode()
puts(response)

port.close()
```

**See:** [examples/serial/ping_pong.q](../../examples/serial/ping_pong.q)

### GPS Module (NMEA)

```quest
let port = serial.open("/dev/ttyUSB0", 9600)

# Read NMEA sentences
while true
    let line = read_line(port, 1000)
    if line != nil and line.starts_with("$GPGGA")
        puts("GPS fix: " .. line)
    end
end
```

### Modem (AT Commands)

```quest
let port = serial.open("/dev/ttyUSB0", 115200)

port.write("AT\r\n")
let response = read_line(port, 1000)
puts("Modem says: " .. response)  # "OK"

port.write("ATI\r\n")  # Get modem info
response = read_line(port, 1000)
puts(response)
```

## Error Handling

### Connection Errors

```quest
try
    let port = serial.open("/dev/ttyUSB0", 9600)
catch e
    if e.message().contains("Permission denied")
        puts("Need permissions - try: sudo chmod 666 /dev/ttyUSB0")
    elif e.message().contains("No such file")
        puts("Device not found - check connection")
    else
        puts("Error: " .. e.message())
    end
end
```

### Read Timeouts

```quest
fun read_with_timeout(port, size, timeout_ms)
    let start = time.ticks_ms()
    let buffer = b""

    while time.ticks_ms() - start < timeout_ms
        let data = port.read(size - buffer.len())
        if data.len() > 0
            buffer = buffer .. data
            if buffer.len() >= size
                return buffer
            end
        end
        time.sleep(0.01)
    end

    if buffer.len() > 0
        return buffer  # Partial data
    end

    raise "Read timeout - no data received"
end
```

### Safe Resource Management

```quest
fun with_serial_port(port_name, baud_rate, callback)
    let port = serial.open(port_name, baud_rate)
    try
        return callback(port)
    ensure
        port.close()
    end
end

# Usage
with_serial_port("/dev/ttyUSB0", 9600, fun (port)
    port.write("HELLO\n")
    return port.read(100).decode()
end)
```

## Troubleshooting

### Port Not Found

```quest
let ports = serial.available_ports()
if ports.len() == 0
    puts("No serial ports found!")
else
    puts("Available ports:")
    ports.each(fun (p)
        puts("  " .. p["port_name"])
    end)
end
```

### No Data Received

- Check baud rate matches device
- Verify device is powered on
- Check cable connections
- Try `clear_input()` before reading
- Add delays after opening (some devices reset)

### Garbled Data

- Baud rate mismatch (most common)
- Wrong data format (expecting text, getting binary)
- Flow control issues
- Cable quality

```quest
# Debug: show raw bytes
let data = port.read(100)
puts("Received " .. data.len()._str() .. " bytes:")
puts("Hex: " .. data.decode("hex"))
```

## Examples

Complete examples in [examples/serial/](../../examples/serial/):

- **ping_pong.q** - Arduino ping/pong protocol
- **ping_pong.ino** - Matching Arduino sketch

Run the example:
```bash
quest examples/serial/ping_pong.q --port /dev/ttyACM0
```

## See Also

- [Bytes Type](../types/bytes.md) - Binary data handling
- [std/time](./time.md) - Timing and delays
- [std/io](./io.md) - File I/O
