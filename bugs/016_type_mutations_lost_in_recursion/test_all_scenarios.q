#!/usr/bin/env quest

# Comprehensive test suite for Bug #016: Type mutations lost when passed as parameters
# This tests various scenarios to understand the scope of the problem

type Counter
    pub count: int

    static fun create()
        Counter.new(count: 0)
    end

    fun increment()
        self.count = self.count + 1
    end

    fun add(n)
        self.count = self.count + n
    end
end

puts("=== Bug #016 Test Suite ===")
puts("")

# Test 1: Direct method call (baseline - should work)
puts("Test 1: Direct method call")
let c1 = Counter.create()
c1.increment()
puts("  Result: " .. c1.count._str() .. " (expected: 1)")
let test1_pass = c1.count == 1
if test1_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 2: Method call in non-recursive function
puts("Test 2: Method call in non-recursive function")
fun mutate_once(counter)
    counter.increment()
end

let c2 = Counter.create()
mutate_once(c2)
puts("  Result: " .. c2.count._str() .. " (expected: 1)")
let test2_pass = c2.count == 1
if test2_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 3: Recursive function (main bug scenario)
puts("Test 3: Recursive function")
fun mutate_recursive(counter, n)
    if n > 0
        counter.increment()
        mutate_recursive(counter, n - 1)
    end
end

let c3 = Counter.create()
mutate_recursive(c3, 3)
puts("  Result: " .. c3.count._str() .. " (expected: 3)")
let test3_pass = c3.count == 3
if test3_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 4: Nested function calls (not recursive, but chained)
puts("Test 4: Nested function calls")
fun mutate_a(counter)
    counter.increment()
    mutate_b(counter)
end

fun mutate_b(counter)
    counter.increment()
end

let c4 = Counter.create()
mutate_a(c4)
puts("  Result: " .. c4.count._str() .. " (expected: 2)")
let test4_pass = c4.count == 2
if test4_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 5: Method with parameters
puts("Test 5: Method with parameters")
fun add_via_func(counter, n)
    counter.add(n)
end

let c5 = Counter.create()
add_via_func(c5, 5)
puts("  Result: " .. c5.count._str() .. " (expected: 5)")
let test5_pass = c5.count == 5
if test5_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 6: Multiple parameters with struct
puts("Test 6: Multiple parameters with struct")
fun add_two(counter1, counter2)
    counter1.increment()
    counter2.increment()
end

let c6a = Counter.create()
let c6b = Counter.create()
add_two(c6a, c6b)
puts("  c6a Result: " .. c6a.count._str() .. " (expected: 1)")
puts("  c6b Result: " .. c6b.count._str() .. " (expected: 1)")
let test6_pass = c6a.count == 1 and c6b.count == 1
if test6_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 7: Struct in array
puts("Test 7: Struct in array")
let c7 = Counter.create()
let arr = [c7]
arr[0].increment()
puts("  Original c7: " .. c7.count._str() .. " (expected: 1)")
puts("  Array[0]: " .. arr[0].count._str() .. " (expected: 1)")
let test7_pass = c7.count == 1 and arr[0].count == 1
if test7_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 8: Struct in dict
puts("Test 8: Struct in dict")
let c8 = Counter.create()
let d = {"counter": c8}
d["counter"].increment()
puts("  Original c8: " .. c8.count._str() .. " (expected: 1)")
puts("  Dict value: " .. d["counter"].count._str() .. " (expected: 1)")
let test8_pass = c8.count == 1 and d["counter"].count == 1
if test8_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 9: Return modified struct
puts("Test 9: Return modified struct from function")
fun increment_and_return(counter)
    counter.increment()
    counter
end

let c9 = Counter.create()
let c9_returned = increment_and_return(c9)
puts("  Original c9: " .. c9.count._str() .. " (expected: 1)")
puts("  Returned: " .. c9_returned.count._str() .. " (expected: 1)")
let test9_pass = c9.count == 1 and c9_returned.count == 1
if test9_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Test 10: Tail recursion
puts("Test 10: Tail recursion")
fun tail_recursive_increment(counter, n, acc)
    if n == 0
        acc
    else
        counter.increment()
        tail_recursive_increment(counter, n - 1, acc + 1)
    end
end

let c10 = Counter.create()
let result10 = tail_recursive_increment(c10, 4, 0)
puts("  Counter: " .. c10.count._str() .. " (expected: 4)")
puts("  Return value: " .. result10._str() .. " (expected: 4)")
let test10_pass = c10.count == 4 and result10 == 4
if test10_pass
    puts("  ✅ PASS")
else
    puts("  ❌ FAIL")
end
puts("")

# Summary
puts("=== Summary ===")
let total = 10
let passed = 0
if test1_pass then passed = passed + 1 end
if test2_pass then passed = passed + 1 end
if test3_pass then passed = passed + 1 end
if test4_pass then passed = passed + 1 end
if test5_pass then passed = passed + 1 end
if test6_pass then passed = passed + 1 end
if test7_pass then passed = passed + 1 end
if test8_pass then passed = passed + 1 end
if test9_pass then passed = passed + 1 end
if test10_pass then passed = passed + 1 end

puts("Passed: " .. passed._str() .. "/" .. total._str())
if passed == total
    puts("✅ All tests passed!")
else
    puts("❌ " .. (total - passed)._str() .. " test(s) failed")
end
