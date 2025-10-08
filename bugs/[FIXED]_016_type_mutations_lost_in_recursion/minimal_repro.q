#!/usr/bin/env quest

type Counter
    pub count: Int

    static fun create()
        Counter.new(count: 0)
    end

    fun increment()
        self.count = self.count + 1
    end
end

# Test if types persist mutations through recursive function calls
fun recursive_increment(counter, n)
    puts("recursive_increment(n=" .. n.str() .. ") count=" .. counter.count.str())
    if n > 0
        counter.increment()
        recursive_increment(counter, n - 1)
    end
end

let c = Counter.create()
puts("Initial: " .. c.count.str())

recursive_increment(c, 5)

puts("After 5 recursive increments: " .. c.count.str() .. " (should be 5)")

if c.count == 5
    puts("✅ Type mutations persist through recursion!")
else
    puts("❌ Type mutations do NOT persist through recursion!")
end
