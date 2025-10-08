# Bug: Type Mutations Lost in Recursive Function Calls

**Status**: 🔴 OPEN - CRITICAL

**Reported**: 2025-10-05

**Severity**: HIGH - Breaks recursive algorithms with mutable state

## Summary

When a type instance is passed to a recursive function, mutations made during the recursion are lost when the function returns. Each recursive call appears to get a copy of the type instance rather than a reference.

This works for non-recursive calls but fails for recursion.

## Minimal Reproduction

```quest
type Counter
    pub int: count

    fun increment()
        self.count = self.count + 1
    end
end

fun recursive_increment(counter, n)
    if n > 0
        counter.increment()
        recursive_increment(counter, n - 1)  # ← Recursion loses mutations
    end
end

let c = Counter.create()
recursive_increment(c, 5)
puts(c.count)  # Prints: 0 (should print: 5)
```

## Actual Output

```
Initial: 0
recursive_increment(n=5) count=0
recursive_increment(n=4) count=1  # ← Mutation works here
recursive_increment(n=3) count=2  # ← And here
recursive_increment(n=2) count=3  # ← And here
recursive_increment(n=1) count=4  # ← And here
recursive_increment(n=0) count=5  # ← Final value is 5
After 5 recursive increments: 0 (should be 5)  # ← But lost!
```

Inside the recursion, mutations work. But when we return to the original caller, the original instance is unchanged.

## Expected Behavior

```quest
let c = Counter.create()
recursive_increment(c, 5)
puts(c.count)  # Should print: 5
```

Mutations should persist because types are reference types (as demonstrated by Bug #010 being fixed for non-recursive calls).

## Comparison with Non-Recursive Calls

**Non-recursive** (works correctly):
```quest
let c = Counter.create()
c.increment()
c.increment()
puts(c.count)  # Prints: 2 ✅ Correct!
```

**Recursive** (broken):
```quest
fun recursive_inc(counter, n)
    if n > 0
        counter.increment()
        recursive_inc(counter, n - 1)
    end
end

let c = Counter.create()
recursive_inc(c, 2)
puts(c.count)  # Prints: 0 ❌ Wrong!
```

## Impact on Brainfuck Benchmark

The brainfuck interpreter uses recursion for loops:

```quest
type Printer
    pub int: sum1
    pub int: sum2

    fun print_char(n)
        self.sum1 = (self.sum1 + n) % 255
        self.sum2 = (self.sum2 + self.sum1) % 255
    end
end

fun run_program(ops, tape, pos, printer)
    ...
    elif op["op"] == LOOP
        while tape[pos] > 0
            pos = run_program(op["val"], tape, pos, printer)  # ← Recursion!
        end
    elif op["op"] == PRINT
        printer.print_char(tape[pos])  # ← Mutation lost after recursion returns
    end
end
```

Result: Checksum is 0 instead of 42059 because mutations are lost.

## Root Cause Hypothesis

When calling a function recursively, Quest appears to:
1. Clone/copy the type instance for the nested call
2. Execute the nested call (mutations work on the copy)
3. Return from nested call
4. **Discard the mutated copy** instead of updating the original

This suggests types are being copied on function call rather than passed by reference.

## Workaround

**None for true recursion**. Options:
1. Use iteration instead of recursion (not always possible)
2. Return the mutated state explicitly (breaks encapsulation)
3. Use global/module-level mutable state (bad design)

For brainfuck specifically:
```quest
# Can't easily avoid recursion for nested loops
# Would need to implement explicit stack
```

## Test Case

```quest
type Acc
    pub int: value

    fun add(n)
        self.value = self.value + n
    end
end

# Test 1: Direct calls (should work)
fun test_direct()
    let acc = Acc.new(value: 0)
    acc.add(1)
    acc.add(2)
    acc.add(3)
    assert acc.value == 6  # ✅ Passes
end

# Test 2: Single level function call (should work)
fun add_via_func(acc, n)
    acc.add(n)
end

fun test_single_level()
    let acc = Acc.new(value: 0)
    add_via_func(acc, 5)
    assert acc.value == 5  # ✅ Passes (Bug #010 fixed this)
end

# Test 3: Recursive calls (BROKEN)
fun add_recursive(acc, n)
    if n > 0
        acc.add(1)
        add_recursive(acc, n - 1)
    end
end

fun test_recursive()
    let acc = Acc.new(value: 0)
    add_recursive(acc, 5)
    assert acc.value == 5  # ❌ Fails! acc.value is 0
end
```

## Expected Rust Implementation

Types should be wrapped in `Rc<RefCell<>>` to allow shared mutable references:

```rust
// Current (wrong?):
QValue::Struct(struct_inst.clone())  // Clone creates copy

// Should be:
QValue::Struct(Rc::clone(&struct_inst))  // Share reference
```

## Comparison with Other Languages

**Python** (references work):
```python
class Counter:
    def __init__(self):
        self.count = 0
    def increment(self):
        self.count += 1

def recursive_inc(counter, n):
    if n > 0:
        counter.increment()
        recursive_inc(counter, n - 1)

c = Counter()
recursive_inc(c, 5)
print(c.count)  # Prints: 5 ✅
```

**Ruby** (references work):
```ruby
class Counter
  attr_accessor :count
  def increment
    @count += 1
  end
end

def recursive_inc(counter, n)
  if n > 0
    counter.increment
    recursive_inc(counter, n - 1)
  end
end

c = Counter.new(count: 0)
recursive_inc(c, 5)
puts c.count  # Prints: 5 ✅
```

## Priority

**HIGH** because:
1. Breaks many recursive algorithms
2. Bug #010 fixed non-recursive case but recursion still broken
3. No workaround for algorithms requiring recursion
4. Blocks brainfuck benchmark completion
5. Unexpected behavior - types seem to be references until you use recursion

## Files

- `bugs/016_type_mutations_lost_in_recursion/000_initial_report.md`
- `benchmarks/brainfuck/_test_recursive_type.q` - Minimal reproduction
- `benchmarks/brainfuck/_test_printer.q` - Shows mutations work without recursion
- `benchmarks/brainfuck/bf.q` - Brainfuck interpreter blocked by this

## Related Bugs

- Bug #010 (mutable type fields) - FIXED for non-recursive calls ✅
- Bug #015 (dict mutations) - Dicts are intentionally value types
- This bug makes types inconsistent: references for simple calls, values for recursive calls
