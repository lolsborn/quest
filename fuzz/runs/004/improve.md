# Language Improvements Suggested by Fuzz Test 004

## 1. Better Error Messages for Argument Order

**Current Behavior:** When positional arguments are placed after keyword arguments, the error message is:
```
ArgErr: Positional argument cannot follow keyword argument
```

**Suggested Improvement:** Include the function name and show which argument violated the rule:
```
ArgErr: In call to 'test_req_args_kwargs': Positional argument "file1.txt" cannot follow keyword argument 'command'
```

**Benefit:** Helps developers quickly identify where the mistake is in complex function calls.

---

## 2. Dict Key Iteration Order Should Be Documented

**Current Behavior:** When iterating over Dict keys, the order appears to vary:
- Section 5: `age=30 name=Alice city=NYC`
- Section 6: Same parameters show different orders

**Suggested Improvement:** Document whether Dict key iteration order is:
- Insertion order (like Python 3.7+)
- Arbitrary/undefined (like older Python)
- Alphabetical

**Benefit:** Clarifies expectations for developers relying on dict ordering.

---

## 3. Support **kwargs in Lambda Functions

**Current Status:** `**kwargs` works in regular functions but not lambdas.

**Suggested Improvement:** Extend lambda syntax to support `**kwargs`:
```quest
let handler = fun (*args, **kwargs)
    # Handle arbitrary arguments
end
```

**Benefit:** Provides consistency and allows lambdas to be used as full function replacements.

---

## 4. Support Function Calls in Default Parameters

**Current Status:** Parse error when using function calls as default values.

**Suggested Improvement:** According to QEP-033, defaults should be evaluated at call time. This should include function calls:
```quest
fun log(level = get_default_level(), message)
    # level is evaluated fresh for each call
end
```

**Benefit:** Enables dynamic defaults based on runtime state, matching behavior in Python, JavaScript, etc.

---

## 5. Consider Adding .is(Nil) Support

**Current Status:** Can't use `.is(nil)` - must use `== nil`.

**Suggested Improvement:** Either:
- Add `Nil` as a type constant so `.is(Nil)` works
- Document that `== nil` is the canonical way to check

**Benefit:** Provides API consistency across all types.

---

## 6. Array Unpacking Syntax (Future)

**Current Status:** Must manually pass array elements.

**Suggested Feature:** Support Python-style unpacking:
```quest
let args = [1, 2, 3]
sum(*args)  # Unpacks array to positional arguments
```

**Benefit:** Makes working with dynamic argument lists much cleaner (mentioned in QEP-034 Phase 3).

---

## 7. Dict Unpacking for Kwargs (Future)

**Current Status:** Must pass individual kwargs.

**Suggested Feature:** Support dict unpacking for keyword arguments:
```quest
let options = {host: "localhost", port: 8080, ssl: true}
connect(**options)  # Unpacks dict to keyword arguments
```

**Benefit:** Enables dynamic construction of keyword arguments (mentioned in QEP-034 Phase 3).
