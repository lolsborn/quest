# QEP-018: eval() Function for Dynamic Code Execution

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** sys.load_module(), REPL implementation

---

## Abstract

This QEP proposes adding an `eval()` function to Quest for dynamic code execution at runtime. Unlike `sys.load_module()` which loads and executes entire module files, `eval()` executes arbitrary Quest code strings within the current scope, enabling metaprogramming, testing, REPL-like workflows, and runtime code generation.

---

## Motivation

### Current Limitations

Quest currently supports loading external code only through `sys.load_module()`:

```quest
use "std/sys"

# Load entire module file
let my_module = sys.load_module("path/to/module.q")

# Can't execute arbitrary code strings
let code = "2 + 2"
# No way to evaluate this! ❌
```

**What you CAN'T do:**
1. Execute code strings at runtime
2. Test parse errors programmatically
3. Build REPLs or code playgrounds
4. Implement code generators or DSLs
5. Dynamically construct code based on runtime data
6. Meta-programming and code introspection

### Use Cases

#### 1. **Testing Framework - Error Testing**

Currently impossible to test that invalid code produces errors:

```quest
# Can't test this! No way to catch parse errors
test.it("rejects consecutive underscores", fun ()
    # Need eval() to test parse errors:
    test.assert_raises("ParseError", fun ()
        eval("let x = 1__000")  # Should fail
    end)
end)
```

#### 2. **REPL / Interactive Shell**

Build custom REPLs or code playgrounds:

```quest
# Simple REPL
while true
    let input = readline("> ")
    if input == "exit"
        break
    end

    try
        let result = eval(input)
        if result != nil
            puts(result)
        end
    catch e
        puts("Error: " .. e.message())
    end
end
```

#### 3. **Dynamic Code Generation**

Generate and execute code based on runtime data:

```quest
# Generate accessor methods dynamically
let fields = ["name", "age", "email"]

for field in fields
    # Generate getter
    let getter_code = "fun get_" .. field .. "() self." .. field .. " end"
    eval(getter_code)

    # Generate setter
    let setter_code = "fun set_" .. field .. "(val) self." .. field .. " = val end"
    eval(setter_code)
end
```

#### 4. **Configuration / DSL Evaluation**

Evaluate user-provided expressions safely:

```quest
# User config file with expressions
let config = {
    "max_retries": "3 * 5",
    "timeout": "60 * 1000",
    "enabled": "true"
}

# Evaluate expressions
for key, expr in config
    config[key] = eval(expr)
end
# max_retries = 15, timeout = 60000, enabled = true
```

#### 5. **Testing Parse Behavior**

Test grammar and parser edge cases:

```quest
# Test numeric literal parsing
test.it("parses scientific notation", fun ()
    let result = eval("1e10")
    test.assert_eq(result.cls(), "Float", nil)
    test.assert_eq(result, 10000000000.0, nil)
end)

test.it("rejects trailing underscores", fun ()
    test.assert_raises("ParseError", fun ()
        eval("100_")
    end)
end)
```

#### 6. **Templating / Code Templates**

Generate code from templates:

```quest
# Code template
let template = """
type {{TypeName}}
    {{Fields}}

    fun to_string()
        "{{TypeName}}(" .. {{FieldAccess}} .. ")"
    end
end
"""

# Fill in template
let code = template
    .replace("{{TypeName}}", "User")
    .replace("{{Fields}}", "str: name\nint: age")
    .replace("{{FieldAccess}}", "self.name .. ', ' .. self.age")

# Execute generated code
eval(code)

# Now User type exists!
let user = User.new(name: "Alice", age: 30)
```

---

## Design Philosophy

### Principle 1: Execute in Current Scope

Unlike modules which have isolated scope, `eval()` executes in the **caller's scope**:

```quest
let x = 10

# eval() sees and can modify caller's variables
eval("x = x + 5")
puts(x)  # 15

# Compare with module load (isolated scope):
sys.load_module("code.q")  # Can't see x
```

### Principle 2: Return Last Expression Value

`eval()` returns the value of the last expression:

```quest
let result = eval("2 + 2")  # Returns 4
let result = eval("let x = 5\nx * 2")  # Returns 10
let result = eval("puts('hi')")  # Returns nil (puts returns nil)
```

### Principle 3: Propagate Exceptions

Parse errors and runtime errors propagate to caller:

```quest
try
    eval("1__000")  # Parse error
catch e
    puts(e.exc_type())  # "ParseError"
end

try
    eval("undefined_var")  # Runtime error
catch e
    puts(e.exc_type())  # "NameError" or "Error"
end
```

### Principle 4: Security Through Isolation (No Special Privileges)

`eval()` code runs with **same permissions** as calling code:
- Can't access private module internals
- Can't bypass security checks
- Can't execute system commands (unless caller can)

---

## API Design

### Signature

```quest
eval(code: Str) → Any
```

**Parameters:**
- `code` (Str): Quest code to execute as string

**Returns:**
- Value of the last expression in the code
- `nil` if code is empty or ends with statement (not expression)

**Raises:**
- `ParseError`: If code has syntax errors
- Any exception raised by the executed code

### Examples

#### Basic Expressions

```quest
eval("2 + 2")           # → 4
eval("'hello'")         # → "hello"
eval("[1, 2, 3]")       # → [1, 2, 3]
eval("{'a': 1}")        # → {"a": 1}
```

#### Variable Access

```quest
let x = 10
eval("x * 2")           # → 20
eval("x = x + 5")       # Modifies x in caller scope
puts(x)                 # 15
```

#### Multiple Statements

```quest
let result = eval("""
    let a = 5
    let b = 10
    a + b
""")
puts(result)            # 15
```

#### Function Definitions

```quest
eval("fun double(x) x * 2 end")

# Function now exists in current scope
puts(double(5))         # 10
```

#### Type Definitions

```quest
eval("""
    type Point
        num: x
        num: y

        fun distance()
            math.sqrt(self.x * self.x + self.y * self.y)
        end
    end
""")

# Type now exists
let p = Point.new(x: 3, y: 4)
puts(p.distance())      # 5.0
```

---

## Comparison with sys.load_module()

| Feature | `eval(code)` | `sys.load_module(path)` |
|---------|--------------|-------------------------|
| **Input** | Code string | File path |
| **Scope** | Caller's scope | Isolated module scope |
| **Returns** | Last expression value | Module object |
| **Variables** | Can access/modify caller's vars | Can't access caller's vars |
| **Use Case** | Dynamic code, testing, REPL | Organize code, reusability |
| **Security** | Same as caller | Isolated from caller |
| **Performance** | Parse on every call | Parse once, cache |
| **File I/O** | No | Yes (reads from disk) |

### Example Comparison

```quest
# eval() - executes in current scope
let x = 10
eval("x = x + 5")
puts(x)  # 15 (modified)

# sys.load_module() - isolated scope
let x = 10
let mod = sys.load_module("code.q")  # code.q contains: x = x + 5
puts(x)  # Still 10 (not modified)
puts(mod.x)  # Module's x (if exported)
```

### When to Use Each

**Use `eval()`:**
- Testing parse errors
- Dynamic code generation
- REPL implementation
- Templating / DSLs
- Metaprogramming
- Quick calculations from user input

**Use `sys.load_module()`:**
- Loading libraries and modules
- Code organization (split code into files)
- Reusable components
- Plugin systems
- When scope isolation is desired

---

## Implementation Strategy

### Phase 1: Basic eval() in std/sys

**Location:** `src/modules/sys.rs`

**Implementation:**

```rust
// In call_sys_function()
"sys.eval" => {
    if args.len() != 1 {
        return Err(format!("sys.eval expects 1 argument, got {}", args.len()));
    }

    let code = match &args[0] {
        QValue::Str(s) => s.value.as_ref().clone(),
        _ => return Err("sys.eval: argument must be String".to_string()),
    };

    // Parse the code
    let pairs = QuestParser::parse(Rule::program, &code)
        .map_err(|e| format!("ParseError: {}", e))?;

    // Evaluate in current scope
    let mut result = QValue::Nil(QNil);
    for pair in pairs {
        if pair.as_rule() == Rule::program {
            for statement in pair.into_inner() {
                if statement.as_rule() != Rule::EOI {
                    result = eval_pair(statement, scope)?;
                }
            }
        }
    }

    Ok(result)
}
```

**Estimated Effort:** 1-2 hours

### Phase 2: Builtin eval() Function

**Location:** Add to builtin functions (main.rs)

**Implementation:**

```rust
// In builtin function handler
"eval" => {
    if args.len() != 1 {
        return Err(format!("eval expects 1 argument, got {}", args.len()));
    }

    let code = args[0].as_str();

    // Same parsing logic as Phase 1
    // But directly available as eval() instead of sys.eval()
}
```

**Benefits:**
- Shorter syntax: `eval("code")` vs `sys.eval("code")`
- More like other languages (Python, JavaScript, Ruby)

**Trade-off:**
- Adds to global namespace
- More "magic" (less explicit)

**Recommendation:** Start with `sys.eval()` (Phase 1), add builtin `eval()` (Phase 2) if users request it.

---

## Error Handling

### Parse Errors

```quest
try
    eval("let x =")  # Incomplete syntax
catch e
    puts(e.exc_type())    # "ParseError"
    puts(e.message())     # "Unexpected end of input"
    puts(e.line())        # 1
end
```

**Implementation:**
```rust
let pairs = QuestParser::parse(Rule::program, &code)
    .map_err(|e| {
        // Wrap pest error as ParseError exception
        create_parse_error(e)
    })?;
```

### Runtime Errors

```quest
try
    eval("undefined_variable")
catch e
    puts(e.exc_type())    # "Error" or "NameError"
    puts(e.message())     # "Undefined variable: undefined_variable"
end
```

**Implementation:**
```rust
// eval_pair() already propagates errors via Result<>
result = eval_pair(statement, scope)?;
```

### Empty Code

```quest
eval("")             # Returns nil
eval("   \n  ")      # Returns nil (only whitespace)
```

**Implementation:**
```rust
if code.trim().is_empty() {
    return Ok(QValue::Nil(QNil));
}
```

---

## Return Value Semantics

### Expression vs Statement

```quest
# Expression - returns value
eval("2 + 2")                # 4
eval("'hello'")              # "hello"
eval("[1, 2, 3]")            # [1, 2, 3]

# Statement - returns nil
eval("let x = 5")            # nil (assignment is statement)
eval("if true puts('hi') end")  # nil (if is statement)

# Multiple statements - returns last value
eval("let x = 5\nx + 10")    # 15 (last expression)
eval("let x = 5\nlet y = 10")  # nil (last is statement)
```

### Implementation Detail

```rust
// Track last result while evaluating
let mut result = QValue::Nil(QNil);
for statement in statements {
    result = eval_pair(statement, scope)?;
}
// Return last result
Ok(result)
```

---

## Security Considerations

### 1. No Additional Privileges

`eval()` code runs with **same permissions** as calling code:

```quest
# If caller can't access file system, eval() can't either
try
    eval("io.read('/etc/passwd')")  # Fails if caller lacks permission
catch e
    puts("Access denied")
end
```

### 2. No Sandbox (User Responsibility)

`eval()` is **not sandboxed**. User must validate input:

```quest
# ⚠️ DANGEROUS - eval untrusted input
let user_input = get_user_input()
eval(user_input)  # User could input "sys.exit(1)" or malicious code!

# ✅ SAFE - validate before eval
let user_input = get_user_input()
if user_input.match("^[0-9+\\-*/() ]+$")  # Only allow math expressions
    eval(user_input)
else
    puts("Invalid input")
end
```

### 3. Scope Visibility

`eval()` can see all variables in caller's scope:

```quest
let secret_token = "abc123"

# eval() can access it!
eval("puts(secret_token)")  # Prints: abc123

# Be careful with eval of untrusted code
eval(untrusted_code)  # Could exfiltrate secret_token
```

**Recommendation:**
- Document security risks clearly
- Provide examples of safe usage patterns
- Consider adding `safe_eval()` in future QEP with restricted scope

---

## Performance Considerations

### Parsing Overhead

**Problem:** `eval()` parses code every time it's called.

```quest
# This parses code 1000 times!
for i in 1 to 1000
    eval("2 + 2")
end
```

**Mitigation:**
1. **Don't use eval() in hot loops**
   ```quest
   # Bad
   for i in 1 to 1000
       eval("process(i)")
   end

   # Good
   for i in 1 to 1000
       process(i)
   end
   ```

2. **User can cache compiled code** (future enhancement)
   ```quest
   # Hypothetical future API
   let compiled = compile("2 + 2")
   for i in 1 to 1000
       compiled.eval()  # Skip parse phase
   end
   ```

### Performance Characteristics

| Operation | Cost | Notes |
|-----------|------|-------|
| Parse | O(n) | n = code length |
| Execute | O(m) | m = complexity |
| Scope lookup | O(1) | HashMap access |

**Typical Timing:**
- Parse: ~0.1-1ms for small code strings
- Execute: Depends on code
- Total: Acceptable for non-hot-path use

**Recommendation:** Document that `eval()` has parsing overhead, use sparingly in performance-critical code.

---

## Alternative Names Considered

| Name | Pros | Cons | Verdict |
|------|------|------|---------|
| `eval()` | Standard name (Python, JS, Ruby) | Short, might pollute namespace | ✅ **Chosen** |
| `sys.eval()` | Explicit, namespaced | More verbose | ✅ **Phase 1** |
| `execute()` | Clear intent | Not standard | ❌ |
| `run()` | Short | Ambiguous (run what?) | ❌ |
| `eval_code()` | Descriptive | Verbose | ❌ |

**Decision:** Use `sys.eval()` initially (Phase 1), add builtin `eval()` if requested (Phase 2).

---

## Edge Cases

### 1. Empty Code

```quest
eval("")           # nil
eval("  \n  ")     # nil (only whitespace)
```

### 2. Only Comments

```quest
eval("# Just a comment")  # nil
```

### 3. Syntax Errors

```quest
try
    eval("let x =")  # Incomplete
catch e
    puts(e.exc_type())  # "ParseError"
end
```

### 4. Undefined Variables

```quest
try
    eval("undefined_var")
catch e
    puts(e.exc_type())  # "Error"
    puts(e.message())   # "Undefined variable: undefined_var"
end
```

### 5. Nested eval()

```quest
eval("eval('2 + 2')")  # Returns 4 (nested eval works)
```

### 6. Multi-line Code

```quest
let result = eval("""
    let x = 5
    let y = 10
    x + y
""")
puts(result)  # 15
```

### 7. Return Statements

```quest
# eval() in function context
fun test()
    eval("return 42")  # Returns from test(), not eval()
end

puts(test())  # 42
```

**Note:** `return` in eval'd code affects enclosing function, not eval itself.

---

## Testing Strategy

### Unit Tests

```quest
# test/sys/eval_test.q
use "std/test"
use "std/sys"

test.module("sys.eval()")

test.describe("Basic expressions", fun ()
    test.it("evaluates arithmetic", fun ()
        test.assert_eq(sys.eval("2 + 2"), 4, nil)
        test.assert_eq(sys.eval("10 * 5"), 50, nil)
    end)

    test.it("evaluates strings", fun ()
        test.assert_eq(sys.eval("'hello'"), "hello", nil)
    end)

    test.it("evaluates arrays", fun ()
        let result = sys.eval("[1, 2, 3]")
        test.assert_eq(result.len(), 3, nil)
    end)
end)

test.describe("Variable access", fun ()
    test.it("reads caller variables", fun ()
        let x = 10
        test.assert_eq(sys.eval("x * 2"), 20, nil)
    end)

    test.it("modifies caller variables", fun ()
        let x = 10
        sys.eval("x = x + 5")
        test.assert_eq(x, 15, nil)
    end)

    test.it("creates new variables", fun ()
        sys.eval("let new_var = 42")
        test.assert_eq(new_var, 42, nil)
    end)
end)

test.describe("Error handling", fun ()
    test.it("raises ParseError on syntax error", fun ()
        test.assert_raises("ParseError", fun ()
            sys.eval("let x =")
        end)
    end)

    test.it("raises Error on undefined variable", fun ()
        test.assert_raises("Error", fun ()
            sys.eval("undefined_variable")
        end)
    end)
end)

test.describe("Return values", fun ()
    test.it("returns last expression", fun ()
        test.assert_eq(sys.eval("let x = 5\nx + 10"), 15, nil)
    end)

    test.it("returns nil for statements", fun ()
        test.assert_eq(sys.eval("let x = 5"), nil, nil)
    end)

    test.it("returns nil for empty code", fun ()
        test.assert_eq(sys.eval(""), nil, nil)
    end)
end)

test.describe("Complex code", fun ()
    test.it("evaluates function definitions", fun ()
        sys.eval("fun test_fn(x) x * 2 end")
        test.assert_eq(test_fn(5), 10, nil)
    end)

    test.it("evaluates type definitions", fun ()
        sys.eval("type TestType num: x end")
        let obj = TestType.new(x: 42)
        test.assert_eq(obj.x, 42, nil)
    end)
end)
```

### Integration Tests

```quest
# test/sys/eval_integration_test.q

test.describe("eval() use cases", fun ()
    test.it("can test parse errors", fun ()
        # This is why we need eval()!
        test.assert_raises("ParseError", fun ()
            sys.eval("1__000")
        end)
    end)

    test.it("can build simple REPL", fun ()
        let commands = ["2 + 2", "let x = 5", "x * 3"]
        let results = []

        for cmd in commands
            let result = sys.eval(cmd)
            results.push(result)
        end

        test.assert_eq(results[0], 4, nil)
        test.assert_eq(results[1], nil, nil)
        test.assert_eq(results[2], 15, nil)
    end)
end)
```

---

## Documentation

### User Guide Section

```markdown
## Dynamic Code Execution with eval()

Quest provides `sys.eval()` for executing code strings at runtime.

### Basic Usage

```quest
use "std/sys"

# Evaluate expressions
let result = sys.eval("2 + 2")  # 4

# Access caller's variables
let x = 10
sys.eval("x = x + 5")
puts(x)  # 15
```

### Use Cases

**Testing Parse Errors:**
```quest
test.assert_raises("ParseError", fun ()
    sys.eval("invalid syntax")
end)
```

**Dynamic Code Generation:**
```quest
for field in ["name", "age", "email"]
    sys.eval("fun get_" .. field .. "() self." .. field .. " end")
end
```

**Simple REPL:**
```quest
while true
    let input = readline("> ")
    try
        puts(sys.eval(input))
    catch e
        puts("Error: " .. e.message())
    end
end
```

### Security Warning

⚠️ **Never eval() untrusted user input without validation!**

```quest
# DANGEROUS - user could input malicious code
sys.eval(user_input)

# SAFE - validate input first
if input.match("^[0-9+\\-*/() ]+$")
    sys.eval(input)
else
    puts("Invalid input")
end
```

### Comparison with sys.load_module()

| Feature | eval() | load_module() |
|---------|--------|---------------|
| Input | Code string | File path |
| Scope | Caller's scope | Isolated |
| Use | Dynamic code | Code organization |
```

---

## Implementation Checklist

### Phase 1: sys.eval() (Namespaced)
- [ ] Add `sys.eval()` to sys module
- [ ] Parse code string with Pest parser
- [ ] Execute in caller's scope
- [ ] Return last expression value
- [ ] Propagate ParseError for syntax errors
- [ ] Propagate runtime errors
- [ ] Handle empty/whitespace-only code
- [ ] Write 20+ unit tests
- [ ] Document in user guide
- [ ] Add examples

### Phase 2: Builtin eval() (Optional)
- [ ] Add `eval()` to builtin functions
- [ ] Same implementation as sys.eval()
- [ ] Update documentation
- [ ] Update tests

### Phase 3: Enhancements (Future)
- [ ] `compile()` for caching parsed code
- [ ] `safe_eval()` with restricted scope
- [ ] Performance profiling
- [ ] Benchmark vs load_module()

---

## Examples

### Example 1: Testing Framework (Parse Errors)

```quest
use "std/test"
use "std/sys"

test.describe("Numeric literal validation", fun ()
    test.it("rejects consecutive underscores", fun ()
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 1__000")
        end)
    end)

    test.it("rejects trailing underscores", fun ()
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 100_")
        end)
    end)

    test.it("accepts valid underscores", fun ()
        let x = sys.eval("1_000")
        test.assert_eq(x, 1000, nil)
    end)
end)
```

### Example 2: Simple REPL

```quest
use "std/sys"

puts("Quest REPL - Type 'exit' to quit")

let context = {}  # Could track variables if needed

while true
    let input = readline("> ")

    if input.trim() == "exit"
        break
    end

    if input.trim() == ""
        # Skip empty lines
    else
        try
            let result = sys.eval(input)
            if result != nil
                puts(result._rep())
            end
        catch e
            puts(term.red("Error: " .. e.message()))
        end
    end
end
```

### Example 3: Configuration Expression Evaluation

```quest
use "std/sys"

# Config with expressions
let config = {
    "port": "8000 + 80",
    "workers": "4 * 2",
    "timeout": "30 * 1000",
    "debug": "true",
    "max_connections": "100"
}

# Evaluate all expressions
for key in config.keys()
    try
        config[key] = sys.eval(config[key])
    catch e
        puts("Invalid config value for " .. key .. ": " .. config[key])
    end
end

puts("Port: " .. config["port"])          # 8080
puts("Workers: " .. config["workers"])    # 8
puts("Timeout: " .. config["timeout"])    # 30000
```

### Example 4: Dynamic Method Generation

```quest
use "std/sys"

type User
    str: name
    int: age
    str: email
end

# Generate getter methods dynamically
let fields = ["name", "age", "email"]

for field in fields
    let code = """
        type User
            fun get_""" .. field .. """()
                self.""" .. field .. """
            end
        end
    """
    sys.eval(code)
end

# Now getters exist!
let user = User.new(name: "Alice", age: 30, email: "alice@example.com")
puts(user.get_name())   # "Alice"
puts(user.get_age())    # 30
puts(user.get_email())  # "alice@example.com"
```

### Example 5: Template-Based Code Generation

```quest
use "std/sys"

fun generate_crud_type(type_name, fields)
    let field_defs = []
    for field in fields
        field_defs.push(field["type"] .. ": " .. field["name"])
    end

    let code = """
        type """ .. type_name .. """
            """ .. field_defs.join("\n    ") .. """

            fun to_string()
                "``` .. type_name .. ```("
    """

    # Add field access to to_string
    let field_access = []
    for field in fields
        field_access.push("self." .. field["name"])
    end
    code = code .. " .. " .. field_access.join(" .. ', ' .. ")
    code = code .. """ .. ")"
            end
        end
    """

    sys.eval(code)
end

# Generate User type
generate_crud_type("User", [
    {"type": "str", "name": "username"},
    {"type": "str", "name": "email"},
    {"type": "int", "name": "age"}
])

# Use generated type
let user = User.new(username: "bob", email: "bob@example.com", age: 25)
puts(user.to_string())  # "User(bob, bob@example.com, 25)"
```

---

## Alternatives Considered

### 1. Lambda-Based Evaluation

```quest
# Instead of eval(code_string), use lambdas
let code = fun () 2 + 2 end
code()  # 4
```

**Rejected:** Doesn't solve parse error testing or dynamic code generation.

### 2. Compile-Then-Execute API

```quest
let compiled = sys.compile("2 + 2")
compiled.execute()  # 4
compiled.execute()  # 4 (no re-parse)
```

**Deferred:** Good optimization, but add in Phase 3 after basic eval() works.

### 3. Sandboxed Evaluation

```quest
sys.safe_eval(code, {allowed_vars: ["x", "y"]})
```

**Deferred:** Security feature, add in future QEP if needed.

---

## Migration Path

**Immediate (QEP-018):**
- Add `sys.eval(code)` to sys module
- Document use cases and security
- Provide examples

**Future (QEP-019?):**
- Add builtin `eval()` if requested
- Add `sys.compile()` for performance
- Add `sys.safe_eval()` for sandboxing

---

## Open Questions

1. **Should eval() be builtin or sys.eval()?**
   - **Proposed:** Start with `sys.eval()`, add builtin later if needed
   - **Rationale:** More explicit, less namespace pollution

2. **Should eval() see private module internals?**
   - **Proposed:** No - respects same visibility rules as caller
   - **Rationale:** Maintains encapsulation

3. **Should we support eval() with custom scope dict?**
   ```quest
   sys.eval("x + y", {"x": 10, "y": 20})  # 30
   ```
   - **Proposed:** Not in initial version
   - **Rationale:** Adds complexity, can add later

4. **Should return statements in eval() work?**
   ```quest
   fun test()
       sys.eval("return 42")  # Return from test() or eval()?
   end
   ```
   - **Proposed:** Return from enclosing function (like Python)
   - **Rationale:** Most intuitive behavior

---

## Performance Benchmarks (Estimated)

| Operation | Time | Notes |
|-----------|------|-------|
| `eval("2 + 2")` | ~0.1ms | Simple expression |
| `eval("let x = 5\nx + 10")` | ~0.2ms | Multiple statements |
| `eval(large_code)` | ~1-10ms | Depends on size |
| `sys.load_module(path)` | ~5-50ms | Includes file I/O |

**Conclusion:** eval() is fast enough for non-hot-path use cases.

---

## References

- Python `eval()`: https://docs.python.org/3/library/functions.html#eval
- JavaScript `eval()`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval
- Ruby `eval()`: https://ruby-doc.org/core-3.0.0/Kernel.html#method-i-eval
- Lua `loadstring()`: https://www.lua.org/manual/5.1/manual.html#pdf-loadstring

---

## Conclusion

The `eval()` function fills a critical gap in Quest's metaprogramming capabilities. While `sys.load_module()` handles code organization and reusability, `eval()` enables:
- Testing parse errors
- Building REPLs
- Dynamic code generation
- Template systems
- Configuration evaluation

**Implementation is straightforward** (~1-2 hours) and leverages existing parser infrastructure. Security is maintained through same-permissions model (no special privileges for eval'd code).

**Recommendation:** Implement as `sys.eval()` in Phase 1, with optional builtin `eval()` in Phase 2 based on user feedback.

---

## Status

- [ ] Grammar changes (none needed)
- [ ] Implementation (sys.eval() in sys module)
- [ ] Unit tests (20+ tests)
- [ ] Integration tests
- [ ] Documentation (user guide + examples)
- [ ] Security guide
- [ ] Performance benchmarks
- [ ] Examples (REPL, testing, code gen)

**Estimated Total Effort:** 4-6 hours (implementation + tests + docs)
