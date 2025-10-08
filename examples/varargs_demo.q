# QEP-034 MVP: Variadic Parameters Demo
# This example demonstrates the new *args feature

puts("=== QEP-034 MVP: Variadic Parameters Demo ===\n")

# Example 1: Simple varargs
puts("1. Simple varargs function:")
fun sum(*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

puts("   sum() = " .. sum().str())
puts("   sum(1, 2, 3, 4, 5) = " .. sum(1, 2, 3, 4, 5).str())
puts("")

# Example 2: Greeting multiple people
puts("2. Greeting multiple people:")
fun greet_all(greeting, *names)
    let result = greeting
    for name in names
        result = result .. " " .. name
    end
    result
end

puts("   " .. greet_all("Hello", "Alice", "Bob", "Charlie"))
puts("   " .. greet_all("Welcome", "User1", "User2"))
puts("")

# Example 3: Mixed parameters
puts("3. Mixed required, optional, and varargs:")
fun connect(host, port = 8080, *options)
    let msg = "Connecting to " .. host .. ":" .. port.str()
    if options.len() > 0
        msg = msg .. " with options: ["
        let first = true
        for opt in options
            if not first
                msg = msg .. ", "
            end
            msg = msg .. opt.str()
            first = false
        end
        msg = msg .. "]"
    end
    msg
end

puts("   " .. connect("localhost"))
puts("   " .. connect("localhost", 3000))
puts("   " .. connect("localhost", 3000, "ssl", "keepalive"))
puts("")

# Example 4: Lambdas with varargs
puts("4. Lambda with varargs:")
let max_of = fun (*nums)
    if nums.len() == 0
        return nil
    end
    let max_val = nums[0]
    for n in nums
        if n > max_val
            max_val = n
        end
    end
    max_val
end

puts("   max_of(3, 1, 4, 1, 5, 9, 2, 6) = " .. max_of(3, 1, 4, 1, 5, 9, 2, 6).str())
puts("")

# Example 5: Type methods with varargs
puts("5. Type methods with varargs:")
type Logger
    pub name: Str

    fun log(level, *messages)
        let result = "[" .. self.name .. "] " .. level .. ": "
        let first = true
        for msg in messages
            if not first
                result = result .. " "
            end
            result = result .. msg.str()
            first = false
        end
        result
    end

    static fun create(name = "default")
        Logger.new(name: name)
    end
end

let logger = Logger.create("MyApp")
puts("   " .. logger.log("INFO", "Server", "started", "on", "port", 8080))
puts("   " .. logger.log("ERROR", "Connection", "failed"))
puts("")

puts("=== Demo Complete ===")
puts("\n✓ All variadic parameter features working correctly!")
