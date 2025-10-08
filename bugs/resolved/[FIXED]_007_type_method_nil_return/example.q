#!/usr/bin/env quest
# Bug 007 - Type Methods Returning Nil Actually Return Self
# Minimal reproduction case

type TestType
    value: Int

    fun returns_nil()
        return nil
    end

    fun returns_42()
        return 42
    end

    fun implicit_nil()
        let x = 5
        # No explicit return - should return nil
    end
end

puts("=== Bug 007: Type Method Nil Return ===\n")

let t = TestType.new(value: 100)

# Test 1: Explicit return nil
puts("Test 1: Method with 'return nil'")
let r1 = t.returns_nil()
puts("  Result == nil: " .. (r1 == nil).str())
puts("  Expected: true")
puts("  Actual: false (BUG!)")
puts("  Returned: TestType instance instead of nil")
puts("")

# Test 2: Explicit return value (works correctly)
puts("Test 2: Method with 'return 42'")
let r2 = t.returns_42()
puts("  Result == 42: " .. (r2 == 42).str())
puts("  Expected: true")
puts("  Actual: true (CORRECT)")
puts("")

# Test 3: Implicit nil (no return statement)
puts("Test 3: Method with no return statement")
let r3 = t.implicit_nil()
puts("  Result == nil: " .. (r3 == nil).str())
puts("  Expected: true")
puts("  Actual: false (BUG!)")
puts("  Returned: TestType instance instead of nil")
puts("")

puts("=== Root Cause ===")
puts("src/main.rs:1803-1809 assumes 'return nil' means 'return self for chaining'")
puts("This breaks methods that legitimately want to return nil")
puts("")

puts("=== Impact ===")
puts("- Handler.add_filter() returns self instead of nil")
puts("- Handler.handle() returns self when filtering")
puts("- Any method that should return nil is broken")
puts("- Cannot implement optional return patterns (find_or_nil)")
