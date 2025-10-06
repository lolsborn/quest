# Fix for Bug 012: Missing Bitwise Operators

**Status**: ✅ FIXED
**Fixed**: 2025-10-05
**Files Modified**: `src/quest.pest`, `src/main.rs`

## Summary

Added support for bitwise NOT (~) operator. Other bitwise operators (|, &, ^, <<, >>) were already implemented in the grammar and evaluator but not documented.

## Operators Available

All standard bitwise operators are now fully supported:

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `\|` | Bitwise OR | `5 \| 3` | 7 |
| `&` | Bitwise AND | `5 & 3` | 1 |
| `^` | Bitwise XOR | `5 ^ 3` | 6 |
| `<<` | Left shift | `1 << 8` | 256 |
| `>>` | Right shift | `256 >> 2` | 64 |
| `~` | Bitwise NOT | `~5` | -6 |

## Changes Made

### 1. Grammar (`src/quest.pest` line 239)
Added `~` to unary operators:
```pest
unary_op = { "-" | "+" | "~" }
```

### 2. Evaluator (`src/main.rs` lines 1839-1843)
Added bitwise NOT handling in unary operator evaluation:
```rust
"~" => {
    // Bitwise NOT (complement) - only works on integers
    let int_val = value.as_num()? as i64;
    Ok(QValue::Int(QInt::new(!int_val)))
},
```

## Implementation Details

- **Grammar:** Already had bitwise operators except NOT (lines 217-222 in quest.pest)
- **Evaluator:** Already had OR, AND, XOR, shift (lines 1563-1643 in main.rs)
- **Precedence:** Correct (matches C/Rust/Python standard)
  - Highest: `~` (bitwise NOT)
  - `<<` `>>` (shifts)
  - `&` (bitwise AND)
  - `^` (bitwise XOR)
  - Lowest: `|` (bitwise OR)

## Test Coverage

Added comprehensive test: `test/operators/bitwise_test.q`

**29 tests covering:**
- ✓ All 6 operators with basic cases
- ✓ Zero handling
- ✓ Commutative properties
- ✓ Bit masking
- ✓ Self-inverse (XOR)
- ✓ Two's complement (NOT)
- ✓ Combined operations
- ✓ Practical use cases:
  - RGB color packing/unpacking
  - Fast modulo with power of 2
  - Even/odd checking
  - Byte swapping

All tests pass ✅

## Use Cases Now Enabled

1. **Checksums**: Fletcher, Adler, CRC
2. **Color manipulation**: RGB packing/unpacking
3. **Binary protocols**: Network byte order, flags
4. **Hash functions**: Jenkins, FNV
5. **Performance**: Fast modulo for powers of 2
6. **Bit manipulation**: Masking, toggling, clearing bits

## Impact

**No breaking changes** - These are new operators. All existing code continues to work.

This brings Quest's bitwise operation support to parity with C, Rust, Python, Ruby, and JavaScript!
