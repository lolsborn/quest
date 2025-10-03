#!/usr/bin/env quest
use "std/serial"

puts("Available ports:")

# List available serial ports
let ports = serial.available_ports()
ports.each(fun (port_info)
    puts("  - " .. port_info["port_name"] .. " (" .. port_info["type"] .. ")")
end)
