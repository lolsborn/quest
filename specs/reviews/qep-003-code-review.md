# Code Review: QEP-003 Function Decorators Implementation

**Date:** 2025-10-17
**Reviewer:** Claude Code
**Status:** Complete
**Overall Grade:** B+

## Scope of Review

This review covers the QEP-003 function decorators implementation across:
- Rust implementation in `src/main.rs` (decorator application logic)
- Grammar in `src/quest.pest` (decorator syntax)
- Quest standard library in `lib/std/decorators.q` (built-in decorators)
- Test suite in `test/function/decorator_test.q`
- Specification in `specs/qep-003-function-decorators.md`

## Executive Summary

✅ **Overall Assessment:** Good implementation with solid foundation, but has **one critical limitation** (method decorators) and several areas for improvement.

**Strengths:**
- Clean decorator application logic with proper bottom-to-top ordering
- Good separation between decorator trait validation and fallback checking
- Comprehensive built-in decorators (Timing, Log, Cache, Retry, Once, Deprecated)
- Support for module-qualified decorators (`dec.Cache`)
- Proper handling of named/positional arguments
- Support for `_decorate` hook (Phase 2 feature)

**Issues Found:**
1. 🔴 **CRITICAL**: Decorators on methods explicitly blocked (src/main.rs:1989-1993)
2. 🟡 **Medium**: Potential correctness issues with callable field handling
3. 🟡 **Medium**: Missing validation and edge case handling
4. 🟢 **Minor**: Code clarity and documentation improvements needed

---

## Critical Issues

### 1. 🔴 Method Decorators Blocked (src/main.rs:1989-1993)

**Issue:** Decorators on instance/static methods fail with error message:
```rust
return type_err!(
    "Decorators on methods are not yet fully supported. \
     Decorators work on standalone functions and will be extended to methods in a future update."
);
```

**Impact:**
- QEP-003 spec claims decorators work on "any function declaration" including methods
- Tests in `test/function/decorator_test.q` only test standalone functions
- Standard library examples in `lib/std/decorators.q` docstrings show method decorators but they don't work
- Spec examples show decorated methods in UserRepository and UserService classes

**Root Cause:**
The code at src/main.rs:1984-1996 checks if decorator returns a `QValue::Struct` (decorated function) but methods must be stored as `QUserFun`:

```rust
let final_func = match func_value {
    QValue::UserFun(f) => *f,
    QValue::Struct(_) => {
        // TODO (QEP-003): Support decorated methods properly
        return type_err!("Decorators on methods are not yet fully supported...");
    }
    _ => return type_err!("Decorator must return a function or callable struct"),
};
```

**Solution Options:**
1. **Extend `methods` HashMap** to store `QValue` instead of `QUserFun` (RECOMMENDED)
   - Update `QType` struct to use `HashMap<String, QValue>` for methods
   - Update method calling logic to handle both `QUserFun` and callable `QStruct`
   - Minimal breaking changes, aligns with decorator pattern

2. **Create wrapper type** that holds the decorated struct
   - Define `DecoratedMethod` enum variant in `QValue`
   - Wrap decorated methods before storing in HashMap
   - More complex, but maintains type safety

3. **Update spec** to reflect current limitation (if not fixing)
   - Document that decorators only work on standalone functions
   - Remove method decorator examples from spec and library docs
   - Update QEP-003 status to reflect limitation

**Recommendation:** Implement option 1 - update the type system to allow `QValue` in methods HashMap, then update method calling logic to handle callable structs with `_call()` method.

**Priority:** P0 - Critical gap between spec and implementation

---

## Medium Priority Issues

### 2. 🟡 Callable Field Logic Inconsistency (src/main.rs:3527-3541)

**Issue:** When calling a field that's a callable struct (e.g., `self.func()` in decorators), the code has special handling but it's subtle:

```rust
// Check if struct has _call() method (callable decorator/functor)
let struct_type_name = struct_inst.borrow().type_name.clone();
if let Some(struct_qtype) = find_type_definition(&struct_type_name, scope) {
    if let Some(call_method) = struct_qtype.get_method("_call") {
        // Bind 'self' to the callable struct and call _call
        scope.push();
        scope.declare("self", field_val.clone())?;
        let return_value = call_user_function(call_method, call_args.clone(), scope)?;
        scope.pop();
        return Ok(return_value);
```

**Problem:** The spec says "Fields in decorated functions: `self.func()` calls the field if callable" (QEP-003 fix). This works, but the implementation:
- Doesn't check if `self.func` is already shadowing an outer `self`
- Creates a new scope and declares `self` again, which could be confusing
- Duplicated logic exists at src/main.rs:4033-4048

**Correctness Concern:** When `self.func(*args)` is called in a decorator's `_call` method:
1. `self` refers to the decorator instance
2. `self.func` retrieves the field (the wrapped function)
3. Code binds `self` AGAIN to `self.func`, shadowing the decorator's `self`

This seems intentional for the field-call pattern, but it's not clearly documented why this is safe.

**Example Test Case Missing:**
```quest
type nested_decorator
    func
    name: Str

    fun _call(*args)
        # Does self.name still work here after calling self.func()?
        puts("Decorator: " .. self.name)
        let result = self.func(*args)  # Does this shadow self?
        puts("Still: " .. self.name)   # Does this still work?
        return result
    end
end
```

**Recommendation:**
- Add comprehensive test for nested `self` binding with field access before and after callable field invocation
- Document this behavior clearly in code comments explaining why the `self` rebinding is safe
- Consider extracting this logic to a helper function to reduce duplication between lines 3527-3541 and 4033-4048

**Priority:** P1 - Potential correctness issue, needs testing

### 3. 🟡 Missing Validation in `apply_decorator` (src/main.rs:544-663)

**Issues:**

a) **No check for `func` parameter type** (src/main.rs:622-646):
```rust
// First positional arg is always the function being decorated
named_args.insert("func".to_string(), func.clone());
```
If the decorator type doesn't have a `func` field, this silently adds it to the kwargs but construction might fail with unclear error.

b) **`construct_struct` error handling** is implicit - no validation that decorator was successfully constructed before using it.

c) **Module-qualified decorators** (src/main.rs:562-566) build name by concatenating with `.` but no validation that all parts exist:
```rust
Rule::identifier => {
    if !decorator_name.is_empty() {
        decorator_name.push('.');
    }
    decorator_name.push_str(part.as_str());
}
```

If `@foo.bar.baz` is used but `foo` is not a module, error message will say "Decorator 'foo.bar.baz' not found" rather than "Module 'foo' not found".

**Recommendation:**
- Validate decorator type has expected constructor signature before attempting construction
- Add better error messages for construction failures with hints about required fields
- Validate module path components exist step by step for better error messages

**Priority:** P1 - User experience and error clarity

### 4. 🟡 Cache Decorator Implementation Issues (lib/std/decorators.q:156-255)

**Issues:**

a) **Cache key collision** (lib/std/decorators.q:190-193):
```quest
let key = args.str()
if kwargs.len() > 0
    key = key .. kwargs.str()
end
```
This string concatenation approach can cause collisions:
- `cache([1, 2])` and `cache([12])` might produce similar keys depending on str() implementation
- Dict ordering in `kwargs.str()` might not be stable
- No separator between args and kwargs strings

**Example collision scenarios:**
```quest
func(1, 2, 3)    # args.str() = "[1, 2, 3]"
func([1, 2], 3)  # args.str() = "[[1, 2], 3]" - could be ambiguous
```

b) **Eviction is naive** (lib/std/decorators.q:222-230):
```quest
if self.cache.len() >= max_val
    # Simple eviction: clear oldest (first key)
    # For production, implement LRU
    let first_key = self.cache.keys()[0]
```
Comment admits this is wrong - it evicts "first" key which is arbitrary in a hash map, not oldest by access time or creation time. This could evict the most recently used item.

c) **No thread safety** - Cache shared across calls but no locking (may not be issue if Quest is single-threaded)

d) **TTL comparison uses large sentinel value** (lib/std/decorators.q:203-206):
```quest
let ttl_val = 999999999
if self.ttl != nil
    ttl_val = self.ttl
end
```
Using a magic number instead of checking if TTL is nil separately. While functional, it's less clear.

**Recommendation:**
- Implement proper LRU eviction with linked list or separate access time tracking
- Use better cache key: implement hash-based approach or use proper serialization with delimiters
- Document thread-safety guarantees (or lack thereof)
- Consider using separate flag for "no TTL" instead of sentinel value

**Priority:** P1 - Cache correctness affects production use

---

## Minor Issues

### 5. 🟢 Once Decorator Field Mutation Pattern (lib/std/decorators.q:354-362)

```quest
fun _call(*args, **kwargs)
    # Use func._id() as a marker for "not yet called"
    # Store called state and result as instance variables dynamically
    if not self.called
        self.result = self.func(*args, **kwargs)
        self.called = true
    end
    return self.result
end
```

**Issue:** Comment says "Use func._id() as a marker" but code actually uses `self.called` field. Comment is outdated/misleading.

**Minor concern:** `self.called` is not declared in type definition, relies on dynamic field creation. This works but isn't type-safe. Looking at the type definition:

```quest
pub type Once
    func
    # Missing: called and result fields
```

**Recommendation:**
- Fix comment to remove reference to `func._id()`
- Add `called: Bool?` and `result` fields to type definition with proper initialization
- Document that Quest allows dynamic field creation if that's the intended pattern

**Priority:** P2 - Code clarity

### 6. 🟢 Missing Test Coverage

`test/function/decorator_test.q` has good basic coverage but missing:

**Not Tested:**
- ❌ Method decorators (justifiably missing since they don't work)
- ❌ Built-in decorators (Timing, Log, Cache, Retry, Once, Deprecated) - no dedicated tests
- ❌ Error cases:
  - Non-callable type used as decorator
  - Type missing Decorator trait
  - Wrong number/type of decorator arguments
  - Decorator construction failures
- ❌ Edge cases:
  - Decorator returns nil
  - Decorator with side effects only
  - Decorator modifying arguments
  - Multiple decorators with shared state
- ❌ Module-qualified decorators (`@dec.Cache`, `@module.decorator`)
- ❌ `_decorate` hook functionality
- ❌ Decorator metadata preservation (`_name`, `_doc`, `_id`)
- ❌ Decorator with kwargs
- ❌ Nested decorator calls

**Well Tested:**
- ✅ Basic decorators on standalone functions
- ✅ Stacking decorators with proper ordering
- ✅ Decorators with named arguments
- ✅ Varargs forwarding
- ✅ Function name preservation
- ✅ Zero-arg functions

**Recommendation:** Add test file `test/decorators/builtin_test.q` for built-in decorators and `test/decorators/error_test.q` for error cases.

**Priority:** P1 - Test coverage gaps

### 7. 🟢 Grammar Documentation (src/quest.pest)

`src/quest.pest` has good grammar rules but could use examples in comments:

```pest
decorator = { "@" ~ decorator_expression }

decorator_expression = {
    identifier ~ ("." ~ identifier)* ~ decorator_args?
}

decorator_args = {
    "(" ~ (expression ~ ("," ~ expression)*)? ~ ")"
}
```

**Recommendation:** Add comment examples:
```pest
# Decorator syntax
# Examples:
#   @my_decorator
#   @module.decorator
#   @Cache(max_size: 100)
#   @Retry(max_attempts: 3, delay: 1.0)
decorator = { "@" ~ decorator_expression }
```

**Priority:** P2 - Documentation clarity

### 8. 🟢 Retry Decorator Error Handling (lib/std/decorators.q:301-319)

```quest
catch e
    attempts = attempts + 1
    if attempts >= max_val
        # Final attempt failed - re-raise
        raise e
    end
```

**Issue:** Catches ALL exceptions. Spec mentions `exceptions: Array of exception types to catch. Default: [Err] (all)` parameter in documentation but it's not implemented:

```quest
pub type Retry
    """
    ...
    Parameters:
    - max_attempts: Maximum retry attempts. Default: 3
    - delay: Initial delay between retries in seconds. Default: 1.0
    - backoff: Multiplier for delay after each retry. Default: 1.0 (no backoff)
    - exceptions: Array of exception types to catch. Default: [Err] (all)  # <-- Not implemented
    """
    func
    max_attempts: Int?
    delay: Num?
    backoff: Num?
    # Missing: exceptions field
```

**Use case:** You might want to retry network errors but not validation errors:
```quest
@Retry(exceptions: [IOErr, NetworkErr])
fun fetch_data(url)
    # Retries on network issues but not on ValueErr or TypeErr
end
```

**Recommendation:** Either implement exception type filtering as documented, or remove from documentation.

**Priority:** P2 - Feature completeness vs documentation accuracy

### 9. 🟢 Deprecated Decorator Always Warns (lib/std/decorators.q:405-418)

```quest
fun _call(*args, **kwargs)
    let msg = "Function is deprecated"
    if self.message != nil
        msg = self.message
    end

    let warning = "[DEPRECATED] " .. self.func._name() .. ": " .. msg

    if self.alternative != nil
        warning = warning .. " (use " .. self.alternative .. " instead)"
    end

    puts(warning)  # <-- Always prints on every call
    return self.func(*args, **kwargs)
end
```

**Issue:** Prints deprecation warning on EVERY call. Most deprecation systems warn once per location or once per session.

**Recommendation:** Add mechanism to track if warning already shown, or add parameter `warn_once: Bool?` to control behavior.

**Priority:** P2 - Nice to have

---

## Performance Considerations

### 10. ✅ Good: Decorator Application is O(n)

src/main.rs:1714-1716:
```rust
for decorator in decorators.iter().rev() {
    func = apply_decorator(decorator, func, scope)?;
}
```
Clean iteration, no unnecessary allocations. Reverse iteration is correct for bottom-to-top application order.

### 11. ⚠️ Potential: Repeated HashMap Lookups

src/main.rs:588-594:
```rust
let has_decorator_trait = scope.get("Decorator")
    .and_then(|v| if matches!(v, QValue::Trait(_)) { Some(v) } else { None })
    .is_some();

if has_decorator_trait {
    if !qtype.implemented_traits.contains(&"Decorator".to_string()) {
```

This looks up `Decorator` trait every time a decorator is applied. Could cache this on first module load or pass as context.

**Impact:** Minimal unless applying many decorators in a tight loop. Not worth optimizing unless profiling shows it's a bottleneck.

**Recommendation:** Leave as-is unless performance testing shows this matters.

**Priority:** P3 - Premature optimization

### 12. ✅ Good: Cache Uses HashMap

Cache decorator uses Dict (HashMap) for O(1) lookups. Good choice for caching.

---

## Security Considerations

### 13. ✅ No Code Injection Risks

Decorator names are identifiers parsed by Pest grammar, not eval'd strings. No way to inject code through decorator syntax.

### 14. ✅ No Unsafe Rust Code

All decorator application code is safe Rust. No `unsafe` blocks in decorator logic.

### 15. ✅ No Arbitrary Code Execution

Decorators must be types defined in scope. No way to pass arbitrary code as decorator.

---

## Code Quality

### 16. ✅ Good Error Messages

src/main.rs:583, 595-598:
```rust
_ => return type_err!("'{}' is not a type (decorators must be types)", decorator_name),

return type_err!(
    "Type '{}' must implement Decorator trait to be used as decorator",
    qtype.name
);
```
Clear, actionable error messages that explain what went wrong and what's needed.

### 17. ⚠️ Code Duplication

Callable struct logic appears twice:
- src/main.rs:3527-3541 (field calls - `obj.field()`)
- src/main.rs:4033-4048 (direct calls - `func()`)

Nearly identical code for looking up `_call()` method and invoking it with `self` binding.

**Recommendation:** Extract to helper function:
```rust
fn call_callable_struct(
    struct_inst: &Rc<RefCell<QStruct>>,
    args: Vec<QValue>,
    scope: &mut Scope
) -> Result<QValue, EvalError> {
    let type_name = struct_inst.borrow().type_name.clone();
    if let Some(qtype) = find_type_definition(&type_name, scope) {
        if let Some(call_method) = qtype.get_method("_call") {
            scope.push();
            scope.declare("self", QValue::Struct(struct_inst.clone()))?;
            let result = call_user_function(call_method, args, scope)?;
            scope.pop();
            return Ok(result);
        }
    }
    type_err!("Type '{}' is not callable (missing _call() method)", type_name)
}
```

**Priority:** P2 - Code maintenance

### 18. ✅ Good: Decorator Trait Validation with Fallback

src/main.rs:588-609:
```rust
let has_decorator_trait = scope.get("Decorator")
    .and_then(|v| if matches!(v, QValue::Trait(_)) { Some(v) } else { None })
    .is_some();

if has_decorator_trait {
    // Decorator trait exists - verify implementation
    if !qtype.implemented_traits.contains(&"Decorator".to_string()) {
        return type_err!(
            "Type '{}' must implement Decorator trait to be used as decorator",
            qtype.name
        );
    }
} else {
    // Decorator trait not defined - fall back to checking _call method
    if qtype.get_method("_call").is_none() {
        return type_err!(
            "Type '{}' cannot be used as decorator (missing _call() method)",
            qtype.name
        );
    }
}
```

Good design: Strict checking when trait exists, lenient fallback for compatibility.

### 19. ✅ Good: Module-Qualified Decorator Support

src/main.rs:562-566:
```rust
Rule::identifier => {
    if !decorator_name.is_empty() {
        decorator_name.push('.');
    }
    decorator_name.push_str(part.as_str());
}
```

Allows `@dec.Cache` syntax by building qualified name. Clean implementation.

---

## Documentation Issues

### 20. 🟢 Spec vs Implementation Gaps

**QEP-003 spec claims:**
- "Decorators work on any function declaration that starts with the `fun` keyword - including standalone functions, instance methods, static methods, and methods within trait implementations."

**Reality:**
- Only standalone functions work
- Methods explicitly blocked with TODO comment

**Examples in spec that don't work:**
- UserService example with `@dec.Cache` on instance method (lines 393-414)
- UserRepository example with decorated methods (lines 758-800)
- MathUtils.fibonacci static method example (lines 425-436)

**Recommendation:** Either:
1. Implement method decorator support (PREFERRED)
2. Update spec to clarify current limitation
3. Add issue tracking method decorator support with timeline

**Priority:** P0 - Documentation accuracy

### 21. 🟢 Built-in Decorator Docstrings

lib/std/decorators.q has good docstrings for each decorator with parameter descriptions and examples. Well done!

---

## Architecture Review

### 22. ✅ Good: Phase 2 `_decorate` Hook Support

src/main.rs:649-662:
```rust
// QEP-003 Phase 2: Check if decorator type has _decorate method (decoration-time hook)
// This allows decorators to execute code when they are applied, not just when called
// Useful for: auto-registration, validation, parameter extraction, etc.
if let Some(_decorate_method) = qtype.get_method("_decorate") {
    // Call _decorate(func) - passes original function being decorated
    let args = vec![func];
    let result = call_method_on_value(&decorated_instance, "_decorate", args, scope)?;
    return Ok(result);
}
```

Forward-thinking design that enables advanced decorator patterns. Not used yet but infrastructure is in place.

### 23. ✅ Good: Bottom-to-Top Application Order

Matches Python, TypeScript conventions. Most intuitive for developers.

```rust
for decorator in decorators.iter().rev() {
    func = apply_decorator(decorator, func, scope)?;
}
```

### 24. ✅ Good: Named and Positional Args Support

Decorators support both:
```quest
@Timing  # No args
@Cache(100, 300)  # Positional
@Retry(max_attempts: 3, delay: 1.0)  # Named
```

Clean implementation handles all cases.

---

## Recommendations Summary

### Must Fix (P0)
1. **Method decorators** - Either implement or update spec/docs to clarify limitation
   - Update QType to store QValue in methods HashMap
   - Update method calling to handle callable structs
   - OR update spec to remove method decorator claims

2. **Documentation accuracy** - Align spec with implementation

### Should Fix (P1)
3. **Cache decorator** - Implement proper LRU eviction and better cache keys
   - Use proper LRU with access time tracking
   - Implement hash-based cache keys with proper delimiters
   - Document thread-safety

4. **Callable field logic** - Add tests for nested self binding, document behavior
   - Test that field access works before and after callable field invocation
   - Document why self rebinding is safe
   - Extract duplicated callable struct logic to helper

5. **Test coverage** - Add tests for built-in decorators and error paths
   - Create test/decorators/builtin_test.q
   - Create test/decorators/error_test.q
   - Test all built-in decorators
   - Test error conditions

6. **Validation** - Add decorator constructor validation with better errors

### Nice to Have (P2)
7. **Retry exception filtering** - Implement exceptions parameter as documented or remove from docs
8. **Code deduplication** - Extract callable struct helper function
9. **Once decorator** - Fix misleading comment and add fields to type definition
10. **Deprecated decorator** - Add warn_once option
11. **Grammar examples** - Add comment examples to pest grammar

---

## Testing Checklist

To verify decorator functionality:

- [x] Basic decorator application
- [x] Decorator stacking (multiple decorators)
- [x] Decorator with no arguments
- [x] Decorator with named arguments
- [x] Decorator with positional arguments
- [x] Varargs forwarding
- [x] Function name preservation
- [ ] Method decorators (BLOCKED - not implemented)
- [ ] Built-in Timing decorator
- [ ] Built-in Log decorator
- [ ] Built-in Cache decorator (with eviction)
- [ ] Built-in Retry decorator (with exponential backoff)
- [ ] Built-in Once decorator
- [ ] Built-in Deprecated decorator
- [ ] Module-qualified decorators (@module.decorator)
- [ ] Error: Non-type used as decorator
- [ ] Error: Type missing Decorator trait
- [ ] Error: Wrong decorator arguments
- [ ] Decorator with _decorate hook
- [ ] Nested callable field self binding

---

## Conclusion

The QEP-003 decorator implementation is **well-designed and mostly correct** for its intended scope (standalone functions). The code is clean, secure, and follows good practices. The main blocker is method decorators, which are explicitly documented as unsupported in the code but claimed to work in the spec.

The built-in decorators are functional but some (Cache, Retry) have known limitations documented in comments that should be addressed for production use.

**Overall Grade: B+** (would be A if method decorators worked and cache/retry were production-ready)

**Critical Path:**
1. Fix method decorator support OR update spec
2. Improve Cache decorator correctness
3. Add comprehensive tests
4. Address nested self binding concerns

**Nice to Have:**
- Retry exception filtering
- Code deduplication
- Better error messages
- Documentation improvements

The implementation demonstrates good understanding of decorator patterns and provides a solid foundation for Quest's decorator system.
