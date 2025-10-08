# Bug: Dict Mutations Inside Functions Don't Persist

**Status**: 🔴 OPEN

**Reported**: 2025-10-05

**Severity**: MEDIUM - Makes dicts less useful for mutable state

## Summary

When a dict is passed to a function and mutated inside that function, the mutations do not persist in the original dict. This is because dicts are passed by value (copied) rather than by reference.

This differs from type instances, which DO persist mutations after method calls.

## Minimal Reproduction

```quest
fun mutate_dict(d)
    puts("Before: d['x'] = " .. d["x"].str())
    d["x"] = d["x"] + 1
    puts("Inside: d['x'] = " .. d["x"].str())
end

let mydict = {x: 5, y: 10}
puts("Initial: mydict['x'] = " .. mydict["x"].str())

mutate_dict(mydict)

puts("After: mydict['x'] = " .. mydict["x"].str())
# Prints: "After: mydict['x'] = 5" (should be 6)
```

## Actual Output

```
Initial: mydict['x'] = 5
Before: d['x'] = 5
Inside: d['x'] = 6
After: mydict['x'] = 5    # ← Bug: mutation didn't persist!
```

## Expected Behavior

Like Python, Ruby, JavaScript, and most languages, dicts should be mutable reference types:

```python
# Python - mutations persist
def mutate_dict(d):
    d['x'] = d['x'] + 1

mydict = {'x': 5}
mutate_dict(mydict)
print(mydict['x'])  # Prints: 6 ✅
```

## Comparison with Types

Type instances DO persist mutations:

```quest
type Counter
    pub int: count
    fun increment()
        self.count = self.count + 1
    end
end

let c = Counter.create(5)
c.increment()
puts(c.count)  # Prints: 6 ✅ Works correctly!
```

This inconsistency is confusing - why do types persist mutations but dicts don't?

## Impact on Brainfuck Benchmark

Initially implemented Printer as a dict:

```quest
fun printer_new(quiet)
    {sum1: 0, sum2: 0, quiet: quiet}
end

fun printer_print(printer, n)
    printer["sum1"] = (printer["sum1"] + n) % 255  # Doesn't persist!
end
```

This produced incorrect checksums (0 instead of 42059) because mutations didn't persist.

**Workaround**: Had to convert Printer to a type instead of a dict.

## Design Question

Should dicts be:
1. **Reference types** (mutations persist) - Like Python, Ruby, JS
2. **Value types** (mutations don't persist) - Current behavior
3. **Explicit choice** - `dict.clone()` for copy, default is reference

## Implications

### If dicts are value types (current):
- ✅ Safer (no accidental mutations)
- ✅ Easier to reason about (no hidden side effects)
- ❌ Inconsistent with other languages
- ❌ Inconsistent with Quest's own types (which are reference types)
- ❌ Forces use of types even for simple mutable state

### If dicts are reference types (proposed):
- ✅ Consistent with other languages
- ✅ Consistent with Quest's type system
- ✅ More flexible for mutable state
- ❌ Could cause accidental mutations
- ❌ Need `.clone()` method for explicit copies

## Recommendation

**Make dicts reference types** to match:
1. Other scripting languages (Python, Ruby, JS, Lua, Perl, PHP)
2. Quest's own type system (types are reference types)
3. Developer expectations

Add explicit `.clone()` method for when copies are needed.

## Test Cases

```quest
# Test 1: Basic mutation
fun mutate(d)
    d["x"] = 10
end

let d = {x: 5}
mutate(d)
assert d["x"] == 10  # Should pass if dicts are references

# Test 2: Nested mutations
fun add_key(d)
    d["new"] = "value"
end

let d2 = {old: "data"}
add_key(d2)
assert d2["new"] == "value"  # Should pass

# Test 3: Mutation in loops
let counters = [{count: 0}, {count: 0}]
for c in counters
    c["count"] = c["count"] + 1
end
assert counters[0]["count"] == 1  # Should pass

# Test 4: Explicit clone (if we add it)
let original = {x: 5}
let copy = original.clone()
copy["x"] = 10
assert original["x"] == 5  # Original unchanged
assert copy["x"] == 10      # Copy changed
```

## Workaround

Use types instead of dicts for mutable state:

```quest
# Instead of dict:
fun printer_new(quiet)
    {sum1: 0, sum2: 0, quiet: quiet}  # ← Doesn't work
end

# Use type:
type Printer
    pub int: sum1
    pub int: sum2
    pub bool: quiet
end  # ← Works correctly
```

## Files

- `bugs/015_dict_mutations_dont_persist/000_initial_report.md` (this file)
- `benchmarks/brainfuck/_test_dict_mutation.q` - Demonstrates the bug

## Priority

**MEDIUM** because:
- Workaround exists (use types instead)
- But creates inconsistency in the language
- And differs from all major scripting languages
- Forces verbose type declarations for simple mutable state

## Related Issues

- Bug #010 (mutable type fields) - FIXED ✅
- Types DO persist mutations correctly
- This creates an inconsistency: types are references, dicts are values
