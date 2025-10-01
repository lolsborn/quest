# Quest Implementation Status

This document tracks which features from `docs/*.md` are implemented vs documented but not yet working.

## ✅ Fully Implemented

### From `obj.md`:
- ✅ Everything is an object (`5.plus(5)` works)
- ✅ `obj._str()` - string representation
- ✅ `obj._rep()` - REPL representation
- ✅ `obj._doc()` - documentation strings
- ✅ `obj._id()` - unique object IDs
- ✅ Method calls: `obj.method(args)`
- ✅ Member access: `obj.method` returns QFun object
- ✅ Method metadata: `obj.method._doc()` works

### Modules System:
- ✅ Module imports: `use module` syntax
- ✅ Module file imports: `use "path/to/file.q" as name`
- ✅ Built-in modules: math, json, io, hash (partial), **sys**
- ✅ Module member access: `module.member`
- ✅ Module method calls: `module.method(args)`
- ✅ User-defined modules with exported state
- ✅ Module search paths via `os.search_path`

### System Module (`sys`):
- ✅ **sys.argc** - Command-line argument count
- ✅ **sys.argv** - Command-line argument array
- ✅ **sys.version** - Quest version string (from Cargo.toml)
- ✅ **sys.platform** - OS platform (darwin, linux, win32, etc.)
- ✅ **sys.executable** - Path to Quest executable
- ✅ **sys.builtin_module_names** - Array of built-in module names
- ✅ Automatically injected into script scope (no import needed)

### Built-in Functions:
- ✅ `puts(...)` - Print with newline
- ✅ `print(...)` - Print without newline
- ✅ `fmt(template, ...args)` - Format strings with positional arguments
- ✅ Math module: `pi`, `e`, `abs`, `sin`, `cos`, `tan`, `sqrt`, `pow`, `log`, `exp`, `floor`, `ceil`, `round`
- ✅ JSON module: `stringify`, `parse`
- ✅ IO module: `read_file`, `write_file`, `glob`, `exists`
- ⚠️ Hash module: Functions defined but not yet implemented (md5, sha1, sha256, sha512, hmac_sha256, hmac_sha512, crc32)

### From `control_flow.md`:
- ✅ Block if/elif/else/end
- ❌ Inline if: `value if condition else other_value` - NOT IMPLEMENTED (grammar doesn't support it)
- ❌ While loops: `while condition ... end` - NOT IMPLEMENTED
- ✅ `.each` iteration for arrays and dictionaries

### From `loops.md`:
- ✅ `for..in` loops with collections (arrays, dicts)
- ✅ `for..in` loops with numeric ranges (`to` keyword - inclusive)
- ✅ `for..in` loops with numeric ranges (`until` keyword - exclusive)
- ✅ `for..in` loops with `step` clause
- ✅ `break` statement - exits current loop
- ✅ `continue` statement - skips to next iteration
- ❌ `while` loops - NOT IMPLEMENTED

### From `string.md`:
- ✅ **String Interpolation: FULLY IMPLEMENTED**
  - ✅ F-strings: `f"Hello {name}"` - automatic variable interpolation from scope
  - ✅ `.fmt()` method: `"Value: {}".fmt(x)` - positional args with format specifiers
  - ✅ Rust-style format specifiers: `:.2` (precision), `:x` (hex), `:b` (binary), `:o` (octal)
  - ✅ Width and alignment: `:5`, `:<5`, `:>5`, `:^5`, `:05`
  - ✅ Sign control: `:+`, `: ` (space for positive)
  - ✅ Alternate forms: `:#x` (0x prefix), `:#b` (0b prefix), `:#o` (0o prefix)
- ✅ String literals: `"text"` (plain strings do NOT interpolate)
- ✅ Multi-line strings: `"""text"""`
- ✅ **String methods: FULLY IMPLEMENTED (all documented methods)**
  - **Case conversion**: capitalize(), lower(), upper(), title()
  - **Trimming**: ltrim(), rtrim(), trim()
  - **Query/check**: count(), endswith(), startswith(), len()
  - **Type checks**: isalnum(), isalpha(), isascii(), isdigit(), isnumeric(), isdecimal(), islower(), isupper(), isspace(), istitle()
  - **Formatting**: expandtabs([tabsize]), encode([encoding])
  - **Comparison**: eq(), neq()
  - **String building**: concat(), fmt(...args)

### From `types.md` and `arrays.md`:
- ✅ Core types: obj, fun, str, num, nil, bool
- ✅ Numbers work as integers and floats
- ✅ **Arrays: FULLY IMPLEMENTED** `[1, 2, 3]` with comprehensive methods (138 tests passing)
  - Basic operations: `len`, `push`, `pop`, `shift`, `unshift`, `get`, `first`, `last`
  - Utility methods: `reverse`, `slice`, `concat`, `join`, `contains`, `index_of`, `count`, `empty`, `sort`
  - Higher-order functions: `map`, `filter`, `reduce`, `any`, `all`, `find`, `find_index`, `each`
  - Negative indexing: `arr[-1]` gets last element
  - Deep equality comparison for arrays
- ✅ **Dictionaries: FULLY IMPLEMENTED** `{"key": value}` with all methods
  - ✅ Bracket access: `dict["key"]` for reading and writing
  - ✅ Basic methods: `len`, `keys`, `values`, `has`
  - ✅ Access methods: `get(key)`, `get(key, default)` - returns nil or default if not found
  - ✅ Immutable operations: `set(key, value)`, `remove(key)` - return new dicts
  - ✅ Higher-order: `each(fn)` - iterate over key-value pairs

## ⚠️ Documented But Not Implemented

### From `obj.md`:
- ❌ `obj.cls()` - exists but not callable as method (trait method only)
- ❌ `obj.type()` - not implemented
- ❌ `obj.new()` - not implemented
- ❌ `obj.del()` - not implemented
- ❌ `obj.is(type)` - exists in trait but not callable

### From `types.md`:
- ❌ Array type annotations: `arr{str}: lines`
- ❌ Multi-dimensional arrays: `arr.dim(3,3)`
- ❌ Complex types with `type` keyword
- ❌ Implementations with `impl` keyword
- ❌ Type checking with `.is()`

### From `string.md`:
- ✅ String concatenation operator: `"hello" .. "world"`
- ✅ String interpolation (f-strings, .fmt(), fmt() function all implemented)

### From `control_flow.md`:
- ❌ For loops
- ❌ `break` and `continue` statements

### Operators:
- ✅ Infix operators: `5 + 5`, `10 - 3`, `4 * 2`, `8 / 2`, `10 % 3`
- ✅ **Comparison operators: TYPE-AWARE** `x > 5`, `a == b`, `a != b`, `x >= 5`, `x <= 5`
  - Works with numbers, strings (lexicographic), booleans, arrays (deep equality)
  - Fixed bug where comparisons only worked on numbers
- ✅ **Logical operators**: `a and b`, `a or b`, `!a` (NOT with `!` prefix)
  - Uses keywords `and`/`or` (NOT `&&`/`||` like C-style languages)
  - Unary NOT uses `!` prefix: `!true`, `!false`
  - ⚠️ **Limitation**: Double negation `!(!x)` doesn't parse - grammar doesn't support nested unary operators
- ✅ Bitwise operators: `a & b`, `a | b`, `a ^ b`, `a << 2`, `a >> 2`
- ✅ String concatenation: `"hello" .. "world"`
- ✅ **Compound Assignment Operators: FULLY IMPLEMENTED**
  - ✅ `+=` - Addition/concatenation (works with numbers, strings, arrays)
  - ✅ `-=` - Subtraction (numbers only)
  - ✅ `*=` - Multiplication (numbers only)
  - ✅ `/=` - Division (numbers only)
  - ✅ `%=` - Modulo (numbers only)
  - ✅ Works with variables, array elements, and dict values

### Variables & Functions:
- ✅ Variable declaration: `let x = 5`
- ✅ Variable assignment: `x = 10` (requires prior `let`)
- ✅ Function definitions: `fun name(args) ... end`
- ✅ Function calls to user-defined functions
- ✅ Closures and captured variables
- ✅ Anonymous functions/lambdas: `fun(x) x * 2 end`
- ❌ Type annotations: `num: x = 5`

## 📝 Syntax Differences from Docs

### What Actually Works:

```quest
# Variables
let x = 5
x = 10  # requires prior let

# Operators (both method calls and infix work)
let sum = x + 5  # or x.plus(5)
let product = x * 2  # or x.times(2)
let is_bigger = x > 3  # or x.gt(3)

# Control flow
if x > 10
    puts("big")
elif x > 5
    puts("medium")
else
    puts("small")
end

# While loops
let i = 0
while i < 5
    puts(i)
    i = i + 1
end

# Logical operators
let result = (x > 5) and (y < 10)
let flag = true or false
let negated = !true

# Arrays and iteration
let arr = [1, 2, 3, 4, 5]
puts(arr[0])  # Access by index
arr.each(fun(x) puts(x) end)  # Iterate

# Dictionaries
let d = {"name": "Quest", "version": 1}
puts(d["name"])

# Functions
fun add(a, b)
    a + b
end
puts(add(5, 3))

# Anonymous functions
let double = fun(x) x * 2 end
puts(double(5))

# Modules
use math
puts(math.pi)

use "mymodule.q" as mymod
mymod.some_function()

# Strings
let msg = "hello"
puts(msg.upper())
puts(msg.len())

# Object metadata
puts(msg.upper._doc())
puts(x._id())
```

## 🎯 Next Implementation Priorities

Based on documentation coverage and practical needs:

### High Priority (Most Useful)
1. **For loops** - `for item in collection ... end` syntax (arrays and dicts are complete, need iteration)
2. **Break and continue** - Loop control statements
3. **Exception handling** - `try`/`catch`/`raise` (comprehensive spec exists)

### Medium Priority
5. **Hash module functions** - Implement md5, sha1, sha256, etc. (stub exists)
6. **Bitwise compound assignments** - `&=`, `|=`, `^=`, `<<=`, `>>=` (if needed)

### Lower Priority (Type System)
8. **Type annotations** - Optional but documented: `num: x = 5`
9. **Type system enhancements** - `obj.is(type)`, `obj.cls()` as callable method
10. **Custom types** - `type` and `impl` keywords

## 📊 Current Test Coverage

- **Math tests**: 19 passing (basic), 38 passing (trig) = **57 total**
- **String tests**: 62 passing (basic), 18 passing (interpolation) = **80 total**
- **Array tests**: 34 passing (comprehensive) = **34 total**
- **Dictionary tests**: 34 passing (comprehensive) = **34 total**
- **Boolean tests**: 44 passing (logical operators, comparisons, conditionals) = **44 total**
- **Module tests**: 33 passing (module system, imports, exports) = **33 total**
- **Operator tests**: 19 passing (compound assignment operators) = **19 total**
- **Function tests**: 19 passing (basic functions, scoping, recursion) = **19 total**
- **Lambda tests**: 21 passing (anonymous functions, closures, higher-order) = **21 total**
- **Loop tests**: 26 passing (for loops, ranges, arrays, dicts, nesting, break, continue) = **26 total**
- **Grand total**: **358 tests, 100% passing**

### Test Organization

**Automated Test Suite** (`test/run.q`):
```
test/
├── math/         # 57 tests - Arithmetic, trigonometry, special values
├── string/       # 75 tests - String methods, interpolation, formatting
├── arrays/       # 34 tests - Array operations, higher-order functions
├── dict/         # 34 tests - Dictionary operations, iteration
├── bool/         # 44 tests - Boolean logic, comparisons
├── modules/      # 33 tests - Module imports, aliasing, JSON, term
├── operators/    # 19 tests - Compound assignment operators
└── functions/    # 40 tests - User functions, lambdas, closures, recursion
```

**Manual Test Files** (see [`test/MANUAL_TESTS.md`](test/MANUAL_TESTS.md)):
- `del_test.q` - Variable deletion with `del` statement
- `glob_test.q` - IO module glob pattern matching
- `hash_test.q` - Cryptographic hash functions (not yet implemented)
- `os_test.q` - OS operations (filesystem side effects)
- `term_test.q` - Terminal colors and ANSI codes (visual inspection)

**Test Files Not Yet Integrated:**
- `test/io/basic.q` - IO operations (needs file cleanup support)
- `test/sys/basic.q` - System module (sys not available in module scope)
- `test/loops/while.q` - While loops (causes timeout, possible infinite loop bug)


## Potential Issues / Notes

## 🔧 Code Organization & Refactoring

### Completed Module Extractions

**src/json_utils.rs** (2025-10-01)
- Extracted JSON conversion utilities from main.rs
- Functions: `json_to_qvalue()`, `qvalue_to_json()`
- Reduced main.rs by 61 lines
- All JSON functionality working (tested via module tests)    
