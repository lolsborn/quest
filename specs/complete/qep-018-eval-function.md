# QEP-018: sys.eval() Function for Dynamic Code Execution

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** sys.load_module(), REPL implementation

---

## Abstract

This QEP proposes adding `sys.eval()` to Quest for dynamic code execution at runtime. Unlike `sys.load_module()` which loads and executes entire module files, `sys.eval()` executes arbitrary Quest code strings within the current scope, enabling metaprogramming, testing, REPL-like workflows, and runtime code generation. The function is namespaced under the `std/sys` module to maintain a clean global namespace.

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
use "std/sys"

# Can't test this! No way to catch parse errors
test.it("rejects consecutive underscores", fun ()
    # Need sys.eval() to test parse errors:
    test.assert_raises("ParseError", fun ()
        sys.eval("let x = 1__000")  # Should fail
    end)
end)
```

#### 2. **REPL / Interactive Shell**

Build custom REPLs or code playgrounds:

```quest
use "std/sys"

# Simple REPL
while true
    let input = readline("> ")
    if input == "exit"
        break
    end

    try
        let result = sys.eval(input)
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
use "std/sys"

# Generate accessor methods dynamically
let fields = ["name", "age", "email"]

for field in fields
    # Generate getter
    let getter_code = "fun get_" .. field .. "() self." .. field .. " end"
    sys.eval(getter_code)

    # Generate setter
    let setter_code = "fun set_" .. field .. "(val) self." .. field .. " = val end"
    sys.eval(setter_code)
end
```

#### 4. **Configuration / DSL Evaluation**

Evaluate user-provided expressions safely:

```quest
use "std/sys"

# User config file with expressions
let config = {
    "max_retries": "3 * 5",
    "timeout": "60 * 1000",
    "enabled": "true"
}

# Evaluate expressions
for key, expr in config
    config[key] = sys.eval(expr)
end
# max_retries = 15, timeout = 60000, enabled = true
```

#### 5. **Testing Parse Behavior**

Test grammar and parser edge cases:

```quest
use "std/sys"

# Test numeric literal parsing
test.it("parses scientific notation", fun ()
    let result = sys.eval("1e10")
    test.assert_eq(result.cls(), "Float", nil)
    test.assert_eq(result, 10000000000.0)end)

test.it("rejects trailing underscores", fun ()
    test.assert_raises("ParseError", fun ()
        sys.eval("100_")
    end)
end)
```

#### 6. **Templating / Code Templates**

Generate code from templates:

```quest
use "std/sys"

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
sys.eval(code)

# Now User type exists!
let user = User.new(name: "Alice", age: 30)
```

---

## Design Philosophy

### Principle 1: Execute in Current Scope

Unlike modules which have isolated scope, `sys.eval()` executes in the **caller's scope**:

```quest
use "std/sys"

let x = 10

# sys.eval() sees and can modify caller's variables
sys.eval("x = x + 5")
puts(x)  # 15

# Compare with module load (isolated scope):
sys.load_module("code.q")  # Can't see x
```

### Principle 2: Return Last Expression Value

`sys.eval()` returns the value of the last expression:

```quest
use "std/sys"

let result = sys.eval("2 + 2")  # Returns 4
let result = sys.eval("let x = 5\nx * 2")  # Returns 10
let result = sys.eval("puts('hi')")  # Returns nil (puts returns nil)
```

### Principle 3: Propagate Exceptions

Parse errors and runtime errors propagate to caller:

```quest
use "std/sys"

try
    sys.eval("1__000")  # Parse error
catch e
    puts(e.type())  # "ParseError"
end

try
    sys.eval("undefined_var")  # Runtime error
catch e
    puts(e.type())  # "NameError" or "Error"
end
```

### Principle 4: Security Through Isolation (No Special Privileges)

`sys.eval()` code runs with **same permissions** as calling code:
- Can't access private module internals
- Can't bypass security checks
- Can't execute system commands (unless caller can)

---

## API Design

### Signature

```quest
use "std/sys"

sys.eval(code: Str) → Any
```

**Parameters:**
- `code` (Str): Quest code to execute as string

**Returns:**
- Value of the last expression in the code
- `nil` if code is empty or ends with statement (not expression)

**Raises:**
- `ParseError`: If code has syntax errors
- Any exception raised by the executed code

**Module:** `std/sys` (must be imported with `use "std/sys"`)

### Examples

#### Basic Expressions

```quest
use "std/sys"

sys.eval("2 + 2")           # → 4
sys.eval("'hello'")         # → "hello"
sys.eval("[1, 2, 3]")       # → [1, 2, 3]
sys.eval("{'a': 1}")        # → {"a": 1}
```

#### Variable Access

```quest
use "std/sys"

let x = 10
sys.eval("x * 2")           # → 20
sys.eval("x = x + 5")       # Modifies x in caller scope
puts(x)                     # 15
```

#### Multiple Statements

```quest
use "std/sys"

let result = sys.eval("""
    let a = 5
    let b = 10
    a + b
""")
puts(result)            # 15
```

#### Function Definitions

```quest
use "std/sys"

sys.eval("fun double(x) x * 2 end")

# Function now exists in current scope
puts(double(5))         # 10
```

#### Type Definitions

```quest
use "std/sys"

sys.eval("""
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

| Feature | `sys.eval(code)` | `sys.load_module(path)` |
|---------|------------------|-------------------------|
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
use "std/sys"

# sys.eval() - executes in current scope
let x = 10
sys.eval("x = x + 5")
puts(x)  # 15 (modified)

# sys.load_module() - isolated scope
let x = 10
let mod = sys.load_module("code.q")  # code.q contains: x = x + 5
puts(x)  # Still 10 (not modified)
puts(mod.x)  # Module's x (if exported)
```

### When to Use Each

**Use `sys.eval()`:**
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

### Implementation: sys.eval() in std/sys module

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

    // Evaluate in caller's scope (scope parameter is passed from caller)
    // This allows eval'd code to access and modify caller's variables
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

**Benefits:**
- Namespaced under `std/sys` (keeps global namespace clean)
- Explicit usage with `use "std/sys"` import
- Consistent with Quest's module policy (all stdlib requires prefixes)
- Clear that this is a system-level function

**Estimated Effort:** 1-2 hours

---

## Error Handling

### Parse Errors

```quest
use "std/sys"

try
    sys.eval("let x =")  # Incomplete syntax
catch e
    puts(e.type())    # "ParseError" or "Error"
    puts(e.message())     # "ParseError: Unexpected end of input"
end
```

**Implementation:**
```rust
let pairs = QuestParser::parse(Rule::program, &code)
    .map_err(|e| {
        // Convert Pest parse error to Quest error string
        // Format: "ParseError: <description>"
        // Note: Quest currently uses string errors, not typed exceptions
        format!("ParseError: {}", e)
    })?;
```

**Note**: Quest's error system currently uses string messages. The `ParseError:` prefix allows catching parse errors vs runtime errors. Future QEP could add typed exception hierarchy.

### Runtime Errors

```quest
use "std/sys"

try
    sys.eval("undefined_variable")
catch e
    puts(e.type())    # "Error" or "NameError"
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
use "std/sys"

sys.eval("")             # Returns nil
sys.eval("   \n  ")      # Returns nil (only whitespace)
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
use "std/sys"

# Expression - returns value
sys.eval("2 + 2")                # 4
sys.eval("'hello'")              # "hello"
sys.eval("[1, 2, 3]")            # [1, 2, 3]

# Statement - returns nil
sys.eval("let x = 5")            # nil (assignment is statement)
sys.eval("if true puts('hi') end")  # nil (if is statement)

# Multiple statements - returns last value
sys.eval("let x = 5\nx + 10")    # 15 (last expression)
sys.eval("let x = 5\nlet y = 10")  # nil (last is statement)
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

`sys.eval()` code runs with **same permissions** as calling code:

```quest
use "std/sys"

# If caller can't access file system, eval() can't either
try
    sys.eval("io.read('/etc/passwd')")  # Fails if caller lacks permission
catch e
    puts("Access denied")
end
```

### 2. No Sandbox (User Responsibility)

`sys.eval()` is **not sandboxed**. User must validate input:

```quest
use "std/sys"
use "std/regex"

# ⚠️ DANGEROUS - eval untrusted input
let user_input = get_user_input()
sys.eval(user_input)  # User could input "sys.exit(1)" or malicious code!

# ✅ BETTER - validate before eval
let user_input = get_user_input()
# Only allow math expressions: digits, operators, parens, spaces
if regex.match(r"^[0-9+\-*/() \t]+$", user_input)
    sys.eval(user_input)
else
    puts("Invalid input")
end

# ✅ BEST - Add length limit to prevent DoS
if user_input.len() > 100
    puts("Input too long")
elif regex.match(r"^[0-9+\-*/() \t]+$", user_input)
    sys.eval(user_input)
else
    puts("Invalid input")
end
```

### 3. Scope Visibility

`sys.eval()` can see all variables in caller's scope:

```quest
use "std/sys"

let secret_token = "abc123"

# sys.eval() can access it!
sys.eval("puts(secret_token)")  # Prints: abc123

# Be careful with eval of untrusted code
sys.eval(untrusted_code)  # Could exfiltrate secret_token
```

### 4. Resource Exhaustion

`sys.eval()` has **no built-in limits** on execution time or memory:

```quest
use "std/sys"

# No protection against:
sys.eval("9999999999999999999999 * 9999999999999999999999")  # Memory exhaustion
sys.eval("while true end")  # Infinite loop
sys.eval("((((((((((((1+1))))))))))))")  # Deep recursion
```

**Mitigation Strategies:**
- **Timeout wrapper**: Run eval in separate thread with timeout
- **Resource limits**: Set OS-level limits (ulimit, cgroups)
- **Process isolation**: Run untrusted eval in separate process
- **Input validation**: Restrict allowed syntax (whitelist approach)
- **Syntax limits**: Reject code over certain length or nesting depth

**Recommendation:**
- Document security risks clearly
- Provide examples of safe usage patterns
- Never eval untrusted input without validation and resource limits
- Consider adding `safe_eval()` in future QEP with restricted scope and timeouts

---

## Performance Considerations

### Parsing Overhead

**Problem:** `sys.eval()` parses code every time it's called.

```quest
use "std/sys"

# This parses code 1000 times!
for i in 1 to 1000
    sys.eval("2 + 2")
end
```

**Mitigation:**
1. **Don't use sys.eval() in hot loops**
   ```quest
   use "std/sys"

   # Bad
   for i in 1 to 1000
       sys.eval("process(i)")
   end

   # Good
   for i in 1 to 1000
       process(i)
   end
   ```

2. **User can cache compiled code** (future enhancement)
   ```quest
   use "std/sys"

   # Hypothetical future API
   let compiled = sys.compile("2 + 2")
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

**Concurrency:**
- Parser is thread-safe (Pest is stateless)
- Multiple concurrent `sys.eval()` calls are safe
- Each eval gets its own parse tree
- No synchronization required

**Recommendation:** Document that `eval()` has parsing overhead, use sparingly in performance-critical code.

---

## Alternative Names Considered

| Name | Pros | Cons | Verdict |
|------|------|------|---------|
| `sys.eval()` | Explicit, namespaced, consistent with module policy | More verbose than bare `eval()` | ✅ **Chosen** |
| `eval()` | Standard name (Python, JS, Ruby), shorter | Pollutes global namespace | ❌ Rejected |
| `sys.execute()` | Clear intent | Not standard | ❌ |
| `sys.run()` | Short | Ambiguous (run what?) | ❌ |
| `sys.eval_code()` | Descriptive | Too verbose | ❌ |

**Decision:** Use `sys.eval()` exclusively. Keeps global namespace clean and aligns with Quest's module philosophy where all stdlib functions require module prefixes.

---

## Edge Cases

### 1. Empty Code

```quest
use "std/sys"

sys.eval("")           # nil
sys.eval("  \n  ")     # nil (only whitespace)
```

### 2. Only Comments

```quest
use "std/sys"

sys.eval("# Just a comment")  # nil
```

### 3. Syntax Errors

```quest
use "std/sys"

try
    sys.eval("let x =")  # Incomplete
catch e
    puts(e.type())  # "ParseError"
end
```

### 4. Undefined Variables

```quest
use "std/sys"

try
    sys.eval("undefined_var")
catch e
    puts(e.type())  # "Error"
    puts(e.message())   # "Undefined variable: undefined_var"
end
```

### 5. Nested eval()

```quest
use "std/sys"

sys.eval("sys.eval('2 + 2')")  # Returns 4 (nested eval works)
```

### 6. Multi-line Code

```quest
use "std/sys"

let result = sys.eval("""
    let x = 5
    let y = 10
    x + y
""")
puts(result)  # 15
```

### 7. Return Statements

```quest
use "std/sys"

# sys.eval() in function context
fun test()
    sys.eval("return 42")  # Returns from test(), not eval()
end

puts(test())  # 42
```

**Note:** `return` in eval'd code affects enclosing function, not eval itself. This matches Python's behavior.

### 8. Module Imports in eval'd Code

```quest
use "std/sys"
use "std/io"

let x = 10

# eval'd code sees all caller's variables, including imported modules
sys.eval("puts(x)")           # ✅ Works - x is in scope
sys.eval("io.read('file')")   # ✅ Works - io is in scope
sys.eval("math.pi")           # ❌ Error - math not imported by caller

# eval'd code CANNOT use 'use' statements (would affect caller's scope unexpectedly)
sys.eval("use 'std/math'")    # ❌ ParseError or runtime error
```

**Rules:**
- eval'd code sees **all** variables from caller's scope
- This includes imported modules (e.g., `sys`, `io`, etc.)
- eval'd code **cannot** use `use` statements
- To use a module in eval'd code, caller must import it first

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
        test.assert_eq(x, 15)    end)

    test.it("creates new variables", fun ()
        sys.eval("let new_var = 42")
        test.assert_eq(new_var, 42)    end)
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

    test.it("return exits enclosing function", fun ()
        fun outer()
            sys.eval("return 42")
            return 99  # Never reached
        end
        test.assert_eq(outer(), 42, nil)
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
        test.assert_eq(obj.x, 42)    end)
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

        test.assert_eq(results[0], 4)        test.assert_eq(results[1], nil)        test.assert_eq(results[2], 15)    end)
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

### Implementation Tasks
- [ ] Add `sys.eval()` to sys module (`src/modules/sys.rs`)
- [ ] Parse code string with Pest parser
- [ ] Execute in caller's scope (pass scope parameter to eval_pair)
- [ ] Return last expression value
- [ ] Map Pest parse errors to Quest error strings with "ParseError:" prefix
- [ ] Include eval'd code source snippet in parse error messages
- [ ] Show line numbers relative to eval'd string in errors (not file line numbers)
- [ ] Propagate runtime errors from eval'd code
- [ ] Handle empty/whitespace-only code (return nil)
- [ ] Test return statement behavior in eval'd code
- [ ] Test module import visibility (eval sees caller's imports)
- [ ] Write 25+ unit tests (`test/sys/eval_test.q`)
- [ ] Document in user guide (`docs/`)
- [ ] Document security risks (resource exhaustion, untrusted input)
- [ ] Add examples to QEP and docs
- [ ] Update CLAUDE.md with sys.eval() reference

### Future Enhancements (Post-QEP-018)
- [ ] **QEP-018b**: `sys.eval(code, scope: dict?, timeout: num?)` with custom scope and timeout
- [ ] **QEP-018c**: `sys.compile()` for caching parsed code (performance optimization)
- [ ] **QEP-018d**: `sys.safe_eval()` wrapper combining scope isolation + timeout + resource limits
- [ ] Performance profiling and benchmarking vs sys.load_module()
- [ ] Typed exception hierarchy (ParseError, NameError, etc.) instead of string errors

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
        test.assert_eq(x, 1000)    end)
end)
```

### Example 2: Simple REPL

```quest
use "std/sys"
use "std/io"
use "std/term"

puts("Quest REPL - Type 'exit' to quit")

let context = {}  # Could track variables if needed

while true
    # Note: io.readline or custom readline function needed
    let input = io.read_line("> ")

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
            puts(term.red("Error: " .. e))
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
use "std/sys"

let compiled = sys.compile("2 + 2")
compiled.execute()  # 4
compiled.execute()  # 4 (no re-parse)
```

**Deferred:** Good optimization, but add in future after basic sys.eval() works.

### 3. Sandboxed Evaluation

```quest
use "std/sys"

sys.safe_eval(code, {allowed_vars: ["x", "y"]})
```

**Deferred:** Security feature, add in future QEP if needed.

---

## Migration Path

**QEP-018 (This Proposal):**
- Add `sys.eval(code)` to sys module
- Document use cases and security
- Provide comprehensive examples
- Write extensive tests

**Future Enhancements (Later QEPs):**
- Add `sys.compile()` for performance (caching parsed code)
- Add `sys.safe_eval()` for sandboxing (restricted scope)

---

## Open Questions

1. **Should sys.eval() see private module internals?**
   - **Proposed:** No - respects same visibility rules as caller
   - **Rationale:** Maintains encapsulation

2. **Should we support sys.eval() with custom scope dict?**
   ```quest
   use "std/sys"
   sys.eval("x + y", {"x": 10, "y": 20})  # 30
   ```
   - **Decision:** **Deferred to QEP-018b** (future enhancement)
   - **Rationale:**
     - Adds implementation complexity (requires scope merging/isolation)
     - Current version covers primary use cases (testing, REPL, code generation)
     - Custom scope enables safer evaluation (prevents access to caller's secrets)
     - Should be designed alongside timeout/resource limits for complete sandbox
   - **Future QEP-018b scope:**
     - `sys.eval(code, scope: dict?, timeout: num?)`
     - Isolated scope with only provided variables
     - Optional timeout for resource control
     - Basis for `sys.safe_eval()` implementation

3. **Should return statements in sys.eval() work?**
   ```quest
   use "std/sys"
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
| `sys.eval("2 + 2")` | ~0.1ms | Simple expression |
| `sys.eval("let x = 5\nx + 10")` | ~0.2ms | Multiple statements |
| `sys.eval(large_code)` | ~1-10ms | Depends on size |
| `sys.load_module(path)` | ~5-50ms | Includes file I/O |

**Conclusion:** sys.eval() is fast enough for non-hot-path use cases.

---

## References

- Python `eval()`: https://docs.python.org/3/library/functions.html#eval
- JavaScript `eval()`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval
- Ruby `eval()`: https://ruby-doc.org/core-3.0.0/Kernel.html#method-i-eval
- Lua `loadstring()`: https://www.lua.org/manual/5.1/manual.html#pdf-loadstring

---

## Conclusion

The `sys.eval()` function fills a critical gap in Quest's metaprogramming capabilities. While `sys.load_module()` handles code organization and reusability, `sys.eval()` enables:
- Testing parse errors
- Building REPLs
- Dynamic code generation
- Template systems
- Configuration evaluation

**Implementation is straightforward** (~1-2 hours) and leverages existing parser infrastructure. Security is maintained through same-permissions model (no special privileges for eval'd code).

**Recommendation:** Implement as `sys.eval()` exclusively, maintaining consistency with Quest's module namespace policy where all standard library functions require module prefixes.

---

## Status

- [ ] Grammar changes (none needed - uses existing parser)
- [ ] Implementation (sys.eval() in `src/modules/sys.rs`)
  - [ ] Parse code with Pest
  - [ ] Execute in caller's scope
  - [ ] Return last expression value
  - [ ] Format parse errors with "ParseError:" prefix
  - [ ] Include source context in error messages
- [ ] Unit tests (25+ tests in `test/sys/eval_test.q`)
  - [ ] Basic expressions
  - [ ] Variable access and modification
  - [ ] Parse error handling
  - [ ] Runtime error handling
  - [ ] Return statement behavior
  - [ ] Module import visibility
  - [ ] Empty/whitespace code
  - [ ] Nested eval
- [ ] Integration tests (parse error testing, REPL examples)
- [ ] Documentation (user guide + examples)
- [ ] Security documentation (resource exhaustion, input validation, length limits)
- [ ] Performance benchmarks (including concurrency tests)
- [ ] Examples (REPL, testing, code gen, templating)
- [ ] Update CLAUDE.md with sys.eval() reference

**Estimated Total Effort:** 5-7 hours (implementation + tests + docs + security review)

**Implementation Note:** Function is namespaced as `sys.eval()` (requires `use "std/sys"`), consistent with Quest's module policy.

**Future Work:** QEP-018b for custom scope and timeout support (enables safe sandboxed eval).
