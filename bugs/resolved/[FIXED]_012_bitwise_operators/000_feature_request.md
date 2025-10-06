# Feature Request: Bitwise Operators

**Status**: 🟡 FEATURE REQUEST

**Reported**: 2025-10-05 (benchmarks implementation session)

**Priority**: MEDIUM - Needed for checksums, hashing, and binary protocols

## Summary

Quest needs bitwise operators for low-level manipulation of integer values. These are standard in virtually all programming languages and essential for checksums, hashing, compression, encryption, and binary protocols.

## Missing Operators

```quest
# Bitwise shift
x << n     # Left shift (multiply by 2^n)
x >> n     # Right shift (divide by 2^n)
x >>> n    # Unsigned right shift (fill with zeros)

# Bitwise logical
x | y      # Bitwise OR
x & y      # Bitwise AND
x ^ y      # Bitwise XOR
~x         # Bitwise NOT (complement)
```

## Current Status

❌ None of these operators exist. Workarounds required for every use.

## Use Cases

### 1. Checksum Calculation (Fletcher/Adler)

```quest
# Fletcher checksum - needs bit shifting and OR
fun fletcher_checksum(data)
    let sum1 = 0
    let sum2 = 0
    # ... calculate sums ...
    (sum2 << 8) | sum1  # Combine into 16-bit checksum
end

# Current workaround: multiply and add
(sum2 * 256) + sum1  # Less clear, more error-prone
```

### 2. RGB Color Manipulation

```quest
# Pack RGB into single integer
let color = (r << 16) | (g << 8) | b

# Unpack RGB from integer
let r = (color >> 16) & 0xFF
let g = (color >> 8) & 0xFF
let b = color & 0xFF

# Current workaround: arithmetic (messy and slow)
let color = r * 65536 + g * 256 + b
let r = (color / 65536) % 256
```

### 3. Binary Protocols

```quest
# Network byte order conversion
fun swap16(n)
    ((n & 0xFF) << 8) | ((n >> 8) & 0xFF)
end

# Bit masking for flags
let flags = 0
flags = flags | FLAG_READ   # Set flag
if (flags & FLAG_WRITE) > 0  # Check flag
```

### 4. Hash Functions

```quest
# Jenkins hash
fun hash(key)
    let h = 0
    let i = 0
    while i < key.len()
        h = h + ord(key[i])
        h = h + (h << 10)  # Multiply by 1024
        h = h ^ (h >> 6)   # Mix bits
        i = i + 1
    end
    h
end
```

### 5. Fast Modulo Powers of 2

```quest
# x % 256 can be optimized to:
x & 0xFF  # Much faster on most CPUs

# x % 1024 can be:
x & 0x3FF
```

## Current Workaround

Use arithmetic operations (slow and unclear):

```quest
# Instead of: (sum2 << 8) | sum1
(sum2 * 256) + sum1

# Instead of: (color >> 16) & 0xFF
((color / 65536) % 256).to_int()

# Instead of: x & 0xFF
x % 256

# No workaround for XOR or NOT!
```

Limitations:
- Slower (arithmetic vs bitwise)
- Less clear intent
- XOR and NOT impossible to emulate efficiently
- Floating point rounding errors possible

## Proposed Syntax

```quest
let a = 0b1010  # Binary literal (bonus feature)
let b = 0xFF    # Already supported (hex literal)

# Shift operators
let x = 1 << 8      # 256
let y = 1024 >> 2   # 256

# Logical operators
let flags = FLAG_A | FLAG_B
let masked = value & 0xFF
let toggled = bits ^ 0xFFFF
let inverted = ~bits
```

## Implementation Notes

Rust already has these operators, should be straightforward to expose:

```rust
// In Quest's operator handling:
BinaryOp::Shl => left << right,      // <<
BinaryOp::Shr => left >> right,      // >>
BinaryOp::BitOr => left | right,     // |
BinaryOp::BitAnd => left & right,    // &
BinaryOp::BitXor => left ^ right,    // ^
UnaryOp::BitNot => !value,           // ~
```

## Operator Precedence

Standard precedence (matching C, Rust, Python):

```
Highest:  ~           (bitwise NOT)
          << >>       (shifts)
          &           (bitwise AND)
          ^           (bitwise XOR)
          |           (bitwise OR)
Lowest:   (comparison operators)
```

## Examples from Other Languages

**C/C++/Rust/Go:**
```c
x << 3      // Left shift
x >> 3      // Right shift
x | y       // OR
x & y       // AND
x ^ y       // XOR
~x          // NOT
```

**Python:**
```python
x << 3      # Left shift
x >> 3      # Right shift
x | y       # OR
x & y       # AND
x ^ y       # XOR
~x          # NOT
```

**JavaScript:**
```javascript
x << 3      // Left shift
x >> 3      // Signed right shift
x >>> 3     // Unsigned right shift
x | y       // OR
x & y       // AND
x ^ y       // XOR
~x          // NOT
```

**Ruby:**
```ruby
x << 3      # Left shift
x >> 3      # Right shift
x | y       # OR
x & y       # AND
x ^ y       # XOR
~x          # NOT
```

All major languages have these operators!

## Test Cases

```quest
# Shift operations
assert (1 << 0) == 1
assert (1 << 1) == 2
assert (1 << 8) == 256
assert (1 << 16) == 65536

assert (256 >> 0) == 256
assert (256 >> 1) == 128
assert (256 >> 8) == 1
assert (255 >> 1) == 127

# Bitwise OR
assert (0b1010 | 0b0101) == 0b1111
assert (0xFF | 0x00) == 0xFF
assert (5 | 3) == 7  # 0101 | 0011 = 0111

# Bitwise AND
assert (0b1010 & 0b0110) == 0b0010
assert (0xFF & 0x0F) == 0x0F
assert (5 & 3) == 1  # 0101 & 0011 = 0001

# Bitwise XOR
assert (0b1010 ^ 0b0110) == 0b1100
assert (0xFF ^ 0xFF) == 0
assert (5 ^ 3) == 6  # 0101 ^ 0011 = 0110

# Bitwise NOT
assert (~0) == -1
assert (~0xFF) == -256  # Two's complement

# Combined operations
assert ((1 << 8) | (1 << 4) | 1) == 273  # 0x111
assert (0xDEADBEEF & 0xFF) == 0xEF
```

## Benefits

1. **Standard feature** - Present in all major languages
2. **Performance** - Bitwise ops are fast CPU instructions
3. **Clarity** - Makes intent clearer than arithmetic workarounds
4. **Enables algorithms** - Checksums, hashing, compression, encryption
5. **Binary protocols** - Network programming, file formats

## Related Features

Could also add:
- Binary literals: `0b1010` (complement to existing `0xFF` hex literals)
- Bit counting: `popcount(n)` - count 1 bits
- Bit rotation: `rotl(n, k)`, `rotr(n, k)`

But the basic operators are the priority.

## Priority

**MEDIUM** because:
- Not blocking basic programming (arithmetic workarounds exist)
- But needed for performance-sensitive code
- Standard feature in all major languages
- Relatively easy to implement (operators already in Rust)
- Would improve Quest's capabilities for systems programming

## Impact on Existing Code

No breaking changes - these are new operators. Existing code continues to work.

The only potential issue is if Quest currently uses `|`, `&`, `^` for other purposes, but a quick check shows they're not used in the syntax.
