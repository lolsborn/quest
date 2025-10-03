#!/usr/bin/env quest
use "std/serial"
use "std/term"
use "std/sys"
use "std/time"

# Serial Monitor - Display incoming serial data
#
# Usage:
#   quest examples/serial/sermon.q --port /dev/ttyUSB0
#   quest examples/serial/sermon.q --port COM3 --baud 115200

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
            sys.exit(1)
        end
    elif arg == "--baud"
        if i + 1 < sys.argc
            baud_rate = sys.argv.get(i + 1)
            i = i + 1
        else
            puts(term.red("Error: --baud requires a value"))
            sys.exit(1)
        end
    elif arg == "--help" or arg == "-h"
        puts(term.bold("Serial Monitor"))
        puts("")
        puts("Displays incoming serial data in real-time.")
        puts("")
        puts("Usage:")
        puts("  quest sermon.q --port <port_name> [--baud <rate>]")
        puts("")
        puts("Options:")
        puts("  --port <name>    Serial port (e.g., /dev/ttyUSB0, COM3)")
        puts("  --baud <rate>    Baud rate (default: 9600)")
        puts("  --help, -h       Show this help")
        puts("")
        puts("Example:")
        puts("  quest sermon.q --port /dev/ttyUSB0")
        puts("  quest sermon.q --port COM3 --baud 115200")
        puts("")
        sys.exit(0)
    end
    i = i + 1
end

# List available ports
puts(term.cyan("Serial Monitor"))
puts("")
puts("Available ports:")

let ports = serial.available_ports()
if ports.len() == 0
    puts(term.yellow("  (none found)"))
else
    ports.each(fun (port_info)
        puts("  - " .. port_info["port_name"] .. " (" .. port_info["type"] .. ")")
    end)
end
puts("")

# Check if port specified
if port_name == nil
    puts(term.yellow("No port specified. Use --port <name>"))
    puts("")
    if ports.len() > 0
        let first_port = ports.get(0)
        puts("Example:")
        puts("  quest sermon.q --port " .. first_port["port_name"])
    end
    sys.exit(1)
end

# Open port
puts(term.green("Opening " .. port_name .. " at " .. baud_rate._str() .. " baud..."))

try
    let port = serial.open(port_name, baud_rate)

    # Set a short timeout so reads don't block for long
    port.set_timeout(10)  # 10ms timeout for quick polling

    puts(term.green("Connected"))
    puts("")
    puts(term.dimmed("Monitoring serial data (press Ctrl+C to stop)..."))
    puts(term.dimmed("---"))
    puts("")

    try
        # Monitor loop
        while true
            let data = port.read(100)
            if data.len() > 0
                # Try to decode as UTF-8 text
                try
                    let text = data.decode()
                    print(text)  # Use print (no newline) to preserve formatting
                catch e
                    # If not valid UTF-8, show as hex
                    puts(term.yellow("[Binary data: " .. data.decode("hex") .. "]"))
                end
            end
            time.sleep(0.01)  # Small delay to avoid busy-waiting
        end
    catch e
        # port.close()
        puts("Exiting...")
        # puts(e)
    end

catch e
    puts("")
    puts(term.red("Error: " .. e.message()))
    puts("")
    puts("Common issues:")
    puts("  - Port doesn't exist - check available ports above")
    puts("  - Port already in use - close other programs using it")
    puts("  - Wrong baud rate - device may expect different speed")
    sys.exit(1)
end
