#!/usr/bin/env quest
use "std/serial"
use "std/term"
use "std/sys"
use "std/time"

# Ping/Pong Serial Communication Example
#
# This script sends "ping" to an Arduino and waits for "pong" response.
# Make sure the Arduino is running the ping_pong.ino sketch.
#
# Usage:
#   quest examples/serial/ping_pong.q --port /dev/cu.usbmodem14101
#   quest examples/serial/ping_pong.q --port COM3

# Parse command line arguments
let port_name = nil
let baud_rate = 9600

let i = 0
while i < sys.argc
    let arg = sys.argv.get(i)
    if arg == "--port"
        if i + 1 < sys.argc
            port_name = sys.argv.get(i + 1)
            i = i + 1
        else
            puts(term.red("Error: --port requires a value"))
            puts("Usage: quest ping_pong.q --port <port_name>")
            sys.exit(1)
        end
    elif arg == "--help" or arg == "-h"
        puts("Serial Ping/Pong Example")
        puts("")
        puts("Usage:")
        puts("  quest ping_pong.q --port <port_name>")
        puts("")
        puts("Options:")
        puts("  --port <name>    Serial port to use (e.g., /dev/cu.usbmodem14101, COM3)")
        puts("  --help, -h       Show this help message")
        puts("")
        sys.exit(0)
    end
    i = i + 1
end

puts(term.cyan("Serial Ping/Pong Example"))
puts("Available ports:")

# List available serial ports
let ports = serial.available_ports()
ports.each(fun (port_info)
    puts("  - " .. port_info["port_name"] .. " (" .. port_info["type"] .. ")")
end)

# Check if port was specified
if port_name == nil
    puts("")
    puts(term.yellow("No port specified. Please run with --port argument:"))
    puts("  quest ping_pong.q --port <port_name>")
    puts("")
    puts("Example:")
    if ports.len() > 0
        let first_port = ports.get(0)
        puts("  quest ping_pong.q --port " .. first_port["port_name"])
    else
        puts("  quest ping_pong.q --port /dev/cu.usbmodem14101")
    end
    sys.exit(1)
end

puts("")
puts(term.yellow("Connecting to " .. port_name .. " at 9600 baud..."))

try
    # Open serial port
    let port = serial.open(port_name, baud_rate)
    puts(term.green("✓ Connected!"))

    # Wait for Arduino to reset (some boards reset on serial connection)
    puts("Waiting for Arduino to initialize...")
    time.sleep(2.0)

    # Send ping/pong messages
    let count = 0
    while true
        count = count + 1

        puts("\n" .. term.bold("--- Round " .. count.str() .. " ---"))

        # Send ping
        puts(term.blue("→ Sending: ping"))
        port.write("ping\n")
        port.flush()

        # Wait for response (with timeout)
        let response = nil
        let timeout_ms = 1000
        let read_start = time.ticks_ms()

        while time.ticks_ms() - read_start < timeout_ms
            let data = port.read(100)
            if data.len() > 0
                response = data.decode().trim()
                break
            end
            time.sleep(0.01)
        end

        # Check response
        if response == nil
            puts(term.red("✗ Timeout waiting for response"))
        elif response == "pong"
            puts(term.green("← Received: " .. response .. " ✓"))
        else
            puts(term.yellow("← Received unexpected: " .. response))
        end

        # Wait 3 seconds before next ping
        time.sleep(3)
    end

    puts("\n" .. term.cyan("Done! Closing port..."))
    port.close()
    puts(term.green("✓ Port closed"))

catch e
    puts(term.red("Error: " .. e.message()))
    puts("Make sure:")
    puts("  1. Arduino is connected")
    puts("  2. Port name is correct (check available_ports above)")
    puts("  3. Arduino is running ping_pong.ino sketch")
    puts("  4. No other program is using the serial port")
end
