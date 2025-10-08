# Bug #016 Test Results

**Date**: 2025-10-06
**Status**: Comprehensive test suite created and executed

---

## Test Suite Results

Ran comprehensive test suite in `test_all_scenarios.q`:

```
=== Bug #016 Test Suite ===

Test 1: Direct method call
  Result: 1 (expected: 1)
  ✅ PASS

Test 2: Method call in non-recursive function
  Result: 0 (expected: 1)
  ❌ FAIL

Test 3: Recursive function
  Result: 0 (expected: 3)
  ❌ FAIL

Test 4: Nested function calls
  Result: 0 (expected: 2)
  ❌ FAIL

Test 5: Method with parameters
  Result: 0 (expected: 5)
  ❌ FAIL

Test 6: Multiple parameters with struct
  c6a Result: 0 (expected: 1)
  c6b Result: 0 (expected: 1)
  ❌ FAIL
```

**Summary**: 1/6 tests pass (Test 7-10 had issues and didn't complete)

---

## Key Findings

### 1. Bug is NOT specific to recursion

The bug report title is misleading. The issue occurs with **ANY function parameter**, not just recursive calls.

```quest
# This FAILS (non-recursive)
fun increment_once(counter)
    counter.increment()
end

let c = Counter.new(count: 0)
increment_once(c)
puts(c.count)  # 0 (should be 1)
```

### 2. Only direct method calls work

```quest
# This WORKS
let c = Counter.new(count: 0)
c.increment()
puts(c.count)  # 1 ✅
```

### 3. The distinction

| Scenario | Works? | Why |
|----------|--------|-----|
| `obj.method()` | ✅ YES | Special copy-back logic updates original variable |
| `func(obj)` where `func` calls `obj.method()` | ❌ NO | Parameter is a copy, no way to update caller's variable |

---

## Scope of Impact

This bug affects:

1. ❌ Passing structs to functions (any function)
2. ❌ Recursive algorithms with mutable state
3. ❌ Helper functions that mutate structs
4. ❌ Callbacks that mutate structs
5. ❌ Higher-order functions with structs

This does NOT affect:

1. ✅ Direct method calls (`obj.method()`)
2. ✅ Method chaining (`obj.method1().method2()`)
3. ✅ Local mutations within a function

---

## Examples of Broken Patterns

### Pattern 1: Helper Functions

```quest
type Config
    pub debug: bool

    fun toggle_debug()
        self.debug = not self.debug
    end
end

fun apply_debug_mode(config)
    config.toggle_debug()  # ❌ Mutates copy, not original
end

let cfg = Config.new(debug: false)
apply_debug_mode(cfg)
puts(cfg.debug)  # false (should be true)
```

### Pattern 2: Accumulator Pattern

```quest
type Accumulator
    pub total: Int

    fun add(n)
        self.total = self.total + n
    end
end

fun sum_array(acc, arr)
    for item in arr
        acc.add(item)  # ❌ Mutates copy
    end
end

let acc = Accumulator.new(total: 0)
sum_array(acc, [1, 2, 3])
puts(acc.total)  # 0 (should be 6)
```

### Pattern 3: Builder Pattern

```quest
type QueryBuilder
    pub query: str

    fun where(condition)
        self.query = self.query .. " WHERE " .. condition
    end

    fun order_by(field)
        self.query = self.query .. " ORDER BY " .. field
    end
end

fun build_user_query(builder)
    builder.where("active = true")   # ❌ Lost
    builder.order_by("created_at")   # ❌ Lost
end

let qb = QueryBuilder.new(query: "SELECT * FROM users")
build_user_query(qb)
puts(qb.query)  # "SELECT * FROM users" (should have WHERE and ORDER BY)
```

### Pattern 4: Visitor Pattern

```quest
type Visitor
    pub count: Int

    fun visit(node)
        self.count = self.count + 1
    end
end

fun traverse(visitor, nodes)
    for node in nodes
        visitor.visit(node)  # ❌ Mutates copy
    end
end

let v = Visitor.new(count: 0)
traverse(v, [1, 2, 3, 4, 5])
puts(v.count)  # 0 (should be 5)
```

---

## Current Workarounds

### 1. Return the modified struct

```quest
fun increment_and_return(counter)
    counter.increment()
    counter  # Return modified copy
end

let c = Counter.new(count: 0)
c = increment_and_return(c)  # Reassign!
puts(c.count)  # 1 ✅
```

**Drawback**: Caller must remember to reassign, breaks intuitive semantics.

### 2. Use method chaining

```quest
# Instead of helper function, use methods
type Counter
    pub count: Int

    fun increment()
        self.count = self.count + 1
        self  # Return self for chaining
    end

    fun add(n)
        self.count = self.count + n
        self
    end
end

let c = Counter.new(count: 0)
c.increment().add(5)  # ✅ Works because direct method calls
```

**Drawback**: Can't use separate functions, limits composability.

### 3. Use global/module state

```quest
let global_counter = Counter.new(count: 0)

fun increment_global()
    global_counter.increment()  # ✅ Works because it's global
end
```

**Drawback**: Bad design, not thread-safe, hard to test.

---

## Comparison with Fixed Bugs

### Bug #015 (Dict mutations) - FIXED ✅

Dicts were changed to use reference semantics:

```quest
fun mutate_dict(d)
    d["x"] = 10
end

let d = {x: 5}
mutate_dict(d)
puts(d["x"])  # 10 ✅ Works now!
```

Dicts now persist mutations through function calls.

### Bug #016 (Struct mutations) - NOT FIXED ❌

Structs still use value semantics:

```quest
fun mutate_struct(s)
    s.field = 10
end

let s = MyStruct.new(field: 5)
mutate_struct(s)
puts(s.field)  # 5 ❌ Still broken!
```

Structs do NOT persist mutations through function calls.

---

## Why This is a Critical Bug

1. **Violates user expectations** - All major languages (Python, Ruby, JS, Java, C#) use reference semantics for objects
2. **Breaks common patterns** - Helper functions, visitors, builders, accumulators
3. **Inconsistent with dicts** - Dicts use references, structs use values
4. **No clear workaround** - Return-and-reassign is awkward and error-prone
5. **Silent failures** - No error message, mutations just silently lost

---

## Related Issues

- **Bug #015**: Dicts had same problem, FIXED by using `Rc<RefCell<>>`
- **Bug #010**: Mutable type fields, FIXED but only for direct method calls

---

## Next Steps

See [ROOT_CAUSE_ANALYSIS.md](ROOT_CAUSE_ANALYSIS.md) for detailed solution.

**Recommended**: Change `QValue::Struct(Box<QStruct>)` to `QValue::Struct(Rc<RefCell<QStruct>>)` to match dict behavior and fix all parameter-passing scenarios.
