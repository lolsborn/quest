# Quest Implementation Status

This document tracks the current state of Quest language implementation.

## 🎯 Core Language Features

### ✅ Object System
- Everything is an object (`5.plus(5)` works)
- Method calls and member access
- Object metadata: `_str()`, `_rep()`, `_doc()`, `_id()`

### ✅ Data Types
- **Primitives**: num (int/float), bool, str, nil
- **Collections**: Arrays with 34 methods, Dictionaries with full CRUD
- **Functions**: Named functions, lambdas, closures
- **Modules**: Import system with `use` syntax

### ✅ Control Flow
- `if`/`elif`/`else`/`end` blocks
- `while` loops with `break`/`continue`
- `for..in` loops (collections and ranges with `to`/`until`/`step`)

### ✅ Operators
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=` (type-aware)
- Logical: `and`, `or`, `!`
- Bitwise: `&`, `|`, `^`, `<<`, `>>`
- String concat: `..`
- Compound assignment: `+=`, `-=`, `*=`, `/=`, `%=`

## 📦 Standard Library Modules

### ✅ Implemented
- **math** - Trig functions, constants (pi, e), basic math
- **json** - Parse and stringify
- **io** - File operations (read, write, glob, exists)
- **hash** - Cryptographic hashes (md5, sha1, sha256, sha512, crc32)
- **encode** - Base64 encoding/decoding (standard and URL-safe)
- **sys** - System info (argv, platform, version, executable)
- **term** - Terminal colors and formatting
- **test** - Testing framework

### ⚠️ Not Implemented
- Exception handling (`try`/`catch`/`raise`)
- HMAC functions (hmac_sha256, hmac_sha512)
- Type system (`type`, `impl` keywords, type annotations)

## 📋 Known Limitations

1. **If statements are not expressions**:
   ```quest
   # ❌ Doesn't work - can't use if as expression
   let result = "big" if x > 3 else "small"

   # ✅ Works - if as statement (can be one line)
   if x > 3 result = "big" else result = "small" end

   # ✅ Works - use function that returns value
   fun max(a, b) if a > b a else b end end
   ```

2. **Grammar limitations**:
   - Assignment operators don't parse inside loop bodies (use methods like `.push()`)
   - Double negation `!(!x)` not supported

3. **Not yet implemented**:
   - Exception handling (`try`/`catch`/`raise`)
   - Type annotations and type system
   - HMAC cryptographic functions
   - Advanced array methods (flatten, unique, sort_by)