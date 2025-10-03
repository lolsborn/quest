"""
Serial port communication module for Quest.

Provides cross-platform serial port communication capabilities.

Available functions:
- serial.available_ports() - List all available serial ports (returns array of dicts)
- serial.open(port_name, baud_rate, [timeout_ms]) - Open a serial port (returns SerialPort object)

SerialPort object methods:
- port.name() - Get port name
- port.read(size) - Read up to size bytes (returns Bytes object, use .decode() for text)
- port.write(data) - Write string or bytes to port (returns bytes written)
- port.flush() - Flush output buffer
- port.bytes_to_read() - Get number of bytes available to read
- port.bytes_to_write() - Get number of bytes waiting to be written
- port.clear_input() - Clear input buffer
- port.clear_output() - Clear output buffer
- port.clear_all() - Clear both buffers
- port.set_timeout(ms) - Set read/write timeout in milliseconds
- port.set_baud_rate(rate) - Set baud rate
- port.baud_rate() - Get current baud rate
- port.set_data_bits(bits) - Set data bits (5, 6, 7, or 8)
- port.set_parity(parity) - Set parity ("none", "odd", or "even")
- port.set_stop_bits(bits) - Set stop bits (1 or 2)
- port.set_flow_control(flow) - Set flow control ("none", "software", or "hardware")

Examples:
  # Text protocol (AT commands)
  port.write("AT\r\n")
  let response = port.read(100).decode()

  # Binary protocol
  port.write(b"\xFF\x01\x42")
  let data = port.read(10)  # Returns Bytes

Constants:
- serial.FIVE_BITS, serial.SIX_BITS, serial.SEVEN_BITS, serial.EIGHT_BITS
- serial.PARITY_NONE, serial.PARITY_ODD, serial.PARITY_EVEN
- serial.STOP_BITS_ONE, serial.STOP_BITS_TWO
- serial.FLOW_NONE, serial.FLOW_SOFTWARE, serial.FLOW_HARDWARE
"""
