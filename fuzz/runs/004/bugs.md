# Bugs Found in Fuzz Test 004

## Bug 1: **kwargs Not Supported in Lambda Functions

**Severity:** Medium

**Description:** Lambda functions do not support `**kwargs` syntax, even though regular functions support it.

**Reproduction:**
```quest
let lambda_kwargs = fun (**opts)
    opts.len()
end

lambda_kwargs(a: 1, b: 2, c: 3)
```

**Error:**
```
ArgErr: Unknown keyword arguments: c, a, b
```

**Expected Behavior:** Lambda should accept arbitrary keyword arguments and collect them into a Dict, just like regular functions do.

**Status:** Confirmed bug - lambdas with `**kwargs` fail to work

---

## Bug 2: Function Calls in Default Parameters Cause Parse Error

**Severity:** Medium

**Description:** Using function calls as default parameter values causes a parse error.

**Reproduction:**
```quest
let counter = 0

fun increment()
    counter = counter + 1
    return counter
end

fun test_evaluation_order(a = increment(), b = increment(), c = increment())
    return "a=" .. a.str() .. " b=" .. b.str() .. " c=" .. c.str()
end

test_evaluation_order()
```

**Error:**
```
Parse error in function body:  --> 1:1
  |
1 | , b = increment(), c = increment())
  | ^---
  |
  = expected program
```

**Expected Behavior:** Function calls should be allowed in default parameters and evaluated at call time (according to QEP-033 spec).

**Status:** Confirmed bug - parser doesn't handle function calls in default params

---

## Bug 3: Nil Does Not Support .cls() Method

**Severity:** Low

**Description:** While most types support the `.cls()` method to get their type name, `nil` does not.

**Reproduction:**
```quest
let x = nil
puts(x.cls())
```

**Error:**
```
TypeErr: Type Nil does not support method calls
```

**Workaround:** Use `== nil` comparison or check with conditional logic.

**Expected Behavior:** Either `nil` should support `.cls()` returning "Nil", or the documentation should clarify that nil is a special case.

**Status:** Confirmed inconsistency in API
