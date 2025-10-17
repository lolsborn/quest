---
Number: QEP-057
Title: Enhanced Error Diagnostics and Location Context
Author: Claude Code
Status: Draft
Created: 2025-10-16
---

# QEP-057: Enhanced Error Diagnostics and Location Context

## Overview

This QEP proposes comprehensive enhancements to Quest's error reporting system, including magic variables for location context (`__file__`, `__line__`, `__function__`), automatic stack trace generation, rich error formatting with source code snippets, and developer-friendly diagnostic tools. These improvements will dramatically enhance the debugging experience as Quest projects scale.

## Status

**Draft** - Design phase for Quest 1.0

## Goals

### Primary Goals
1. Add magic variables for compile-time location context (`__file__`, `__line__`, `__function__`)
2. Automatic capture of call stack information in all exceptions
3. Rich error formatting with source code snippets (Rust-style)
4. Enhanced stack traces with argument values and local variables
5. Debug mode with detailed execution tracing
6. Integration with IDEs and external debugging tools

### Secondary Goals
7. Performance profiling integration (identify hot spots via error locations)
8. Error aggregation and grouping (de-duplicate similar errors)
9. Structured logging with location metadata
10. Source maps for compiled/minified code

## Motivation

### Current State: Good Error Messages, Limited Context

Quest's current error system (QEP-037) provides:
- ✅ Typed exceptions with hierarchical matching
- ✅ Clear error messages
- ✅ Basic stack traces

**Example current error**:
```
ConfigurationErr: No schema registered for module: my.module
  at lib/std/conf.q:153
```

This tells you **what** went wrong, but not always **where** in your code you triggered it.

### Problem: Debugging Large Codebases

As Quest projects grow, error location becomes critical:

**Scenario 1: Multiple call sites**
```quest
# app/server.q
let config = conf.get_config("app.server")  # Which one failed?

# app/database.q
let config = conf.get_config("app.database")  # This one?

# app/cache.q
let config = conf.get_config("app.cache")  # Or this one?
```

**Current error**:
```
ConfigurationErr: No schema registered for module: app.cache
```

**Question**: Which file called `get_config()`? You have to grep the codebase.

**Desired error**:
```
ConfigurationErr: No schema registered for module: app.cache
  at app/cache.q:45 in init_cache()
  called from app/main.q:12 in main()
```

**Scenario 2: Nested function calls**
```quest
fun process_request(request)
    let user = authenticate(request)
    let data = fetch_data(user)
    let result = transform(data)  # Fails deep inside
    return result
end
```

**Current error**:
```
TypeErr: Expected int, got str
  at lib/transform.q:78
```

**Question**: What was the call chain? What were the argument values?

**Desired error**:
```
TypeErr: Expected int, got str
  at lib/transform.q:78 in _validate_input()
    value: "not_a_number"
  called from lib/transform.q:45 in transform()
    data: {id: 42, count: "not_a_number", ...}
  called from app/handler.q:23 in process_request()
    request: Request{method: "POST", path: "/api/data"}
  called from app/main.q:67 in handle_request()
```

### Problem: Production Debugging

In production, you often only have logs. Current logs lack context:

**Current log entry**:
```
2025-10-16 14:32:15 ERROR IndexErr: Array index out of range: 10
```

**Questions**:
- Which file/function?
- What was the array size?
- What code path led here?
- Is this a recurring issue or one-off?

**Desired log entry**:
```
2025-10-16 14:32:15 ERROR IndexErr: Array index out of range: 10
  at app/processor.q:156 in process_batch()
  array size: 5, requested index: 10
  call_id: req_abc123
  user_id: user_456
  stack:
    app/processor.q:156 in process_batch()
    app/worker.q:89 in process_job()
    app/queue.q:45 in consume()
```

### Comparison with Other Languages

#### Python
```python
# Python provides excellent error context
def process():
    data = fetch_data()
    return data[10]  # IndexError

# Error output:
# Traceback (most recent call last):
#   File "app.py", line 23, in <module>
#     process()
#   File "app.py", line 15, in process
#     return data[10]
# IndexError: list index out of range
```

#### Rust
```rust
// Rust shows source code snippets
fn process() -> Result<i32, Error> {
    let data = vec![1, 2, 3];
    Ok(data[10])
}

// Error output:
// error: index out of bounds: the length is 3 but the index is 10
//   --> src/main.rs:42:8
//    |
// 42 |     Ok(data[10])
//    |        ^^^^^^^^ index out of bounds
//    |
//    = note: `#[deny(unconditional_panic)]` on by default
```

#### Ruby
```ruby
# Ruby provides full backtrace
def process
  data = [1, 2, 3]
  data[10].upcase  # NoMethodError
end

# Error output:
# app.rb:15:in `process': undefined method `upcase' for nil:NilClass (NoMethodError)
#   from app.rb:25:in `<main>'
```

Quest should match or exceed these standards.

## Design

### Phase 1: Magic Variables (Core Foundation)

#### Compile-Time Location Constants

Add three magic variables that resolve at **parse time**:

```quest
# __file__ - Absolute path to current file
puts(__file__)
# Output: /Users/name/project/app/main.q

# __line__ - Current line number (integer)
puts(__line__)
# Output: 42

# __function__ - Current function name (or "<module>" if top-level)
fun example()
    puts(__function__)
end
example()
# Output: example
```

#### Implementation in Parser

**Location**: `src/quest.pest` and `src/main.rs`

Add new tokens:
```pest
// src/quest.pest
magic_variable = { "__file__" | "__line__" | "__function__" }
primary = {
    magic_variable |
    // ... existing primary rules ...
}
```

**Evaluation**: Replace during parsing
```rust
// src/main.rs - in eval_pair_impl()
Rule::magic_variable => {
    let magic_name = pair.as_str();
    match magic_name {
        "__file__" => {
            // Get current file path from scope or evaluator context
            let file_path = scope.current_file();
            Ok(QValue::Str(QString::new(file_path.to_string())))
        }
        "__line__" => {
            // Get line number from pest Pair's position
            let line_num = pair.as_span().start_pos().line_col().0;
            Ok(QValue::Int(QInt::new(line_num as i64)))
        }
        "__function__" => {
            // Get current function name from scope stack
            let func_name = scope.current_function_name();
            Ok(QValue::Str(QString::new(func_name)))
        }
        _ => Err(format!("Unknown magic variable: {}", magic_name))
    }
}
```

#### Scope Enhancement

**Location**: `src/scope.rs`

Add context tracking:
```rust
pub struct Scope {
    // ... existing fields ...
    current_file: Option<String>,
    current_function: Option<String>,
    call_stack: Vec<CallFrame>,
}

pub struct CallFrame {
    pub function_name: String,
    pub file_path: String,
    pub line_number: usize,
    pub local_vars: HashMap<String, QValue>,  // For enhanced debugging
}

impl Scope {
    pub fn current_file(&self) -> &str {
        self.current_file.as_deref().unwrap_or("<unknown>")
    }

    pub fn current_function_name(&self) -> String {
        self.current_function.clone().unwrap_or_else(|| "<module>".to_string())
    }

    pub fn push_call_frame(&mut self, function_name: String, file: String, line: usize) {
        self.call_stack.push(CallFrame {
            function_name,
            file_path: file,
            line_number: line,
            local_vars: HashMap::new(),
        });
    }

    pub fn pop_call_frame(&mut self) {
        self.call_stack.pop();
    }

    pub fn build_stack_trace(&self) -> Vec<String> {
        self.call_stack.iter().rev().map(|frame| {
            format!("  at {}:{} in {}()",
                frame.file_path,
                frame.line_number,
                frame.function_name
            )
        }).collect()
    }
}
```

### Phase 2: Automatic Exception Context

#### Enhanced Exception Creation

**Location**: `src/types/exception.rs`

Modify `QException` to capture location automatically:

```rust
impl QException {
    /// Create exception with automatic location capture
    pub fn new_with_context(
        exception_type: ExceptionType,
        message: String,
        scope: &Scope,
    ) -> Self {
        let current_frame = scope.call_stack.last();

        QException {
            exception_type,
            message,
            line: current_frame.map(|f| f.line_number),
            file: current_frame.map(|f| f.file_path.clone()),
            stack: scope.build_stack_trace(),
            cause: None,
            original_value: None,
            id: next_object_id(),
        }
    }
}
```

#### Automatic Capture in `raise` Statements

**Location**: `src/control_flow.rs`

When processing `raise` statements, automatically inject context:

```rust
// In handle_raise() function
fn handle_raise(exception_value: QValue, scope: &Scope) -> Result<QValue, String> {
    match exception_value {
        QValue::Exception(mut exc) => {
            // If exception doesn't have location, inject current context
            if exc.file.is_none() || exc.line.is_none() {
                let current_frame = scope.call_stack.last();
                if let Some(frame) = current_frame {
                    exc.file = Some(frame.file_path.clone());
                    exc.line = Some(frame.line_number);
                }
            }

            // If exception doesn't have stack trace, build one
            if exc.stack.is_empty() {
                exc.stack = scope.build_stack_trace();
            }

            Err(format!("Exception: {}", exc.str()))
        }
        _ => Err("raise expects an exception".to_string())
    }
}
```

### Phase 3: Rich Error Formatting

#### Source Code Snippet Extraction

Add utility to show code context around error:

```rust
// src/error_formatter.rs (new file)

pub struct ErrorFormatter {
    source_cache: HashMap<String, Vec<String>>,  // File path -> lines
}

impl ErrorFormatter {
    pub fn format_error_with_source(
        &mut self,
        exception: &QException,
        context_lines: usize,
    ) -> String {
        let mut output = String::new();

        // Header: Exception type and message
        output.push_str(&format!("{}: {}\n",
            exception.exception_type.name(),
            exception.message
        ));

        // Location with source snippet
        if let (Some(file), Some(line)) = (&exception.file, exception.line) {
            output.push_str(&format!("  at {}:{}\n", file, line));

            // Load source file
            if let Some(source_lines) = self.load_source_file(file) {
                output.push_str(&self.format_source_snippet(
                    source_lines,
                    line,
                    context_lines,
                ));
            }
        }

        // Stack trace
        if !exception.stack.is_empty() {
            output.push_str("\nStack trace:\n");
            for frame in &exception.stack {
                output.push_str(&format!("{}\n", frame));
            }
        }

        output
    }

    fn format_source_snippet(
        &self,
        lines: &[String],
        error_line: usize,
        context: usize,
    ) -> String {
        let mut output = String::new();

        let start = error_line.saturating_sub(context + 1);
        let end = (error_line + context).min(lines.len());

        output.push_str("\n");
        for (i, line) in lines[start..end].iter().enumerate() {
            let line_num = start + i + 1;
            let indicator = if line_num == error_line { "→" } else { " " };
            output.push_str(&format!("{:4}{} | {}\n", line_num, indicator, line));

            // Add caret line for error line
            if line_num == error_line {
                output.push_str(&format!("     | {}\n", "^".repeat(line.len().min(80))));
            }
        }

        output
    }

    fn load_source_file(&mut self, file_path: &str) -> Option<&[String]> {
        // Cache source files for performance
        if !self.source_cache.contains_key(file_path) {
            if let Ok(content) = std::fs::read_to_string(file_path) {
                let lines: Vec<String> = content.lines().map(String::from).collect();
                self.source_cache.insert(file_path.to_string(), lines);
            } else {
                return None;
            }
        }

        self.source_cache.get(file_path).map(|v| v.as_slice())
    }
}
```

#### Example Rich Error Output

**Code**:
```quest
# app/processor.q
fun process_data(items)
    let result = []
    for item in items
        result.push(item.value * 2)  # Error: item has no 'value' field
    end
    return result
end
```

**Rich Error Output**:
```
AttrErr: Object has no attribute 'value'
  at app/processor.q:5

   3  | fun process_data(items)
   4  |     let result = []
   5 → |     for item in items
      |             ^^^^^^^^^^
   6  |         result.push(item.value * 2)
   7  |     end

Stack trace:
  at app/processor.q:5 in process_data()
    items: [{id: 1}, {id: 2}]
  at app/main.q:23 in main()
```

### Phase 4: Enhanced Stack Traces with Values

#### Capture Argument Values

Enhance `CallFrame` to store function arguments:

```rust
pub struct CallFrame {
    pub function_name: String,
    pub file_path: String,
    pub line_number: usize,
    pub arguments: Vec<(String, QValue)>,  // Argument name -> value
    pub local_vars: HashMap<String, QValue>,
}

impl CallFrame {
    pub fn format_with_args(&self) -> String {
        let mut output = format!("  at {}:{} in {}(",
            self.file_path,
            self.line_number,
            self.function_name
        );

        // Show argument values (truncated if too long)
        for (i, (name, value)) in self.arguments.iter().enumerate() {
            if i > 0 {
                output.push_str(", ");
            }
            output.push_str(&format!("{}: {}", name, value.repr_short(50)));
        }
        output.push_str(")\n");

        output
    }
}
```

#### Value Representation for Debugging

Add method to `QValue` for short representations:

```rust
impl QValue {
    /// Short representation for debugging (max_len characters)
    pub fn repr_short(&self, max_len: usize) -> String {
        let full = self._rep();
        if full.len() <= max_len {
            full
        } else {
            format!("{}...", &full[..max_len - 3])
        }
    }
}
```

#### Example Enhanced Stack Trace

```
TypeErr: Expected int, got str
  at lib/math.q:15 in multiply()
    a: 42, b: "not_a_number"
  at lib/processor.q:78 in transform()
    data: {count: "not_a_number", id: 42, name: "test"}
  at app/handler.q:45 in process_request()
    request: Request{method: "POST", path: "/api/calc"}
  at app/main.q:120 in main()
```

### Phase 5: Debug Mode

#### Debug Flags and Configuration

Add debug configuration via environment variable or command line:

```bash
# Enable debug mode
export QUEST_DEBUG=1
quest app.q

# Or via command line flag
quest --debug app.q

# Debug specific features
quest --debug=stack,values,timing app.q
```

#### Debug Output Features

**1. Function Entry/Exit Tracing**
```
→ ENTER process_data() at app/processor.q:12
  args: items=[1, 2, 3]
  ← EXIT process_data() at app/processor.q:18
    returned: [2, 4, 6]
    duration: 0.15ms
```

**2. Variable Tracking**
```
app/processor.q:14: let result = []
  result = []

app/processor.q:16: result.push(item.value * 2)
  item = {id: 1, value: 5}
  result = [10]
```

**3. Exception Augmentation**
```
DEBUG: Exception raised
  Type: TypeErr
  Message: Expected int, got str
  Location: lib/math.q:15
  Local variables at error:
    a = 42
    b = "not_a_number"
    temp = nil
```

### Phase 6: IDE and Tooling Integration

#### Language Server Protocol (LSP) Integration

Provide structured error information for IDEs:

```json
{
  "error": {
    "type": "TypeErr",
    "message": "Expected int, got str",
    "severity": "error",
    "location": {
      "file": "app/processor.q",
      "line": 45,
      "column": 12,
      "length": 8
    },
    "stack_trace": [
      {
        "file": "lib/math.q",
        "line": 15,
        "function": "multiply",
        "arguments": {"a": "42", "b": "\"not_a_number\""}
      }
    ],
    "suggestions": [
      "Convert the value to an integer using .to_int()",
      "Check that the input is numeric before calling multiply()"
    ]
  }
}
```

#### Source Maps for Compiled Code

If Quest adds compilation/optimization:

```json
// app.q.map
{
  "version": 3,
  "file": "app.compiled.q",
  "sourceRoot": "",
  "sources": ["app.q"],
  "mappings": "AAAA,SAAS,YAAY..."
}
```

Errors in compiled code map back to original source.

### Phase 7: Performance and Profiling Integration

#### Location-Based Profiling

Track execution time per file/line:

```quest
# Enable profiling
quest --profile app.q

# Output:
# Performance Profile
# ==================
#
# Hot spots:
#   app/processor.q:45  - 45.2% (process_data loop)
#   lib/math.q:78       - 23.1% (matrix_multiply)
#   app/database.q:156  - 12.5% (query execution)
```

#### Error Frequency Tracking

Track which errors occur most often:

```quest
# Error frequency (last 1000 errors)
#
# Top errors:
#   TypeErr at lib/validator.q:89     - 456 occurrences
#   IndexErr at app/processor.q:45    - 123 occurrences
#   KeyErr at app/cache.q:67          - 89 occurrences
```

## Implementation Plan

### Phase 1: Foundation (Quest 0.2) - 3-4 weeks

**Week 1-2: Magic Variables**
- [ ] Add `__file__`, `__line__`, `__function__` to parser
- [ ] Implement magic variable resolution
- [ ] Add tests for magic variables
- [ ] Update documentation

**Week 3: Call Stack Tracking**
- [ ] Enhance `Scope` with call stack
- [ ] Track function entry/exit
- [ ] Add `CallFrame` structure
- [ ] Implement `build_stack_trace()`

**Week 4: Automatic Exception Context**
- [ ] Modify exception creation to capture context
- [ ] Update `raise` to inject location
- [ ] Update all exception raising code
- [ ] Add tests for automatic context

**Deliverables**:
- Magic variables working
- Exceptions include file/line/function
- Basic stack traces

### Phase 2: Rich Formatting (Quest 0.3) - 2-3 weeks

**Week 1: Error Formatter**
- [ ] Create `ErrorFormatter` utility
- [ ] Implement source file caching
- [ ] Add source snippet formatting
- [ ] Color-coded output for terminals

**Week 2: Enhanced Stack Traces**
- [ ] Add argument capture to `CallFrame`
- [ ] Implement `repr_short()` for values
- [ ] Format stack traces with arguments
- [ ] Add truncation for large values

**Week 3: Integration and Testing**
- [ ] Integrate formatter with REPL
- [ ] Add configuration options (snippet size, colors)
- [ ] Comprehensive test suite
- [ ] Documentation and examples

**Deliverables**:
- Rust-style error messages with source snippets
- Stack traces include argument values
- Configurable formatting

### Phase 3: Debug Mode (Quest 0.4) - 2 weeks

**Week 1: Debug Infrastructure**
- [ ] Add `QUEST_DEBUG` environment variable
- [ ] Command line `--debug` flag
- [ ] Debug output utilities
- [ ] Function tracing

**Week 2: Advanced Debug Features**
- [ ] Variable tracking
- [ ] Exception augmentation
- [ ] Performance impact mitigation
- [ ] Documentation

**Deliverables**:
- Debug mode with function tracing
- Variable value tracking
- Minimal performance overhead

### Phase 4: IDE Integration (Quest 0.5) - 2-3 weeks

**Week 1-2: LSP Integration**
- [ ] Structured error format (JSON)
- [ ] LSP error reporting
- [ ] IDE integration examples
- [ ] VS Code extension updates

**Week 3: Tooling**
- [ ] Error log parser
- [ ] Error frequency analyzer
- [ ] Source map support (if needed)
- [ ] Documentation

**Deliverables**:
- LSP error reporting
- IDE integration guides
- Tooling for error analysis

### Phase 5: Production Features (Quest 1.0) - 2 weeks

**Week 1: Production Enhancements**
- [ ] Structured logging integration
- [ ] Error aggregation
- [ ] Performance profiling
- [ ] Error frequency tracking

**Week 2: Polish and Documentation**
- [ ] Comprehensive documentation
- [ ] Best practices guide
- [ ] Migration guide
- [ ] Performance benchmarks

**Deliverables**:
- Production-ready error diagnostics
- Complete documentation
- Performance profiling integration

**Total Timeline**: ~12-15 weeks across multiple Quest releases

## API Reference

### Magic Variables

```quest
# Compile-time location constants

__file__      # Absolute path to current file (str)
__line__      # Current line number (int)
__function__  # Current function name or "<module>" (str)
```

### Debug Functions (std/sys)

```quest
use "std/sys" as sys

# Get current call stack
let stack = sys.get_call_stack()
# Returns: [{function: "foo", file: "app.q", line: 42}, ...]

# Get current stack depth
let depth = sys.get_call_depth()
# Returns: 5

# Format exception with rich output
let formatted = sys.format_exception(exception, show_source: true, context_lines: 3)
```

### Configuration (quest.toml)

```toml
[debug]
# Enable debug mode
enabled = false

# Features to enable
trace_functions = false    # Log function entry/exit
trace_variables = false    # Log variable assignments
show_arguments = true      # Show argument values in stack traces
source_snippets = true     # Show source code in errors
context_lines = 3          # Lines of context around error

# Output
use_colors = true          # Color-coded output
max_value_length = 100     # Max length for value repr
max_stack_depth = 50       # Max stack frames to show
```

### Command Line Flags

```bash
# Debug mode
quest --debug script.q
quest --debug=trace,values script.q

# Error formatting
quest --no-colors script.q           # Disable colors
quest --full-stack script.q          # Show full stack (no truncation)
quest --no-source script.q           # Disable source snippets

# Profiling
quest --profile script.q             # Enable profiling
quest --profile-output=report.txt    # Save profile to file
```

## Examples

### Example 1: Magic Variables

```quest
# lib/utils.q

fun log_error(message)
    puts("ERROR [" .. __file__ .. ":" .. __line__.str() .. "] " .. message)
end

fun debug(message)
    if DEBUG_ENABLED
        puts("DEBUG [" .. __function__ .. "] " .. message)
    end
end

fun process()
    debug("Starting process")  # DEBUG [process] Starting process
    log_error("Something failed")  # ERROR [lib/utils.q:15] Something failed
end
```

### Example 2: Rich Error with Source

**Code**:
```quest
# app/calculator.q
fun divide(a, b)
    return a / b  # Line 3
end

fun calculate(x, y, op)
    if op == "divide"
        return divide(x, y)
    end
end

# Error: divide by zero
calculate(10, 0, "divide")
```

**Output**:
```
ArithmeticErr: Division by zero
  at app/calculator.q:3 in divide()

   1 | # app/calculator.q
   2 | fun divide(a, b)
   3 →     return a / b
       |            ^^^^^
   4 | end

Stack trace:
  at app/calculator.q:3 in divide(a: 10, b: 0)
  at app/calculator.q:8 in calculate(x: 10, y: 0, op: "divide")
  at app/calculator.q:13 in <module>
```

### Example 3: Debug Mode

**Code**:
```quest
# app/process.q
fun process_items(items)
    let result = []
    for item in items
        result.push(item * 2)
    end
    return result
end

process_items([1, 2, 3])
```

**Debug Output** (with `quest --debug app/process.q`):
```
→ ENTER process_items() at app/process.q:2
  args: items=[1, 2, 3]

  app/process.q:3: let result = []
    result = []

  app/process.q:4: for item in items (iteration 1)
    item = 1

  app/process.q:5: result.push(item * 2)
    result = [2]

  app/process.q:4: for item in items (iteration 2)
    item = 2

  app/process.q:5: result.push(item * 2)
    result = [2, 4]

  app/process.q:4: for item in items (iteration 3)
    item = 3

  app/process.q:5: result.push(item * 2)
    result = [2, 4, 6]

← EXIT process_items() at app/process.q:7
  returned: [2, 4, 6]
  duration: 0.23ms
```

### Example 4: Production Logging

**Code**:
```quest
# app/api.q
use "std/log" as log

fun handle_request(request)
    try
        let result = process(request)
        return result
    catch e
        # Automatic location context in logs
        log.error("Request failed: " .. e.str())
        raise e
    end
end
```

**Log Output**:
```json
{
  "timestamp": "2025-10-16T14:32:15Z",
  "level": "ERROR",
  "message": "Request failed: TypeErr: Expected int, got str",
  "location": {
    "file": "app/api.q",
    "line": 10,
    "function": "handle_request"
  },
  "exception": {
    "type": "TypeErr",
    "message": "Expected int, got str",
    "stack": [
      "lib/validator.q:45 in validate_input()",
      "lib/processor.q:89 in process()",
      "app/api.q:6 in handle_request()"
    ]
  },
  "context": {
    "request_id": "req_abc123",
    "user_id": "user_456"
  }
}
```

## Performance Considerations

### Impact Analysis

| Feature | Performance Impact | Mitigation |
|---------|-------------------|------------|
| Magic variables | None (compile-time) | Resolved during parsing |
| Call stack tracking | ~5-10% overhead | Only track in debug mode by default |
| Source file caching | Minimal (one-time load) | Cache files in memory |
| Argument capture | ~10-15% overhead | Configurable, off by default |
| Debug mode | ~50-100% slower | Only enable when debugging |
| Rich formatting | Minimal (error path) | Only format on error |

### Production Recommendations

**Default configuration** (production):
```toml
[debug]
enabled = false
show_arguments = false
trace_functions = false
trace_variables = false
source_snippets = true      # Show source on errors (minimal cost)
context_lines = 3
```

**Performance**: Negligible impact (~1-2% overhead for call stack tracking)

**Development configuration**:
```toml
[debug]
enabled = true
show_arguments = true
trace_functions = true      # Significant overhead (~50%)
trace_variables = true
source_snippets = true
context_lines = 5
```

### Optimization Strategies

1. **Lazy Stack Trace Building**: Only build full stack trace when exception is actually caught/logged
2. **Smart Caching**: Cache source files but evict rarely-used files
3. **Compile-Time Optimization**: Strip debug info in optimized builds
4. **Sampling**: In high-throughput scenarios, only trace 1/N calls

## Migration and Compatibility

### Backward Compatibility

✅ **Fully backward compatible**:
- All existing code works unchanged
- Magic variables are opt-in
- Debug mode is disabled by default
- Existing error handling unchanged

### Gradual Adoption

**Phase 1**: Add magic variables to new code
```quest
# New code uses __file__ for better errors
fun validate(data)
    if not data.valid
        raise ValueErr.new("Invalid data at " .. __file__ .. ":" .. __line__.str())
    end
end
```

**Phase 2**: Enable debug mode in development
```bash
# Development
export QUEST_DEBUG=1
quest app.q

# Production (no debug)
quest app.q
```

**Phase 3**: Update libraries to use enhanced errors
```quest
# stdlib modules adopt enhanced diagnostics
# Applications automatically benefit
```

### Migration Guide

**For application developers**:
1. No changes required (errors automatically improve)
2. Optionally use `__file__`/`__line__` in custom error messages
3. Enable debug mode during development

**For library developers**:
1. Consider using magic variables in error messages
2. Ensure error messages are clear and actionable
3. Test with debug mode enabled

## Testing Strategy

### Unit Tests

```quest
# test/magic_variables_test.q

test.describe("Magic Variables", fun ()
    test.it("__file__ returns current file path", fun ()
        let file = __file__
        test.assert(file.ends_with("magic_variables_test.q"))
    end)

    test.it("__line__ returns current line number", fun ()
        let line1 = __line__
        let line2 = __line__
        test.assert_eq(line2, line1 + 1)
    end)

    test.it("__function__ returns function name", fun ()
        fun example()
            return __function__
        end
        test.assert_eq(example(), "example")
    end)
end)
```

### Integration Tests

```quest
# test/enhanced_errors_test.q

test.describe("Enhanced Error Diagnostics", fun ()
    test.it("exceptions include file and line", fun ()
        try
            raise TypeErr.new("test error")
        catch e: TypeErr
            test.assert(e.file() != nil)
            test.assert(e.line() != nil)
        end
    end)

    test.it("stack traces include function names", fun ()
        fun inner()
            raise ValueErr.new("inner error")
        end

        fun outer()
            inner()
        end

        try
            outer()
        catch e: ValueErr
            let stack = e.stack()
            test.assert(stack.any(fun (s) s.contains("inner") end))
            test.assert(stack.any(fun (s) s.contains("outer") end))
        end
    end)
end)
```

### Performance Tests

```quest
# benchmark/error_overhead.q

use "std/sys" as sys

# Measure overhead of call stack tracking
fun benchmark_stack_tracking()
    let start = sys.time()

    let i = 0
    while i < 10000
        dummy_function(i)
        i = i + 1
    end

    let duration = sys.time() - start
    puts("Stack tracking overhead: " .. duration.str() .. "ms")
end

fun dummy_function(x)
    return x * 2
end

benchmark_stack_tracking()
```

## Success Criteria

### Functional Requirements

- ✅ Magic variables (`__file__`, `__line__`, `__function__`) implemented and tested
- ✅ Exceptions automatically capture location and stack trace
- ✅ Rich error formatting with source snippets
- ✅ Debug mode with function/variable tracing
- ✅ IDE integration (LSP error reporting)
- ✅ Performance overhead <5% in production mode
- ✅ All existing tests pass
- ✅ Comprehensive documentation

### Quality Requirements

- ✅ Error messages are clear and actionable
- ✅ Stack traces are readable and helpful
- ✅ Source snippets highlight the relevant code
- ✅ Debug output doesn't overwhelm users
- ✅ Performance impact is acceptable
- ✅ Documentation is comprehensive with examples

### User Experience Requirements

- ✅ Developers can quickly identify error location
- ✅ Stack traces show call chain with arguments
- ✅ Debug mode helps understand execution flow
- ✅ IDEs show errors inline with context
- ✅ Production logs include actionable information

## Future Enhancements

### Beyond Quest 1.0

1. **Interactive Debugging**
   - REPL-based debugger
   - Set breakpoints in code
   - Step through execution
   - Inspect variables

2. **Remote Debugging**
   - Debug production applications remotely
   - Live error monitoring
   - Real-time stack traces

3. **Error Recovery Suggestions**
   - AI-powered error fixes
   - "Did you mean?" suggestions
   - Link to relevant documentation

4. **Visual Debugging Tools**
   - Flame graphs for performance
   - Call tree visualization
   - Error frequency heatmaps

5. **Time-Travel Debugging**
   - Record execution trace
   - Step backward through code
   - Inspect historical state

## Related Work

### Comparison with Other Languages

| Language | Magic Variables | Stack Traces | Source Snippets | Debug Mode |
|----------|----------------|--------------|-----------------|------------|
| Python | `__file__` | ✅ Excellent | ❌ No | Via pdb |
| Ruby | `__FILE__`, `__LINE__` | ✅ Excellent | ❌ No | Via debugger |
| Rust | `file!()`, `line!()` | ✅ Excellent | ✅ Yes | N/A (compile-time) |
| JavaScript | ❌ No (stack only) | ✅ Good | ❌ No | Via debugger |
| Quest (proposed) | ✅ Yes | ✅ Excellent | ✅ Yes | ✅ Built-in |

Quest's error diagnostics will be **best-in-class** for dynamic languages.

## References

- [QEP-037: Typed Exception System](qep-037-typed-exception-system.md)
- [Python traceback module](https://docs.python.org/3/library/traceback.html)
- [Rust error handling](https://doc.rust-lang.org/book/ch09-00-error-handling.html)
- [Ruby Exception class](https://ruby-doc.org/core-3.0.0/Exception.html)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)

---

**Status**: Draft - awaiting review and discussion
**Target Release**: Quest 1.0 (phases across 0.2-1.0)
**Estimated Effort**: 12-15 weeks across multiple releases
