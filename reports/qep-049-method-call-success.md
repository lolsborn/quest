# QEP-049: Iterative Method Call Evaluation - Success Report

**Date:** 2025-10-13
**Status:** ✅ Complete - Method calls working iteratively with if_statement routing

## Summary

Successfully implemented iterative evaluation for method calls with positional arguments, fixed hybrid evaluation issues, and re-enabled if_statement routing. All 2504 tests passing.

## Achievements

### 1. Iterative Method Call Evaluation
**Status:** ✅ Working

Method calls with simple positional arguments now evaluate fully iteratively:

```quest
let arr = [1, 2, 3]
arr.len()           # Iterative: CallEvalArg → CallExecute → result
arr.push(4)         # Iterative: arg evaluation + method dispatch
io.is_dir("src")    # Iterative: module method call support
```

**Implementation:**
- `CallEvalArg` state evaluates arguments one at a time
- Arguments accumulate in `CallState.args`
- `CallExecute` dispatches with all evaluated arguments
- No recursion during argument evaluation

### 2. Module Method Call Support
**Status:** ✅ Working

Modules require special handling - they don't have methods, they have members that are functions:

```quest
use "std/io" as io
io.is_dir("path")   # Gets is_dir member, calls as function
```

**Implementation (CallExecute):**
```rust
if let QValue::Module(module) = base {
    // Built-in module methods
    match method_name.as_str() {
        "_doc" | "str" | "_rep" | "_id" => { /* special */ }
        _ => {
            // Get member and call as function
            let func = module.get_member(method_name)?;
            match func {
                QValue::Fun(_) => call_builtin_function(),
                QValue::UserFun(_) => call_user_function(module_scope),
                _ => error
            }
        }
    }
}
```

**Key Details:**
- Module scope sharing via `Scope::with_shared_base()`
- I/O redirection inheritance
- Proper function dispatch for builtin vs user-defined

### 3. Universal .is() Method Support
**Status:** ✅ Working

The `.is()` method works on all types but isn't implemented in each type's `call_method`:

```quest
5.is(Int)          # true
"hello".is(Str)    # true
arr.is(Array)      # true
```

**Implementation (CallExecute):**
```rust
} else if method_name == "is" {
    // Universal .is() method for all types
    let actual_type = base.as_obj().cls().to_lowercase();
    let expected_type = type_name.to_lowercase();
    QValue::Bool(actual_type == expected_type)
}
```

**Why Needed:**
- `call_method_on_value` doesn't implement `.is()` for each type
- Each type's `call_method` would error on "is"
- Must be handled before falling back to `call_method_on_value`

### 4. Hybrid Evaluation Fixed
**Status:** ✅ Fixed

**Problem:** When if_statement was routed to iterative, conditions with method calls failed:
```quest
if io.is_dir("src")  # Failed: "Module std/io has no method 'is_dir'"
    puts("yes")
end
```

**Root Causes:**
1. Module methods not supported in CallExecute
2. Universal .is() not supported in CallExecute
3. Both caused fallback to call_method_on_value which doesn't handle them

**Solution:**
- Added module method handling in CallExecute
- Added .is() handling in CallExecute
- Now works seamlessly with if_statement routing

### 5. if_statement Routing Re-enabled
**Status:** ✅ Enabled

```rust
// src/main.rs line 944
let use_iterative = matches!(rule,
    Rule::nil | Rule::boolean | Rule::number |
    Rule::bytes_literal | Rule::type_literal |
    Rule::if_statement  // ✅ Re-enabled
);
```

**What This Enables:**
- If conditions evaluate iteratively
- Method calls in conditions work correctly
- No hybrid evaluation mismatches
- All test suite scenarios pass

## Architecture

### State Machine Flow

```
if io.is_dir("src")
    ↓
if_statement routed to iterative
    ↓
IfEvalCondition: evaluate io.is_dir("src")
    ↓
postfix: base (io) + method_call (is_dir)
    ↓
PostfixEvalBase: evaluate base → Module(io)
    ↓
PostfixApplyOperation: handle method_call
    ↓
CallEvalArg(0): evaluate "src" → Str("src")
    ↓
CallExecute:
  - Check if module → Yes
  - Get member "is_dir" → Fun
  - Call builtin function
  - Return result → Bool(true)
    ↓
PostfixApplyOperation continues (no more ops)
    ↓
IfEvalCondition completes with Bool(true)
    ↓
IfEvalBranch(0): execute then branch
    ↓
Result
```

### Code Structure

**src/eval.rs** (~1,900 lines):

1. **Postfix Handling** (lines 497-707)
   - `PostfixEvalBase`: Evaluate primary expression
   - `PostfixApplyOperation`: Process operations sequentially
   - Handles method calls, member access (fallback), index access (fallback)

2. **Argument Evaluation** (lines 713-759)
   - `CallEvalArg`: Evaluate arguments one at a time
   - Accumulate in `CallState.args`
   - Continue to next arg or CallExecute

3. **Method Dispatch** (lines 761-856)
   - `CallExecute`: Execute method with all args
   - Special cases:
     - Module method calls (lines 773-820)
     - Universal .is() method (lines 821-836)
     - Regular method calls via call_method_on_value (lines 837-844)
   - Update parent postfix frame with result

## Fallback Strategies

### What Works Iteratively
✅ Positional arguments with simple expressions
✅ Module method calls
✅ Universal .is() method
✅ Array/Dict/Int/Str/etc method calls
✅ Chained method calls (basic)

### What Falls Back to Recursive
❌ Named arguments (`obj.method(x: 1, y: 2)`)
❌ Array unpacking (`obj.method(*args)`)
❌ Dict unpacking (`obj.method(**kwargs)`)
❌ Member access without parens (`arr.len` as method reference)
❌ Index access (`arr[i]`)

**Detection:**
```rust
// In PostfixApplyOperation
if item.as_rule() != Rule::expression {
    // Has named args, unpacking, etc - fall back to recursive
    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
    push_result_to_parent(&mut stack, result, &mut final_result)?;
}
```

## Test Results

### Full Test Suite
```
Total:   2512
Passed:  2504
Skipped: 8
Failed:  0
Status:  ✅ All tests passing
```

### Specific Test Cases
- ✅ Array methods: `arr.len()`, `arr.push(4)`, `arr.pop()`
- ✅ Module methods: `io.is_dir("src")`, `test.it()`, `log.info()`
- ✅ Universal .is(): `5.is(Int)`, `"hello".is(Str)`
- ✅ If with method calls: `if io.is_dir("src") ... end`
- ✅ Log tests (were failing before .is() fix)
- ✅ All existing functionality preserved

## Performance

**No Performance Regression:**
- Test suite runtime: ~2m8s (same as before)
- No additional overhead for method calls
- call_method_on_value still handles dispatch efficiently
- Module scope sharing via Rc<RefCell<>> (no copying)

**Potential Future Optimization:**
- Currently falls back to recursive for complex args
- Could implement named args/unpacking iteratively for further gains
- Index access could be optimized

## Files Modified

### src/eval.rs
- Lines 497-707: Postfix handling with method call setup
- Lines 713-759: CallEvalArg implementation
- Lines 761-856: CallExecute with module and .is() support
- Total changes: +180 lines

### src/main.rs
- Line 947: Re-enabled if_statement routing
- Total changes: +1 line, -3 lines (removed comment)

## Remaining Work

### To Enable Full Expression Chain Routing

1. **Named Arguments** (QEP-035)
   - Parse named_arg in argument_list
   - Evaluate name and value separately
   - Store in `CallState.kwargs`

2. **Array/Dict Unpacking** (QEP-034)
   - Evaluate unpack_args expressions
   - Expand into positional args
   - Evaluate unpack_kwargs expressions
   - Merge into keyword args

3. **Index Access**
   - Parse index_access expressions
   - Evaluate indices
   - Apply indexing with type-specific logic
   - Handle chained indexing

4. **Member Access (Method References)**
   - Create Fun objects for method references
   - Handle `arr.len` (without parens)
   - Return callable method reference

5. **Route All Operators**
   - Currently only literals + if_statement routed
   - All 17 operators implemented but not routed
   - Need to test routing complete expression chain
   - Verify no hybrid evaluation issues remain

### Estimated Effort
- Named args/unpacking: ~300 lines, 1-2 days
- Index access: ~200 lines, 1 day
- Method references: ~150 lines, 1 day
- Full routing + testing: ~100 lines, 1 day
- **Total: ~750 lines, 4-5 days**

## Key Learnings

1. **Module Methods Are Special**
   - Modules don't have methods, they have function members
   - Must get member and call as function, not dispatch as method
   - Requires module scope setup with shared base

2. **Universal Methods Need Early Handling**
   - `.is()` isn't in any type's call_method
   - Must be handled before call_method_on_value
   - Same pattern could apply to other universal methods

3. **Hybrid Evaluation is Tricky**
   - Can't route partial expression chains
   - Either route complete chain or use recursive
   - Mixing causes mismatches and errors

4. **Fallback Strategy Works**
   - Implement common case (simple positional args)
   - Fall back to recursive for complex cases
   - Get 80% benefit with 20% effort
   - Can extend iteratively over time

## Conclusion

**Status:** ✅ Successfully implemented iterative method call evaluation with if_statement routing.

**Key Achievements:**
- Method calls with positional args fully iterative
- Module method calls working correctly
- Universal .is() method supported
- if_statement routing enabled without issues
- All 2504 tests passing

**Next Steps:**
- Implement named args/unpacking support
- Implement index access iteratively
- Route complete expression chain
- Performance testing with deep recursion

This is a major milestone in QEP-049 - the core method call machinery is working iteratively, enabling most real-world code to avoid stack overflow issues.
