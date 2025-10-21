# Reproduce the original scenario from Configuration type

type Config
    pub host: Str?
    pub port: Int?
    pub static: Str = ""  # Field with default added later
end

# This simulates what from_dict() was doing BEFORE adding static field
# It was calling: Config.new(host: ..., port: ...) but NOT passing static
puts("Test: Calling constructor with host and port, but NOT static")
puts("Expected: static should use default value ''")

let c = Config.new(
    host: "127.0.0.1",
    port: 3000
    # Note: static NOT provided - should use default ""
)

puts("host: " .. (c.host or "nil"))
puts("port: " .. (c.port or "nil").str())  
puts("static: '" .. c.static .. "'")
puts("")
puts("✓ SUCCESS: Default value was used even though field wasn't provided!")

