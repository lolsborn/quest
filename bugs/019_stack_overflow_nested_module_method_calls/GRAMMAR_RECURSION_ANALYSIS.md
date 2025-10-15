# Pest Grammar Recursion Analysis for Quest Language

**Date**: 2025-10-11
**Analysis**: Potential recursion issues in [src/quest.pest](src/quest.pest) and [src/main.rs](src/main.rs)
**Context**: Investigation related to Bug #019 (stack overflow in nested module method calls)

---

## Executive Summary

The Quest language uses Pest parser with recursive grammar rules and a recursive evaluator (`eval_pair`). Analysis reveals **multiple potential recursion hazards**:

1. **Expression grammar recursion** (safe with precedence climbing)
2. **Postfix operation chains** (potential issue)
3. **eval_pair recursive calls** (instrumented, but unbounded in some paths)
4. **Scope cloning in function calls** (CRITICAL - creates logical circular references)

**Primary Finding**: The grammar itself is **safe**, but the **evaluation logic** has unbounded recursion risks, particularly in **function call chains with captured scopes**.

---

## Part 1: Grammar-Level Recursion

### 1.1 Expression Precedence Chain

The grammar uses **precedence climbing** for expression parsing, which creates a deep but finite call chain:

```pest
expression = { lambda_expr }
lambda_expr = { "fun" ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end" | elvis_expr }
elvis_expr = { logical_or ~ (elvis_op ~ logical_or)* }
logical_or = { logical_and ~ (or_op ~ logical_and)* }
logical_and = { logical_not ~ (and_op ~ logical_not)* }
logical_not = { not_op ~ logical_not | bitwise_or }
bitwise_or = { bitwise_xor ~ ("|" ~ bitwise_xor)* }
bitwise_xor = { bitwise_and ~ ("^" ~ bitwise_and)* }
bitwise_and = { shift ~ ("&" ~ shift)* }
shift = { comparison ~ (shift_op ~ comparison)* }
comparison = { concat ~ (comparison_op ~ concat)* }
concat = { addition ~ (".." ~ addition)* }
addition = { multiplication ~ (add_op ~ multiplication)* }
multiplication = { unary ~ (mul_op ~ unary)* }
unary = { unary_op ~ unary | postfix }
postfix = { primary ~ (...postfix_operations)* }
primary = { ... }
```

**Max Grammar Depth**: ~16 levels (expression → primary)

**Risk Level**: **LOW**
- Standard precedence climbing pattern
- Depth bounded by grammar structure
- Pest handles this efficiently

### 1.2 Postfix Operation Chains

```pest
postfix = {
    primary ~ (
        "." ~ method_name ~ "(" ~ argument_list? ~ ")"  // method call
        | "." ~ method_name                              // member access
        | index_access                                   // array/dict access
    )*
}
```

**The asterisk `*` allows unlimited chaining**:
- `obj.foo().bar().baz().qux()...` → infinite chain possible
- `arr[0][1][2][3]...` → infinite nested indexing

**Risk Level**: **MEDIUM**
- Grammar allows unlimited chaining
- Real-world code rarely exceeds depth 5-10
- **Evaluator must handle this safely** (see Part 2)

### 1.3 Nested Expressions in Function Calls

```pest
argument_list = { (argument_item) ~ ("," ~ argument_item)* }
argument_item = { unpack_kwargs | unpack_args | named_arg | expression }
```

Each argument can be a **full expression**, leading to nested recursion:

```quest
func(
    other_func(
        nested_func(
            deeply_nested(...)
        )
    )
)
```

**Risk Level**: **LOW-MEDIUM**
- Bounded by practical code complexity
- Stack depth = call depth + expression depth
- Modern systems handle 100s of levels easily

### 1.4 Statement Recursion (Control Flow)

Statements can contain nested statements:

```pest
if_statement = { "if" ~ expression ~ statement* ~ elif_clause* ~ else_clause? ~ "end" }
while_statement = { "while" ~ expression ~ statement* ~ "end" }
for_statement = { "for" ~ identifier ~ "in" ~ for_range ~ statement* ~ "end" }
```

**Risk Level**: **LOW**
- Standard control flow nesting
- Real code rarely exceeds depth 10-15

---

## Part 2: Evaluator Recursion (`eval_pair`)

The main evaluator in [src/main.rs:872](src/main.rs#L872) is **highly recursive**. Every grammar rule calls `eval_pair` recursively:

### 2.1 Current Stack Depth Tracking

```rust
pub fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    static DEPTH: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
    let depth = DEPTH.fetch_add(1, std::sync::atomic::Ordering::SeqCst);

    if depth > 60 {
        eprintln!("!!! RECURSION DEPTH EXCEEDED 60 !!!");
        DEPTH.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
        return Err("Stack depth exceeded - infinite loop detected".to_string());
    }

    if depth > 40 {
        eprintln!("DEEP[{}]: {:?} -> {}", depth, pair.as_rule(), ...);
    }

    // ... evaluation logic ...
}
```

**Protection**: ✅ Yes - Hard limit at depth 60

**Issues**:
- Depth counter is **global** (tracks `eval_pair` calls, not logical recursion)
- Doesn't distinguish between:
  - Grammar recursion (safe)
  - Function call recursion (potentially unbounded)
- Depth 60 may be too **low** for deeply nested expressions
- Depth 60 may be too **high** for infinite function call loops

### 2.2 eval_pair Recursion Patterns

#### Pattern A: Grammar Rule Unwrapping (Safe)

```rust
Rule::statement => {
    let inner = pair.into_inner().next().unwrap();
    eval_pair(inner, scope)  // One level deeper
}

Rule::expression_statement => {
    let inner = pair.into_inner().next().unwrap();
    eval_pair(inner, scope)  // One level deeper
}
```

**Depth**: Adds 1-2 levels per grammar layer
**Risk**: LOW - Bounded by grammar depth (~16 max)

#### Pattern B: Iterating Over Children (Safe)

```rust
Rule::if_statement => {
    for stmt_pair in iter {
        result = eval_pair(stmt_pair, scope)?;  // Sequential calls
    }
}
```

**Depth**: Each call returns before next
**Risk**: LOW - Not actually recursive (tail-call-like)

#### Pattern C: Nested Expression Evaluation (Medium Risk)

```rust
Rule::addition => {
    let lhs = eval_pair(lhs_pair, scope)?;
    let rhs = eval_pair(rhs_pair, scope)?;
    // ...
}
```

**Depth**: Multiplies with nested expressions
**Example**: `1 + 2 * 3 + 4 * 5` → depth ~10
**Risk**: MEDIUM - Deep expressions can stack up

#### Pattern D: Postfix Chains (Medium-High Risk)

```rust
Rule::postfix => {
    let mut result = eval_pair(first_pair, scope)?;  // Base evaluation

    while i < pairs.len() {
        // Method calls don't recursively call eval_pair
        // UNLESS the arguments contain complex expressions
        let args = parse_call_arguments(args_pair, scope)?;  // Recursive!
    }
}
```

**Location**: [src/main.rs:2748-2950](src/main.rs#L2748-L2950)

**Risk**: MEDIUM-HIGH
- Base evaluation is safe (non-recursive iteration)
- **Arguments** can trigger deep recursion:
  - `obj.method(other.method(nested.method(...)))`
  - Each argument evaluation calls `eval_pair` recursively

#### Pattern E: Function Calls with Captured Scopes (CRITICAL)

From [src/function_call.rs:65](src/function_call.rs#L65):

```rust
pub fn call_user_function(
    user_fun: &QUserFun,
    args: CallArguments,
    scope: &mut Scope
) -> Result<QValue, String> {
    let mut new_scope = Scope::new();
    new_scope.scopes = user_fun.captured_scopes.clone();  // CLONE captured scopes

    // ... execute function body ...
}
```

Combined with function lookup from [src/main.rs:3549](src/main.rs#L3549):

```rust
Rule::primary => {
    if let Some(func_value) = scope.get(func_name) {  // CLONES function!
        match func_value {
            QValue::UserFun(user_fun) => {
                return call_user_function(&user_fun, call_args, scope);
            }
        }
    }
}
```

And scope cloning from [src/scope.rs:220-227](src/scope.rs#L220-L227):

```rust
pub fn get(&self, name: &str) -> Option<QValue> {
    for scope in self.scopes.iter().rev() {
        if let Some(value) = scope.borrow().get(name) {
            return Some(value.clone());  // CLONE here!
        }
    }
    None
}
```

**The Circular Reference Problem**:

1. Function `helper()` is defined → captures current scope
2. Captured scope contains: `{"helper": QValue::UserFun(helper)}`
3. Calling `helper()`:
   - Line 3549: `scope.get("helper")` **clones** the function
   - Line 65: `user_fun.captured_scopes.clone()` clones scopes
   - Cloned scopes **still contain** `"helper": QValue::UserFun(helper)`
4. Inside `helper()`, calling `helper()` again:
   - Looks up "helper" in captured scope
   - Clones it again (with nested captured scopes)
   - **Infinite logical recursion**

**Risk**: **CRITICAL** 🔴
- Creates **logical circular references**
- Each function call re-clones the entire scope chain
- No escape condition - will always overflow
- **THIS IS THE LIKELY ROOT CAUSE OF BUG #019**

---

## Part 3: Specific Recursion Hazards

### 3.1 Postfix Chain Evaluation

**Code**: [src/main.rs:2748-2950](src/main.rs#L2748-L2950)

```rust
while i < pairs.len() {
    let current = &pairs[i];
    match current.as_rule() {
        Rule::identifier | Rule::method_name => {
            if has_parens || has_args {
                let call_args = if has_args {
                    let args_pair = pairs[i + 1].clone();
                    parse_call_arguments(args_pair, scope)?  // RECURSIVE!
                } else {
                    // ...
                };

                // Call method (may trigger function_call.rs)
                result = call_method_on_value(&result, method_name, args, scope)?;
            }
        }
        Rule::index_access => {
            let indices = index_pair.into_inner()
                .map(|p| eval_pair(p, scope))  // RECURSIVE!
                .collect::<Result<Vec<_>, _>>()?;
        }
    }
}
```

**Issue**: Method chains like `obj.m1(args).m2(args).m3(args)` are **iterative** (safe), but if `args` contains nested calls, it becomes **recursive**.

**Example That Would Fail**:
```quest
obj.method(
    nested.call(
        deeper.call(
            deepest.call(...)
        )
    )
).another().chain()
```

**Mitigation**: Current depth limit of 60 should catch this

### 3.2 Array Higher-Order Functions

**Code**: [src/main.rs:2908-2909](src/main.rs#L2908-L2909)

```rust
match method_name {
    "map" | "filter" | "each" | "reduce" | "any" | "all" | "find" | "find_index" => {
        result = call_array_higher_order_method(arr, method_name, args, scope, call_user_function_compat)?;
    }
}
```

These call **user-provided functions** on every array element. If the function itself calls another higher-order function:

```quest
let data = [[1, 2], [3, 4], [5, 6]]
data.map(fun (row) row.map(fun (x) x * 2 end) end)
```

**Depth**: Nested higher-order functions multiply recursion depth
**Risk**: MEDIUM - Caught by depth limit, but may reject valid code

### 3.3 Module Method Calls

**Code**: [src/main.rs:2854-2878](src/main.rs#L2854-L2878)

```rust
QValue::UserFun(user_fn) => {
    let mut module_scope = Scope::with_shared_base(
        module.get_members_ref(),
        Rc::clone(&scope.module_cache)
    );

    module_scope.push();
    for (k, v) in scope.to_flat_map() {
        if !module_scope.scopes[0].borrow().contains_key(&k) {
            module_scope.scopes[1].borrow_mut().insert(k, v);  // CLONE v!
        }
    }

    let ret = call_user_function(&user_fn, call_args.clone(), &mut module_scope)?;
}
```

**Issue**: When calling module methods, the **entire caller scope is cloned** into the module scope. This includes:
- All variables
- All function definitions (including the calling function itself!)

**Risk**: HIGH - Circular reference similar to Pattern E

---

## Part 4: Recommendations

### 4.1 Immediate Actions (Critical)

#### Fix 1: Filter Functions from Captured Scopes

**Location**: Function definition code (where `capture_current_scope` is called)

**Current** (from [src/function_call.rs:7-23](src/function_call.rs#L7-L23)):
```rust
pub fn capture_current_scope(scope: &Scope) -> Vec<Rc<RefCell<HashMap<String, QValue>>>> {
    scope.scopes.iter().map(|s| Rc::clone(s)).collect()
}
```

**Fix**:
```rust
pub fn capture_current_scope(scope: &Scope) -> Vec<Rc<RefCell<HashMap<String, QValue>>>> {
    scope.scopes.iter().map(|s| {
        let filtered = s.borrow()
            .iter()
            .filter(|(_, v)| !matches!(v, QValue::UserFun(_)))
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect();
        Rc::new(RefCell::new(filtered))
    }).collect()
}
```

**Pros**:
- Completely eliminates circular references
- Simple to implement
- Functions can still access variables from defining scope

**Cons**:
- Closures cannot call other functions from their defining scope
- Breaks mutual recursion via closures
- May break existing code that relies on function access in closures

#### Fix 2: Separate Function Call Depth Tracking

**Add to `Scope` or global state**:

```rust
// Separate counter for LOGICAL function calls (not grammar recursion)
static FUNCTION_CALL_DEPTH: AtomicUsize = AtomicUsize::new(0);

pub fn call_user_function(...) -> Result<QValue, String> {
    let fn_depth = FUNCTION_CALL_DEPTH.fetch_add(1, Ordering::SeqCst);

    if fn_depth > 100 {
        FUNCTION_CALL_DEPTH.fetch_sub(1, Ordering::SeqCst);
        return Err(format!("Maximum function call depth exceeded (100). Possible infinite recursion in function '{}'",
            user_fun.name.as_deref().unwrap_or("<anonymous>")));
    }

    // ... function body ...

    let result = eval_body(...);
    FUNCTION_CALL_DEPTH.fetch_sub(1, Ordering::SeqCst);
    result
}
```

**Pros**:
- Tracks actual function call recursion
- Allows deeper grammar recursion (expressions)
- Better error messages

**Cons**:
- Doesn't fix root cause (circular references)
- Limit of 100 may still be hit by valid recursive functions

### 4.2 Medium-Term Improvements

#### Improvement 1: Lazy Function Resolution

**Concept**: Don't clone functions on lookup - resolve by name at call time

**Change from**:
```rust
if let Some(func_value) = scope.get(func_name) {  // Clones entire QUserFun
    match func_value {
        QValue::UserFun(user_fun) => call_user_function(&user_fun, ...)
    }
}
```

**Change to**:
```rust
if let Some(func_ref) = scope.get_function_ref(func_name) {  // Returns &QUserFun (no clone)
    call_user_function(func_ref, ...)
}
```

**Implementation**:
```rust
impl Scope {
    pub fn get_function_ref(&self, name: &str) -> Option<&QUserFun> {
        for scope in self.scopes.iter().rev() {
            if let Some(QValue::UserFun(user_fun)) = scope.borrow().get(name) {
                // Return reference without cloning
                // Problem: Can't return reference to value inside RefCell!
                // Need different approach...
            }
        }
        None
    }
}
```

**Issue**: Can't return `&QUserFun` from inside `RefCell<HashMap<...>>`
**Solution**: Store functions in a **separate data structure** (function table)

#### Improvement 2: Function Table / Registry

**Concept**: Store all functions in a global or scope-level registry, reference by ID

```rust
// Global function registry
static FUNCTION_REGISTRY: OnceLock<Mutex<HashMap<u64, QUserFun>>> = OnceLock::new();

// In scope, store function IDs instead of values
pub enum QValue {
    FunctionRef(u64),  // Reference by ID
    UserFun(Box<QUserFun>),  // Keep for backward compat
    // ...
}

// Function call
if let Some(QValue::FunctionRef(fn_id)) = scope.get(func_name) {
    let registry = FUNCTION_REGISTRY.get().unwrap().lock().unwrap();
    let user_fun = registry.get(&fn_id).unwrap();
    call_user_function(user_fun, ...)
}
```

**Pros**:
- Eliminates cloning entirely
- No circular references possible
- Functions can reference each other freely

**Cons**:
- Major refactoring required
- Global state management complexity
- Lifetime issues with closures

### 4.3 Long-Term Architectural Changes

#### Option A: Tail Call Optimization

Convert tail-recursive calls to iteration where possible:

```rust
// Currently recursive
fn eval_pair(pair, scope) -> Result<QValue> {
    match pair.as_rule() {
        Rule::statement => eval_pair(inner, scope),  // Tail call
        // ...
    }
}

// Optimized (trampoline pattern)
fn eval_pair(mut pair, scope) -> Result<QValue> {
    loop {
        match pair.as_rule() {
            Rule::statement => {
                pair = inner;  // Update instead of recursive call
                continue;
            }
            // ...
        }
    }
}
```

**Impact**: Reduces stack depth for linear grammar chains

#### Option B: Explicit Stack Management

Replace implicit call stack with explicit data structure:

```rust
struct EvalFrame {
    pair: Pair<Rule>,
    state: EvalState,
}

fn eval_iterative(initial_pair, scope) -> Result<QValue> {
    let mut stack = vec![EvalFrame::new(initial_pair)];

    while let Some(frame) = stack.pop() {
        match frame.pair.as_rule() {
            // Push child frames instead of recursive calls
            Rule::addition => {
                stack.push(EvalFrame::new(rhs_pair));
                stack.push(EvalFrame::new(lhs_pair));
            }
            // ...
        }
    }
}
```

**Pros**:
- Complete control over stack depth
- Can implement custom depth limits
- No language recursion limits

**Cons**:
- Major rewrite of evaluator
- Complex state management
- Loss of natural recursive structure

---

## Part 5: Testing Recommendations

### 5.1 Grammar Depth Tests

Add tests for maximum safe depth:

```quest
# test/grammar_depth_test.q

# Deep expression nesting (should work)
let x = 1 + 2 + 3 + 4 + ... (100 terms)

# Deep postfix chains (should work)
let result = obj.m1().m2().m3()...(depth 50)

# Deep function argument nesting (should work)
f(g(h(i(j(k(l(m(...))))))))  # depth 50
```

### 5.2 Function Recursion Tests

```quest
# test/function_recursion_test.q

# Direct recursion (should work with limit)
fun factorial(n)
    if n <= 1
        return 1
    end
    n * factorial(n - 1)
end

factorial(100)  # Should hit depth limit
factorial(50)   # Should work

# Mutual recursion (test circular reference fix)
fun is_even(n)
    if n == 0
        return true
    end
    is_odd(n - 1)
end

fun is_odd(n)
    if n == 0
        return false
    end
    is_even(n - 1)
end

is_even(100)  # Should work after fix
```

### 5.3 Closure Scope Tests

```quest
# test/closure_scope_test.q

# Test that functions don't capture themselves
fun outer()
    fun inner()
        puts("Inner called")
        # Should NOT be able to call itself infinitely
    end

    inner()
    inner()
end

outer()  # Should work (print twice)

# Test captured variable access
fun make_counter()
    let count = 0

    fun increment()
        count = count + 1
        count
    end

    increment
end

let counter = make_counter()
counter()  # 1
counter()  # 2
counter()  # 3
```

---

## Part 6: Conclusions

### Grammar Analysis: ✅ SAFE
- Standard precedence climbing pattern
- Depth bounded by grammar structure (~16 levels)
- No infinite loops possible in grammar alone

### Evaluator Analysis: ⚠️ MULTIPLE ISSUES

1. **Critical Issue**: Function scope cloning creates circular references (Bug #019)
2. **Medium Issue**: Global depth limit doesn't distinguish grammar vs. function recursion
3. **Low Issue**: Deep expression nesting could hit depth limit unnecessarily

### Priority Fixes:

1. **CRITICAL**: Filter functions from captured scopes OR implement lazy function resolution
2. **HIGH**: Add separate function call depth tracking
3. **MEDIUM**: Increase grammar recursion depth limit to 100+, function depth to 1000+
4. **LOW**: Consider tail call optimization for common patterns

### Related Bugs:

- **Bug #019**: Stack overflow in nested module method calls → **Root cause identified**
- See [ANALYSIS2.md](bugs/019_stack_overflow_nested_module_method_calls/ANALYSIS2.md) for detailed analysis

---

## Appendix A: Key Code Locations

| Location | Description | Risk |
|----------|-------------|------|
| [src/quest.pest:243-307](src/quest.pest#L243-L307) | Expression grammar (precedence chain) | LOW |
| [src/quest.pest:289-295](src/quest.pest#L289-L295) | Postfix operations (unlimited chaining) | MEDIUM |
| [src/main.rs:872-896](src/main.rs#L872-L896) | `eval_pair` depth tracking | MEDIUM |
| [src/main.rs:2748-2950](src/main.rs#L2748-L2950) | Postfix evaluation (method chains) | MEDIUM |
| [src/main.rs:3549](src/main.rs#L3549) | Function lookup (clones function) | CRITICAL |
| [src/function_call.rs:65](src/function_call.rs#L65) | Scope cloning in function calls | CRITICAL |
| [src/function_call.rs:7-23](src/function_call.rs#L7-L23) | `capture_current_scope` | CRITICAL |
| [src/scope.rs:220-227](src/scope.rs#L220-L227) | `Scope::get` (clones values) | CRITICAL |

---

## Appendix B: Recommended Reading

- QEP-048: Stack Depth Tracking ([specs/qep-048-stack-depth-tracking.md](specs/qep-048-stack-depth-tracking.md))
- Bug #019 Analysis: [bugs/019_stack_overflow_nested_module_method_calls/ANALYSIS2.md](bugs/019_stack_overflow_nested_module_method_calls/ANALYSIS2.md)
- Clone Trait Analysis: [docs/CLONE_TRAIT_ANALYSIS.md](docs/CLONE_TRAIT_ANALYSIS.md)
