# Demonstrates the bug where fields with defaults are still required

type Config
    pub host: Str = "localhost"
    pub port: Int = 3000
    pub debug: Bool = false
end

# This should work but currently fails with:
# ArgErr: Required field 'host' not provided and has no default
let config1 = Config.new()

# These should also work:
let config2 = Config.new(host: "0.0.0.0")
let config3 = Config.new(port: 8080)
let config4 = Config.new(host: "127.0.0.1", debug: true)

puts("config1.host: " .. config1.host)
puts("config1.port: " .. config1.port.str())
puts("config1.debug: " .. config1.debug.str())
puts("")
puts("config2.host: " .. config2.host)
puts("config2.port: " .. config2.port.str())
puts("")
puts("config3.host: " .. config3.host)
puts("config3.port: " .. config3.port.str())
puts("")
puts("config4.host: " .. config4.host)
puts("config4.debug: " .. config4.debug.str())

