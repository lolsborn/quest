#!/usr/bin/env quest
# Test case for mutable type fields bug

use "std/sys" as sys

puts("=== Test: Mutable Type Fields ===")
puts("")

type Counter
    pub count: Int

    static fun create()
        Counter.new(count: 0)
    end

    fun increment()
        puts("  Before increment: self.count = " .. self.count._str())
        self.count = self.count + 1
        puts("  After increment:  self.count = " .. self.count._str())
        self.count
    end

    fun get()
        self.count
    end
end

# Test 1: Simple increment
puts("Test 1: Simple increment")
let c = Counter.create()
puts("Initial count: " .. c.count._str())
let result = c.increment()
puts("Returned value: " .. result._str())
puts("Field value: " .. c.count._str())
puts("")

if c.count != 1
    puts("❌ FAILED: Expected count=1, got count=" .. c.count._str())
    sys.exit(1)
else
    puts("✅ PASSED: count=1 as expected")
end
puts("")

# Test 2: Multiple increments
puts("Test 2: Multiple increments")
c.increment()
c.increment()
puts("After 2 more increments: " .. c.count._str())
if c.count != 3
    puts("❌ FAILED: Expected count=3, got count=" .. c.count._str())
    sys.exit(1)
else
    puts("✅ PASSED: count=3 as expected")
end
puts("")

# Test 3: Multiple instances
puts("Test 3: Multiple instances")
let c1 = Counter.create()
let c2 = Counter.create()
c1.increment()
c1.increment()
c2.increment()
puts("c1.count = " .. c1.count._str() .. " (should be 2)")
puts("c2.count = " .. c2.count._str() .. " (should be 1)")

if c1.count != 2
    puts("❌ FAILED: c1 should be 2")
    sys.exit(1)
end
if c2.count != 1
    puts("❌ FAILED: c2 should be 1")
    sys.exit(1)
end
puts("✅ PASSED: Instances maintain separate state")
puts("")

puts("=== All Tests Passed ===")
