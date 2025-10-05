"""
#Random number generation with cryptographically secure and fast generators.

This module provides explicit random number generators (RNG) for different use cases.
All random operations require creating a generator first.

**Generator Types:**
- `rand.secure()` - Cryptographically secure RNG (ChaCha20-based)
- `rand.fast()` - Fast non-cryptographic RNG (PCG64) for games/simulations
- `rand.seed(value)` - Seeded RNG for reproducible sequences

**Example:**
```quest
use "std/rand"

# Create a secure RNG
let rng = rand.secure()

# Generate random values
let dice = rng.int(1, 6)
let probability = rng.float()
let coin = rng.bool()

# Array operations
let winner = rng.choice(participants)
rng.shuffle(deck)
let sample = rng.sample(population, 10)
```
"""

%fun secure()
"""
## Create cryptographically secure random number generator.

Uses ChaCha20-based PRNG seeded from OS entropy. Suitable for security-sensitive
operations like generating tokens, keys, and salts.

**Returns:** **RNG** - Cryptographically secure random number generator

**Example:**
```quest
let rng = rand.secure()

# Generate secure token
let token = rng.bytes(32)

# Generate session ID
let session_id = rng.int(100000, 999999)
```
"""

%fun fast()
"""
## Create fast non-cryptographic random number generator.

Uses PCG64 algorithm for high performance. About 2-3x faster than secure RNG.
**NOT suitable for cryptography or security.**

**Returns:** **RNG** - Fast random number generator

**Use for:** Games, simulations, procedural generation, Monte Carlo methods

**DO NOT use for:** Tokens, keys, salts, security-sensitive decisions

**Example:**
```quest
let rng = rand.fast()

# Game loop - generate many random values quickly
for i in 0..1000000
    let x = rng.int(0, 800)
    let y = rng.int(0, 600)
    spawn_particle(x, y)
end
```
"""

%fun seed(value)
"""
## Create seeded random number generator for reproducible sequences.

Same seed always produces the same sequence of random values. Useful for testing,
procedural generation, and debugging.

**Parameters:**
- `value` (**Int** or **Str**) - Seed value

**Returns:** **RNG** - Seeded random number generator

**Example:**
```quest
# Same seed = same sequence
let rng1 = rand.seed(42)
let rng2 = rand.seed(42)

puts(rng1.int(1, 100))  # Same as rng2
puts(rng2.int(1, 100))  # Same as rng1

# String seeds for procedural generation
let dungeon_rng = rand.seed("level_1")
let width = dungeon_rng.int(10, 20)  # Always same for "level_1"
```
"""

# =============================================================================
# RNG Object Methods
# =============================================================================

# The following methods are available on RNG objects returned by
# rand.secure(), rand.fast(), and rand.seed().
# All RNG types have identical APIs.

# rng.int(min, max)
"""
Generate random integer in range [min, max] (inclusive).

**Parameters:**
- `min` (**Int**) - Minimum value (inclusive)
- `max` (**Int**) - Maximum value (inclusive)

**Returns:** **Int** - Random integer in [min, max]

**Raises:** Error if min > max

**Example:**
```quest
let rng = rand.secure()
let dice = rng.int(1, 6)        # 1-6 inclusive
let port = rng.int(1024, 65535)
```
"""

# rng.float() or rng.float(min, max)
"""
Generate random float.

**Variants:**
- `float()` - Returns float in [0.0, 1.0)
- `float(min, max)` - Returns float in [min, max)

**Parameters:**
- `min` (**Int** or **Float**) - Minimum value (inclusive)
- `max` (**Int** or **Float**) - Maximum value (exclusive)

**Returns:** **Float** - Random floating-point number

**Example:**
```quest
let rng = rand.secure()
let probability = rng.float()           # 0.0 to 1.0
let temp = rng.float(-10.0, 40.0)       # -10 to 40
```
"""

# rng.bool()
"""
Generate random boolean (50/50 chance).

**Returns:** **Bool** - Random true or false

**Example:**
```quest
let rng = rand.secure()
if rng.bool()
    puts("Heads!")
else
    puts("Tails!")
end
```
"""

# rng.bytes(n)
"""
Generate n random bytes.

**Parameters:**
- `n` (**Int**) - Number of bytes to generate

**Returns:** **Bytes** - Random bytes

**Example:**
```quest
let rng = rand.secure()
let salt = rng.bytes(16)
let token = rng.bytes(32)
```
"""

# rng.choice(array)
"""
Pick random element from array.

**Parameters:**
- `array` (**Array**) - Array to choose from

**Returns:** Random element from array

**Raises:** Error if array is empty

**Example:**
```quest
let rng = rand.secure()
let colors = ["red", "green", "blue"]
let color = rng.choice(colors)

let winner = rng.choice(participants)
```
"""

# rng.shuffle(array)
"""
Shuffle array in place using Fisher-Yates algorithm.

**Parameters:**
- `array` (**Array**) - Array to shuffle (will be modified)

**Returns:** **Nil**

**Note:** This method mutates the array.

**Example:**
```quest
let rng = rand.secure()
let deck = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
rng.shuffle(deck)
puts(deck)  # Shuffled order
```
"""

# rng.sample(array, k)
"""
Sample k random elements from array (without replacement).

Returns a new array with k randomly selected elements. Each element can only
appear once in the result (sampling without replacement).

**Parameters:**
- `array` (**Array**) - Array to sample from
- `k` (**Int**) - Number of elements to sample

**Returns:** **Array** - New array with k random elements

**Raises:** Error if k > array length

**Example:**
```quest
let rng = rand.secure()
let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let lottery = rng.sample(numbers, 3)  # Pick 3 unique numbers
puts(lottery)  # e.g., [7, 2, 9]
```
"""
