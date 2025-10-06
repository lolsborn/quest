# Bug: Mutable Type Fields Don't Update Correctly

**Status**: 🔴 OPEN

**Reported**: 2025-10-05 (benchmarks implementation session)

**Severity**: HIGH - Blocks implementation of stateful algorithms

## Summary

When mutating type fields inside instance methods (e.g., `self.pos = self.pos + 1`), the mutations don't persist correctly. The field appears to return the boolean result of the assignment rather than the updated value, causing infinite loops and incorrect behavior.

## Minimal Reproduction

```quest
type Parser
    pub string: text
    pub int: pos

    static fun create(text)
        Parser.new(text: text, pos: 0)
    end

    fun next_char()
        if self.pos >= self.text.len()
            nil
        else
            let ch = self.text.slice(self.pos, self.pos + 1)
            self.pos = self.pos + 1  # BUG: This doesn't work!
            ch
        end
    end
end

let p = Parser.create("hello")
puts(p.next_char())  # Prints: "h"
puts(p.pos._str())    # Prints: "0" (should be "1")
puts(p.next_char())  # Prints: "h" again! (should be "e")
```

## Observed Behavior

From debugging output when parsing brainfuck:
```
parse_ops called, pos=0, len=3
  char: 'true' at pos -1    # <-- Notice 'true' instead of character!
  char: 'true' at pos -1    # <-- pos is -1, not incrementing!
```

The field returns `true` (the boolean result of the assignment) instead of the actual value, and `pos` never increments.

## Expected Behavior

```quest
let p = Parser.create("hello")
puts(p.next_char())  # "h"
puts(p.pos._str())    # "1"
puts(p.next_char())  # "e"
puts(p.pos._str())    # "2"
```

## Impact

This bug makes it **impossible** to implement:
- Parsers with position tracking
- Iterators
- State machines
- Any algorithm requiring mutable instance state

## Workaround

Use functional approach with return values instead of mutation:

```quest
# Instead of mutating self.pos:
fun parse(text, pos)
    # ... do work ...
    {result: result, new_pos: pos + 1}  # Return new position
end

# Caller must manually track position:
let result = parse(text, 0)
let result2 = parse(text, result.new_pos)
```

This works but is verbose and un-ergonomic compared to mutable state.

## Context

Discovered while implementing brainfuck interpreter for benchmarks. The interpreter needs a parser that tracks position through the source code. Every attempt to use `self.pos = self.pos + 1` resulted in infinite loops because the position never advanced.

## Related Code

File: `benchmarks/brainfuck/bf.q` (lines 76-97)
File: `benchmarks/brainfuck/_test_parser.q` (demonstrates the bug clearly)

## Test Case

```quest
#!/usr/bin/env quest
# Minimal test case for mutable type fields bug

type Counter
    pub int: count

    static fun create()
        Counter.new(count: 0)
    end

    fun increment()
        puts("Before: count = " .. self.count._str())
        self.count = self.count + 1
        puts("After: count = " .. self.count._str())
        self.count
    end
end

let c = Counter.create()
puts("Initial: " .. c.count._str())

let result = c.increment()
puts("Returned: " .. result._str())
puts("Field value: " .. c.count._str())

# Expected output:
# Initial: 0
# Before: count = 0
# After: count = 1
# Returned: 1
# Field value: 1

# Actual output:
# Initial: 0
# Before: count = 0
# After: count = 0  (or true, or other wrong value)
# Returned: true (or 0)
# Field value: 0
```

## Possible Root Causes

1. **Assignment returns boolean** instead of assigned value
2. **Self reference issue** - mutations to `self.field` don't update the instance
3. **Scope issue** - `self` is a copy, not a reference
4. **Reference cell issue** - type instances might not be properly wrapped in RefCell

## Similar Issues in Other Languages

This works correctly in most languages:

**Python:**
```python
class Counter:
    def __init__(self):
        self.count = 0

    def increment(self):
        self.count += 1  # Works fine
```

**Rust:**
```rust
struct Counter { count: i32 }
impl Counter {
    fn increment(&mut self) {
        self.count += 1;  // Works with &mut self
    }
}
```

**Ruby:**
```ruby
class Counter
  attr_accessor :count
  def increment
    @count += 1  # Works fine
  end
end
```

Quest should support this pattern natively.

## Recommendations

1. Fix assignment to properly update type fields
2. Ensure assignment expressions return the assigned value (not boolean)
3. Add test cases for mutable type fields to prevent regression
4. Document whether types are value types or reference types

## Priority

**HIGH** - This is a fundamental feature needed for object-oriented programming and stateful algorithms. Without working mutable fields, many algorithms become impractical to implement.
