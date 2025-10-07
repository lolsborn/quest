# QEP-039: Hybrid Bytecode/Interpreter Execution

- **Number**: 039
- **Status**: Draft
- **Author**: Quest Team
- **Created**: 2025-10-07
- **Last Updated**: 2025-10-07 (post-review revisions)

## Abstract

This QEP proposes a hybrid execution model for Quest that combines bytecode compilation with AST interpretation. The approach enables incremental development of a bytecode VM while maintaining 100% backward compatibility. Unimplemented bytecode features gracefully fall back to the existing interpreter, allowing continuous delivery of performance improvements without "big bang" rewrites.

**Key Benefits**: Incremental development, always-working code, easy debugging, gradual learning curve, and continuous performance improvements.

## Motivation

Quest currently uses a pure AST interpreter, which is simple but has performance limitations. A full bytecode VM rewrite would be risky and time-consuming. We need a strategy that:

1. **Enables incremental development** - Build bytecode support gradually without breaking existing code
2. **Always remains functional** - Users never see broken or incomplete features
3. **Facilitates learning** - Allows developers to understand bytecode concepts one opcode at a time
4. **Enables debugging** - Provides a reference implementation to validate bytecode correctness
5. **Ships improvements continuously** - Performance gains visible as opcodes are implemented

## Proposal

Implement a **hybrid execution model** where Quest can execute code using either bytecode (fast path) or AST interpretation (fallback path):

```rust
pub enum ExecutionMode {
    Bytecode,      // Fast path - when implemented
    Interpret,     // Fallback - AST interpreter
}

pub struct VM {
    // Bytecode state
    bytecode: Vec<Instruction>,
    registers: Vec<Value>,

    // Fallback to AST interpreter
    ast_interpreter: AstInterpreter,

    // Track what's implemented
    implemented_ops: HashSet<Opcode>,
}
```

### Architecture Components

**Phase 1: Retain AST Interpreter** (existing)
- Keep current AST interpreter fully functional
- Serves as reference implementation
- Always available as fallback

**Phase 2: Add Bytecode Layer**
```rust
pub enum Opcode {
    // Start with just a few
    LoadConst,    // Load constant
    Add,          // Addition
    Return,       // Return value

    // Add more as you implement
    LoadLocal,
    StoreLocal,
    Call,
    // ... etc
}

pub struct Instruction {
    opcode: Opcode,
    operand: u32,  // Keep it simple at first
}

pub struct VM {
    bytecode: Vec<Instruction>,
    ip: usize,              // instruction pointer
    registers: Vec<Value>,  // Register-based architecture
    constants: Vec<Value>,

    // THE KEY: Fallback interpreter
    ast_interpreter: AstInterpreter,
    ast_cache: HashMap<usize, Expr>, // Map IP to AST node
    local_map: HashMap<String, u8>,  // Variable name -> register mapping
}
```

**Phase 3: Hybrid Execution**
```rust
impl VM {
    pub fn execute(&mut self) -> Result<Value> {
        while self.ip < self.bytecode.len() {
            let instr = &self.bytecode[self.ip];

            match instr.opcode {
                // Implemented opcodes - fast path
                Opcode::LoadConst { dest, const_idx } => {
                    let val = self.constants[const_idx as usize].clone();
                    self.registers[dest as usize] = val;
                    self.ip += 1;
                }

                Opcode::Add { dest, a, b } => {
                    let val_a = &self.registers[a as usize];
                    let val_b = &self.registers[b as usize];
                    self.registers[dest as usize] =
                        Value::Number(val_a.as_number()? + val_b.as_number()?);
                    self.ip += 1;
                }

                // NOT YET IMPLEMENTED - fallback!
                Opcode::MakeClosure { .. } => {
                    return self.fallback_to_interpreter(self.ip);
                }
            }
        }
        Ok(Value::Nil)
    }

    fn fallback_to_interpreter(&mut self, from_ip: usize) -> Result<Value> {
        // CRITICAL: Sync VM register state back to interpreter variables
        for (var_name, reg_idx) in &self.local_map {
            let value = self.registers[*reg_idx as usize].clone();
            self.ast_interpreter.set_var(var_name, value);
        }

        // Execute using interpreter
        let ast_node = self.ast_cache.get(&from_ip)?;
        let result = self.ast_interpreter.eval(ast_node)?;

        // Sync interpreter state back to registers
        for (var_name, reg_idx) in &self.local_map {
            if let Some(value) = self.ast_interpreter.get_var(var_name) {
                self.registers[*reg_idx as usize] = value.clone();
            }
        }

        Ok(result)
    }
}
```

**Phase 4: Compiler with Fallback Markers**
```rust
pub struct Compiler {
    bytecode: Vec<Instruction>,
    constants: Vec<Value>,
    ast_cache: HashMap<usize, Expr>,
}

impl Compiler {
    pub fn compile(&mut self, expr: &Expr) -> Result<()> {
        match expr {
            Expr::Number(n) => {
                // Implemented! Generate bytecode
                let const_idx = self.add_constant(Value::Number(*n));
                self.emit(Opcode::LoadConst, const_idx);
            }

            Expr::Closure { params, body } => {
                // NOT IMPLEMENTED YET!
                // Store AST for fallback
                let ip = self.bytecode.len();
                self.ast_cache.insert(ip, expr.clone());
                self.emit(Opcode::MakeClosure, ip as u32);
            }
        }
        Ok(())
    }
}
```

### Implementation Order

**Week 1-2: Core Opcodes** (5-10 opcodes)
- `LoadConst` - Load constant value
- `LoadLocal` - Load local variable
- `StoreLocal` - Store local variable
- `Add`, `Sub`, `Mul`, `Div` - Basic arithmetic
- `Jump` - Unconditional jump
- `Return` - Return from function

**Week 3-4: Control Flow** (5-10 opcodes)
- `JumpIfFalse` - Conditional jump
- `JumpIfTrue` - Conditional jump
- `Compare` - Comparison operations
- `And`, `Or`, `Not` - Boolean operations

**Week 5-6: Functions** (5 opcodes)
- `Call` - Call function
- `MakeFunction` - Create function object
- `GetUpvalue` - Closure support
- `SetUpvalue` - Closure support

**Week 7-8: Closures** (incremental)
- Start with simple functions
- Add upvalue support incrementally
- Fall back to interpreter for complex cases

**Week 9-10: Exceptions**
- `Throw` - Throw exception
- `PushHandler` - Exception handler
- `PopHandler` - Pop handler

## Rationale

### Why Hybrid Execution?

**✅ Incremental Development**
- Start with 5 opcodes, grow to 50+
- Ship working code while improving performance
- Test each opcode thoroughly before moving on

**✅ Always Working**
- Incomplete bytecode? Fall back to interpreter
- No "big bang" rewrite
- Users don't see breakage

**✅ Easy Debugging**
- Compare bytecode vs interpreter results
- Catch codegen bugs immediately
- Reference implementation always available

**✅ Learn Gradually**
- Understand one opcode at a time
- See performance improvements incrementally
- Build intuition for bytecode design

### Architecture Choice: Register-Based VM

**Recommendation**: Use a **register-based** architecture (Lua-style) rather than stack-based (Python-style).

**Benefits**:
- Fewer instructions for common operations (no stack shuffling)
- More natural mapping from AST to bytecode
- Better performance (empirically proven by Lua)
- Easier to optimize with peephole techniques

**Example comparison**:
```
Stack-based (a + b * c):
  LOAD_VAR b
  LOAD_VAR c
  MUL
  LOAD_VAR a
  ADD

Register-based:
  MUL R2, b, c
  ADD R1, a, R2
```

### Why NOT Other Options?

**❌ Pure WebAssembly Backend**
- Closures require complex GC (Wasm GC still stabilizing)
- Manual exception handling (unwinding)
- Manual dynamic dispatch and object system
- Too complex for first bytecode implementation

**❌ JVM Bytecode**
- Must generate valid `.class` files
- Complex verification rules and stack map frames
- Type system mismatch with Quest
- Not suitable for learning

**❌ Pure Custom Bytecode (No Fallback)**
- All-or-nothing: must implement everything before it works
- Debugging is a nightmare
- Can't ship until 100% complete
- High risk of prolonged breakage

### Performance Expectations

**Realistic Speedup Targets** (compared to AST interpreter):

- **Simple arithmetic** (`2 + 3 * 4`): 3-5x faster
  - Fewer allocations, direct register operations

- **Function calls** (no closures): 2-3x faster
  - Optimized call frames, register passing

- **Loops and control flow**: 2-4x faster
  - Direct jumps vs AST traversal

- **Complex closures** (initially): 0.9-1.2x (10-20% speedup, may initially regress)
  - Overhead of upvalue management
  - Will improve with optimization

- **Overall typical program**: 2-3x faster at 80% bytecode coverage

**Note**: These are conservative estimates. Mature bytecode VMs (Lua, Python) achieve 5-10x over naive interpreters.

## Examples

### Top-Level Architecture

```rust
pub struct Language {
    // Phase 1: Start here (existing)
    interpreter: AstInterpreter,

    // Phase 2: Add this (new)
    compiler: Option<Compiler>,
    vm: Option<VM>,

    // Configuration
    prefer_bytecode: bool,  // Try bytecode first
}

impl Language {
    pub fn execute(&mut self, code: &str) -> Result<Value> {
        let ast = self.parse(code)?;

        if self.prefer_bytecode && self.compiler.is_some() {
            // Try bytecode path
            match self.compile_and_run(&ast) {
                Ok(value) => return Ok(value),
                Err(e) if e.is_not_implemented() => {
                    // Fall back to interpreter
                    eprintln!("Bytecode incomplete, using interpreter");
                }
                Err(e) => return Err(e),
            }
        }

        // Interpreter path (always works)
        self.interpreter.eval(&ast)
    }
}
```

### Register-Based Implementation

```rust
pub enum Instruction {
    // Simple instructions (implement early)
    LoadK { dest: u8, const_idx: u16 },  // dest = constants[idx]
    Move { dest: u8, src: u8 },          // dest = src
    Add { dest: u8, a: u8, b: u8 },      // dest = a + b

    // Complex instructions (implement later, fall back initially)
    MakeClosure { dest: u8, proto_idx: u16 },
    CallComplex { func: u8, args: Vec<u8> },
}

impl VM {
    fn execute_instruction(&mut self, instr: &Instruction) -> Result<()> {
        match instr {
            Instruction::LoadK { dest, const_idx } => {
                self.registers[*dest as usize] =
                    self.constants[*const_idx as usize].clone();
                Ok(())
            }

            Instruction::Add { dest, a, b } => {
                let val_a = &self.registers[*a as usize];
                let val_b = &self.registers[*b as usize];
                self.registers[*dest as usize] =
                    Value::Number(val_a.as_number()? + val_b.as_number()?);
                Ok(())
            }

            Instruction::MakeClosure { .. } => {
                // TODO: Implement later
                Err(NotImplemented::Closure.into())
            }
        }
    }
}
```

### Incremental Closure Implementation

```rust
// Version 1: No closures, fall back
impl VM {
    fn execute_closure(&mut self) -> Result<Value> {
        // Not implemented, use interpreter
        self.fallback_to_interpreter(self.ip)
    }
}

// Version 2: Simple closures (no upvalues)
impl VM {
    fn execute_closure(&mut self) -> Result<Value> {
        if self.has_upvalues() {
            // Complex case - fall back
            return self.fallback_to_interpreter(self.ip);
        }
        // Simple case - use bytecode
        self.execute_simple_closure()
    }
}

// Version 3: Full closures
impl VM {
    fn execute_closure(&mut self) -> Result<Value> {
        // Fully implemented!
        self.execute_full_closure()
    }
}
```

### Testing Strategy

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_opcodes_match_interpreter() {
        let code = "2 + 3 * 4";

        // Execute with interpreter
        let interp_result = AstInterpreter::new().eval(parse(code));

        // Execute with bytecode
        let bytecode_result = VM::compile_and_run(parse(code));

        // Must match!
        assert_eq!(interp_result, bytecode_result);
    }

    #[test]
    fn test_fallback_for_unimplemented() {
        // Test that unimplemented features fall back gracefully
        let code = "fun () { let x = 1; fun () { x } } end";

        let result = VM::compile_and_run(parse(code));
        assert!(result.is_ok());
    }
}
```

### Quest Usage Example

```quest
# User code that works regardless of bytecode implementation status

# Simple arithmetic (likely bytecode)
let x = 2 + 3 * 4

# Function calls (might be bytecode)
fun add(a, b)
    a + b
end

# Complex closures (might fall back to interpreter)
fun make_counter()
    let count = 0
    fun ()
        count = count + 1
        count
    end
end

let counter = make_counter()
puts(counter())  # 1
puts(counter())  # 2
```

## Modern Feature Support

This section addresses how recently-implemented Quest features (QEP-033 through QEP-037) interact with the bytecode VM.

### Default Parameters (QEP-033)

**Challenge**: Default expressions are evaluated at **call time**, not definition time.

**Bytecode Strategy**:
```quest
fun greet(name, greeting = "Hello")
    greeting .. ", " .. name
end
```

Compiled to:
```rust
// Function prologue checks if argument was provided
LoadArg R0, 0          // name (always provided)
ArgCount R1            // Get actual arg count
LoadConst R2, 2        // Expected count
JumpIfEq R1, R2, skip_default
  // Evaluate default expression
  LoadConst R3, "Hello"
  Move R3, greeting_reg
skip_default:
LoadArg R4, 1          // greeting (or use R3)
```

**Fallback Strategy**: Initially fall back to interpreter for functions with defaults. Implement in Week 5-6 after basic function calls work.

### Variadic Parameters (QEP-034)

**Challenge**: `*args` packs remaining arguments into an Array at runtime.

**Bytecode Strategy**:
```quest
fun sum(*numbers)
    # numbers is an Array
end
```

Compiled to:
```rust
// Pack varargs into Array
ArgCount R0            // How many args provided?
MakeArray R1           // Create empty array
LoadConst R2, 0        // Start from required param count
pack_loop:
  JumpIfGte R2, R0, done_packing
  LoadArg R3, R2       // Get arg at index
  ArrayPush R1, R3     // Append to array
  Add R2, R2, 1        // Increment
  Jump pack_loop
done_packing:
  Move R1, numbers_reg
```

**Fallback Strategy**: Implement varargs packing as special opcode `PackVarargs` in Week 6. Fall back to interpreter until then.

### Named Arguments (QEP-035)

**Challenge**: Arguments can be reordered at call site.

**Bytecode Strategy**:
```quest
greet(name: "Alice", greeting: "Hi")  # Reordered!
```

Two approaches:

**Approach A: Runtime Reordering** (simpler, initially)
- Compile to dictionary of named args
- Runtime matches names to parameter positions
- Higher overhead, but works immediately

**Approach B: Compile-Time Reordering** (optimized)
- Compiler knows function signature
- Reorders arguments at compile time
- Generates positional loads in correct order

**Fallback Strategy**: Start with runtime reordering (Week 7), optimize to compile-time later (Week 11+).

### Keyword Arguments (**kwargs) (QEP-034 Phase 2)

**Challenge**: `**kwargs` collects extra named arguments into Dict.

**Bytecode Strategy**:
```quest
fun connect(host, **options)
    # options = {ssl: true, timeout: 60, ...}
end
```

Compiled to:
```rust
LoadArg R0, 0          // host (required)
MakeDict R1            // Empty dict for options
GetKwargs R2           // Get named args dict from call frame
// Iterate and filter out known params
ForEach R2, key, value:
  // If key not in known params, add to R1
  DictSet R1, key, value
Move R1, options_reg
```

**Fallback Strategy**: Week 8-9 implementation. Requires call frame metadata about named arguments.

### Typed Exceptions (QEP-037)

**Challenge**: Exception hierarchy with type-based catching.

**Bytecode Strategy**:
```quest
try
    risky()
catch e: IndexErr
    handle_index()
catch e: Err
    handle_other()
end
```

Compiled to:
```rust
PushHandler catch1, IndexErr   // Set up first handler
PushHandler catch2, Err         // Set up second handler
  Call risky                    // Protected code
  PopHandler                    // Success, remove handlers
  PopHandler
  Jump after_catch
catch1:
  PopHandler                    // Remove remaining handler
  StoreLocal e, exception_reg   // Bind exception to variable
  Call handle_index
  Jump after_catch
catch2:
  StoreLocal e, exception_reg
  Call handle_other
after_catch:
```

**Fallback Strategy**: Exceptions are complex. Fall back to interpreter until Week 9-10. Requires exception handling table in bytecode.

### Implementation Priority

1. **Week 1-4**: Core opcodes (no modern features)
2. **Week 5**: Default parameters
3. **Week 6**: Varargs (`*args`)
4. **Week 7**: Named arguments (runtime reordering)
5. **Week 8**: Keyword arguments (`**kwargs`)
6. **Week 9-10**: Typed exceptions

Until each feature is implemented, functions using these features will fall back to the interpreter gracefully.

## Implementation Notes

### Key Design Decisions

1. **Architecture: Register-Based** (decided above)
   - Lua-style register VM for better performance
   - Fewer instructions for common operations
   - More natural mapping from AST

2. **Opcode Format**
   - Start simple: `opcode + operand (u32)`
   - Evolve to structured instructions with multiple fields
   - Consider instruction size vs. complexity tradeoffs

3. **Fallback Granularity**
   - Per-instruction fallback (fine-grained) ✅ **Recommended**
   - Per-function fallback (coarse-grained)
   - Maximum flexibility: single unimplemented opcode doesn't break entire function

4. **Performance Monitoring**
   - Track bytecode vs interpreter execution paths
   - Measure speedup as opcodes are implemented
   - Identify hot paths for prioritization

5. **Error Handling**
   - Distinguish between "not implemented" and "actual error"
   - Custom error type hierarchy
   - Graceful degradation without user-visible failures

### Error Handling Design

**Error Type Hierarchy**:
```rust
pub enum VMError {
    // Fallback condition (not a real error)
    NotImplemented {
        opcode: Opcode,
        ip: usize,
        context: String,
    },

    // Actual runtime errors
    RuntimeError {
        message: String,
        backtrace: Vec<StackFrame>,
    },

    // Quest exception (user-triggered)
    QuestException {
        exception_type: String,  // "IndexErr", "TypeErr", etc.
        message: String,
        backtrace: Vec<StackFrame>,
    },

    // VM internal errors (bugs)
    InternalError {
        message: String,
        details: String,
    },
}

pub struct StackFrame {
    function_name: String,
    file: String,
    line: usize,
    column: usize,
    execution_mode: ExecutionMode,  // "bytecode" or "interpreter"
}
```

**Stack Trace Generation**:
- Bytecode frames: Use instruction pointer + debug info table
- Interpreter frames: Use existing AST span information
- Mixed traces: Interleave bytecode and interpreter frames
- Show execution mode in trace for debugging

**Example trace**:
```
Traceback (most recent call last):
  File "test.q", line 10, in main [bytecode]
    result = calculate(x, y)
  File "test.q", line 5, in calculate [interpreter]
    return divide(a, b)
  File "test.q", line 2, in divide [bytecode]
    return a / b
Err: division by zero
```

### Closure Implementation Details

**Upvalue Representation**:
```rust
pub struct Upvalue {
    location: UpvalueLocation,
    closed: Option<Box<Value>>,
}

pub enum UpvalueLocation {
    // Still on stack (open upvalue)
    Open {
        frame_idx: usize,  // Which call frame
        reg_idx: u8,       // Which register in that frame
    },

    // Moved to heap (closed upvalue)
    Closed,  // Value is in `closed` field
}

pub struct Closure {
    function_proto: Rc<FunctionProto>,
    upvalues: Vec<Rc<RefCell<Upvalue>>>,
}
```

**Escape Analysis** (future optimization):
- Analyze which variables need heap allocation
- Keep non-escaping variables in registers only
- Initially: conservative (heap-allocate all captured variables)

**Closure Creation Process**:
```rust
// Week 7: Simple functions (no upvalues)
MakeClosure { dest, proto_idx }  // Just copy prototype

// Week 8: Closures with upvalues
MakeClosure { dest, proto_idx }
CaptureLocal { closure, local_reg }  // Capture parent local
CaptureUpvalue { closure, upvalue_idx }  // Capture parent upvalue
```

**Compatibility with Quest's Current Closures**:
- Quest already has closure support in interpreter
- Bytecode must maintain same semantics
- Test: Every closure test must pass in both modes

### Migration Path

**Phase A: Foundation** (Weeks 1-2)
- Set up VM data structures
- Implement 5-10 basic opcodes
- Build compiler skeleton with fallback support
- Verify AST interpreter still works

**Phase B: Core Features** (Weeks 3-6)
- Add control flow opcodes
- Implement function calls (without closures)
- Gradually reduce fallback usage
- Measure performance improvements

**Phase C: Advanced Features** (Weeks 7-10)
- Implement closure support
- Add exception handling
- Optimize hot paths
- Comprehensive testing

**Phase D: Optimization** (Ongoing)
- Profile and optimize bytecode
- Reduce interpreter fallbacks to <5%
- Consider JIT compilation for hot functions
- Benchmark against other languages

### Testing Requirements

- **Correctness**: Every bytecode operation must match interpreter behavior
- **Coverage**: Test all opcodes individually and in combination
- **Regression**: Ensure existing Quest code continues to work
- **Performance**: Measure and track speedup for common operations
- **Fallback**: Verify graceful degradation for unimplemented features

### Edge Cases and Gotchas

**1. Recursive Fallback**
```quest
# What if bytecode calls interpreter which calls bytecode?
fun bytecode_func()
    unimplemented_feature()  # Falls back to interpreter
end

fun interp_func()
    bytecode_func()  # Interpreter calls bytecode
end
```

**Solution**: Track execution mode in call stack. Allow seamless transitions. Test thoroughly.

**2. Mid-Function Fallback**
```quest
fun mixed()
    let x = 2 + 3      # Bytecode: works
    let y = make_closure()  # Fallback triggers here
    x + y()            # Resume bytecode?
end
```

**Solution**: Fallback executes rest of function in interpreter. Don't resume bytecode after fallback in same function. Simpler and safer.

**3. Exception During Fallback**
```quest
try
    bytecode_func()  # Falls back to interpreter
                     # Interpreter throws exception
catch e: Err
    puts(e.stack())  # What does stack trace show?
end
```

**Solution**: Stack trace shows mixed frames (bytecode + interpreter). Clearly mark execution mode per frame.

**4. Module Loading**
```quest
use "mymodule"  # Is module compiled to bytecode?
```

**Solution**:
- Phase A-B: All modules use interpreter
- Phase C: Optionally compile modules to bytecode
- Cache bytecode on disk (future: `.qc` files like Python's `.pyc`)

**5. AST Cache Memory Overhead**

For large programs, storing full AST for unimplemented opcodes consumes memory.

**Solution**:
- Store AST node IDs + reference to original parse tree (not full clone)
- Or: Store source span + re-parse on demand (slower but lower memory)
- Trade-off: Memory vs fallback speed

**6. Concurrent Execution**

If Quest adds threading later, bytecode VM needs thread safety.

**Solution**: Defer until threading is designed. Keep in mind but don't over-engineer.

### Configuration Options

```rust
pub struct VMConfig {
    // Enable/disable bytecode execution (default: true)
    pub enable_bytecode: bool,

    // Log fallback events for debugging (default: false)
    // Example: "Fallback at IP 42: MakeClosure not implemented"
    pub log_fallbacks: bool,

    // Fail on fallback instead of using interpreter (default: false)
    // IMPORTANT: Dev/test only! Never enable in production
    // Useful for testing bytecode coverage
    pub strict_bytecode: bool,

    // Performance monitoring (default: false)
    // Track: bytecode_time, interpreter_time, fallback_count
    pub track_execution_stats: bool,

    // Maximum AST cache size in MB (default: 100)
    // Limits memory usage for fallback AST storage
    pub max_ast_cache_mb: usize,
}
```

**Command-Line Flags** (to be added):
```bash
quest --force-interp test.q          # Disable bytecode entirely
quest --strict-bytecode test.q       # Fail on unimplemented opcodes
quest --log-fallbacks test.q         # Show fallback events
quest --vm-stats test.q              # Show execution statistics
```

**Environment Variables**:
```bash
QUEST_FORCE_INTERP=1 quest test.q    # Disable bytecode
QUEST_VM_STATS=1 quest test.q        # Enable stats
```

### Debugging and Tooling

**Disassembler Tool**:
```rust
pub fn disassemble(bytecode: &[Instruction]) -> String {
    let mut output = String::new();
    for (ip, instr) in bytecode.iter().enumerate() {
        output.push_str(&format!("{:04} ", ip));
        match instr {
            Instruction::LoadConst { dest, const_idx } =>
                output.push_str(&format!("LOADK    R{} K{}\n", dest, const_idx)),
            Instruction::Add { dest, a, b } =>
                output.push_str(&format!("ADD      R{} R{} R{}\n", dest, a, b)),
            // ... etc
        }
    }
    output
}
```

**Quest API for Introspection**:
```quest
use "std/sys"

# Disassemble a function
fun my_func(x)
    x * 2
end

puts(sys.disassemble(my_func))
# Output:
# 0000 LOADARG  R0 0
# 0001 LOADK    R1 K0    ; 2
# 0002 MUL      R2 R0 R1
# 0003 RETURN   R2

# Check execution mode
puts(sys.execution_mode(my_func))  # "bytecode" or "interpreter"

# Get VM statistics
let stats = sys.execution_stats()
puts("Bytecode: " .. stats.bytecode_time .. "ms")
puts("Interpreter: " .. stats.interpreter_time .. "ms")
puts("Fallbacks: " .. stats.fallback_count)
puts("Coverage: " .. stats.bytecode_coverage .. "%")
```

**Instruction Tracing** (debug builds):
```bash
QUEST_TRACE=1 quest test.q

# Output:
# [TRACE] IP=0000 LOADK R0 K0 (42)
# [TRACE] IP=0001 LOADK R1 K1 (3)
# [TRACE] IP=0002 ADD R2 R0 R1 (45)
# [TRACE] IP=0003 RETURN R2
# [FALLBACK] IP=0004 MakeClosure -> interpreter
```

**Testing Tools**:
```rust
#[cfg(test)]
mod vm_tests {
    // Compare bytecode vs interpreter for all test files
    #[test]
    fn test_bytecode_matches_interpreter() {
        for test_file in glob("test/**/*.q") {
            let code = fs::read_to_string(test_file)?;

            // Run both modes
            let interp_result = run_with_interpreter(&code);
            let bytecode_result = run_with_bytecode(&code);

            // Must match!
            assert_eq!(interp_result, bytecode_result,
                "Mismatch in {}", test_file);
        }
    }
}
```

### Documentation Needs

**User-Facing Documentation**:
1. **Performance Guide** (`docs/performance.md`)
   - When is bytecode used vs interpreter?
   - How to measure and interpret VM stats
   - Expected performance characteristics

2. **Debugging Guide** (`docs/debugging-bytecode.md`)
   - How to disable bytecode for debugging
   - Interpreting mixed stack traces
   - Using disassembler and tracing tools

3. **Configuration Reference** (`docs/configuration.md`)
   - All command-line flags
   - Environment variables
   - VMConfig options

**Developer Documentation**:
1. **Bytecode Format Specification** (`docs/bytecode-format.md`)
   - Complete opcode reference
   - Instruction encoding
   - Calling conventions
   - Exception handling tables

2. **Contributing Guide** (`docs/contributing-opcodes.md`)
   - Step-by-step: Adding a new opcode
   - Testing checklist
   - Performance benchmarking
   - When to use fallback

3. **Architecture Overview** (`docs/vm-architecture.md`)
   - Register allocation strategy
   - Call frame management
   - Upvalue handling
   - GC integration points

## References

- [Crafting Interpreters - Bytecode VM](https://craftinginterpreters.com/chunks-of-bytecode.html)
- [Lua 5.4 VM Design](https://www.lua.org/doc/jucs05.pdf)
- [A No-Frills Introduction to Lua 5.1 VM Instructions](https://www.mcours.net/cours/pdf/info/lua/lua_vm.pdf)
- Python's CPython bytecode implementation
- Ruby's YARV (Yet Another Ruby VM)
- QEP-033: Default Parameters
- QEP-034: Variadic Parameters
- QEP-037: Typed Exceptions

## Open Questions

### 1. Force interpreter-only mode for debugging?
**Answer**: ✅ **Yes** - Add `--force-interp` flag and `QUEST_FORCE_INTERP` env var.

**Rationale**: Essential for isolating bugs. "Is this a bytecode issue or language issue?"

### 2. What percentage of opcodes before making bytecode the default?
**Proposed Answer**: **80% opcode coverage + all control flow** implemented and tested.

**Metrics**:
- Core arithmetic, variables, functions: Must work
- Control flow (if/while/for): Must work
- Basic exceptions: Must work
- Can fall back to interpreter for: Complex closures, advanced features

**Timeline**: End of Phase C (Week 8-10)

### 3. Expose execution mode to Quest code?
**Answer**: ✅ **Yes** - Add `sys.execution_mode(func)` and `sys.execution_stats()`.

**Rationale**: Useful for debugging, profiling, and understanding performance. Transparency builds trust.

### 4. Performance-critical stdlib functions?
**Proposed Answer**: Phase E (post-Phase D), optional **JIT compilation** for hot functions.

**Strategy**:
- Measure: Which stdlib functions are hot paths?
- Optimize: Implement in native Rust (already done for most)
- Future: JIT compile Quest bytecode to native (LLVM, Cranelift)

**Not a priority** for initial bytecode implementation.

### 5. Keep AST interpreter permanently or remove?
**Answer**: ✅ **Keep permanently** (at least for foreseeable future).

**Rationale**:
- **Reference implementation**: Validates bytecode correctness
- **Debugging tool**: Isolate VM bugs
- **Fallback**: Graceful degradation for new features
- **Educational**: Understand language semantics
- **Low cost**: Maintenance burden is minimal

**Recommendation**: Keep but potentially hide behind feature flag in distant future.

### 6. Bytecode versioning and compatibility?
**New Question**: How do we version bytecode format for future compatibility?

**Proposed Answer**:
- **Short term**: No versioning (bytecode is ephemeral, generated at runtime)
- **Medium term**: If we cache bytecode (`.qc` files), add version header
- **Format**: `QUEST<major><minor>` magic bytes (e.g., `QUEST0001`)
- **Compatibility**: Regenerate bytecode if version mismatch

**Not urgent** until Phase D-E.

### 7. Impact on compile times?
**New Question**: Does bytecode compilation slow down startup?

**Preliminary Answer**: Unlikely to be significant.
- Bytecode generation is fast (simpler than optimization passes)
- Trade-off: Slight compile overhead for significant runtime speedup
- Measure in Phase B

### 8. Memory usage compared to interpreter?
**New Question**: Does bytecode VM use more memory than AST interpreter?

**Expected Answer**: Slightly higher, but manageable.
- Bytecode instructions: ~8-12 bytes each
- Constants pool: Shared with interpreter
- AST cache (during migration): Temporary overhead
- Registers: Small, fixed-size per call frame

**Mitigation**: Monitor in Phase A-B, optimize if needed.
