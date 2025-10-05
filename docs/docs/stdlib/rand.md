# Random Number Generation

The `std/rand` module provides cryptographically secure and fast random number generation with an explicit, generator-first API.

## Import

```quest
use "std/rand"
```

## Philosophy

Quest's random number generation requires explicitly creating a generator first. This design:
- Prevents hidden global state
- Forces intentional choice between secure and fast RNG
- Makes code more testable with seeded generators
- Provides clear security guarantees

## Generator Types

### `rand.secure()` - Cryptographically Secure RNG

Creates a cryptographically secure random number generator using ChaCha20 algorithm.

**Use for:** Security tokens, session IDs, API keys, salts, general-purpose random values

**Returns:** RNG object (crypto-secure)

**Example:**
```quest
use "std/rand"

let rng = rand.secure()
let token = rng.bytes(32)
let session_id = rng.int(100000, 999999)
```

### `rand.fast()` - Fast Non-Cryptographic RNG

Creates a fast random number generator using PCG64 algorithm. About 2-3x faster than secure RNG.

**Use for:** Games, simulations, procedural generation, Monte Carlo methods

**DO NOT use for:** Cryptography, security tokens, passwords, keys

**Returns:** RNG object (fast, non-crypto)

**Example:**
```quest
use "std/rand"

let rng = rand.fast()

# High-performance game loop
for i in 0 to 1000000
    let x = rng.int(0, 800)
    let y = rng.int(0, 600)
    spawn_particle(x, y)
end
```

### `rand.seed(value)` - Seeded RNG for Reproducibility

Creates a seeded random number generator for reproducible sequences. Same seed always produces the same sequence.

**Parameters:**
- `value` - Seed value (Int or Str)

**Use for:** Testing, procedural generation, debugging, deterministic simulations

**Returns:** RNG object (seeded, reproducible)

**Example:**
```quest
use "std/rand"

# Same seed = same sequence
let rng1 = rand.seed(42)
let rng2 = rand.seed(42)

puts(rng1.int(1, 100))  # e.g., 57
puts(rng2.int(1, 100))  # Same: 57

# String seeds for procedural generation
let dungeon_rng = rand.seed("level_1")
let width = dungeon_rng.int(10, 20)  # Always same for "level_1"
```

## RNG Methods

All RNG objects (secure, fast, seeded) support the same methods:

### `rng.int(min, max)` - Random Integer

Generate random integer in range [min, max] (both inclusive).

**Parameters:**
- `min` - Minimum value (Int)
- `max` - Maximum value (Int)

**Returns:** Random integer (Int)

**Raises:** Error if min > max

**Example:**
```quest
let rng = rand.secure()
let dice = rng.int(1, 6)           # 1-6 inclusive
let port = rng.int(1024, 65535)    # Random port number
let temperature = rng.int(-10, 40)  # Can be negative
```

### `rng.float()` / `rng.float(min, max)` - Random Float

Generate random floating-point number.

**Variants:**
- `rng.float()` - Returns float in [0.0, 1.0)
- `rng.float(min, max)` - Returns float in [min, max)

**Parameters:**
- `min` - Minimum value (Int or Float)
- `max` - Maximum value (Int or Float)

**Returns:** Random float (Float)

**Example:**
```quest
let rng = rand.secure()

let probability = rng.float()           # 0.0 to 1.0
let temperature = rng.float(-10.0, 40.0)
let angle = rng.float(0.0, 360.0)
```

### `rng.bool()` - Random Boolean

Generate random boolean with 50/50 probability.

**Returns:** Random boolean (Bool)

**Example:**
```quest
let rng = rand.secure()

# Coin flip
if rng.bool()
    puts("Heads!")
else
    puts("Tails!")
end

# Random spawn
let should_spawn_enemy = rng.bool()
```

### `rng.bytes(n)` - Random Bytes

Generate n random bytes.

**Parameters:**
- `n` - Number of bytes to generate (Int)

**Returns:** Random bytes (Bytes)

**Example:**
```quest
use "std/rand"
use "std/encoding/hex"

let rng = rand.secure()

# Generate salt for password hashing
let salt = rng.bytes(16)

# Generate API token
let token_bytes = rng.bytes(32)
let token = hex.encode(token_bytes)
puts("API Token: " .. token)
```

### `rng.choice(array)` - Random Element

Pick a random element from an array.

**Parameters:**
- `array` - Array to choose from (Array)

**Returns:** Random element from array

**Raises:** Error if array is empty

**Example:**
```quest
let rng = rand.secure()

let colors = ["red", "green", "blue", "yellow"]
let random_color = rng.choice(colors)

let participants = ["Alice", "Bob", "Charlie", "Diana"]
let winner = rng.choice(participants)
puts("Winner: " .. winner)
```

### `rng.shuffle(array)` - Shuffle Array

Shuffle array in place using the Fisher-Yates algorithm.

**Parameters:**
- `array` - Array to shuffle (Array, will be modified)

**Returns:** Nil

**Note:** This method mutates the array.

**Example:**
```quest
let rng = rand.secure()

let deck = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
rng.shuffle(deck)
puts(deck)  # [7, 2, 9, 1, 5, 3, 10, 6, 4, 8]

# Deal cards
for i in 0 to 4
    puts("Card: " .. deck[i])
end
```

### `rng.sample(array, k)` - Random Sample

Sample k random elements from array without replacement (each element appears at most once).

**Parameters:**
- `array` - Array to sample from (Array)
- `k` - Number of elements to sample (Int)

**Returns:** New array with k random elements (Array)

**Raises:** Error if k > array length

**Example:**
```quest
let rng = rand.secure()

# Lottery numbers
let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let lottery = rng.sample(numbers, 3)
puts(lottery)  # [7, 2, 9] (all unique)

# Random subset
let population = ["A", "B", "C", "D", "E"]
let subset = rng.sample(population, 2)
```

## Complete Examples

### Game Enemy Spawning

```quest
use "std/rand"

fun spawn_enemy()
    let rng = rand.fast()  # Fast RNG for game loop

    let enemy_type = rng.choice(["goblin", "orc", "troll", "dragon"])
    let x = rng.int(0, 800)
    let y = rng.int(0, 600)
    let health = rng.int(50, 150)
    let has_shield = rng.bool()

    {
        "type": enemy_type,
        "x": x,
        "y": y,
        "health": health,
        "shield": has_shield
    }
end

# Spawn 10 enemies
let enemies = []
for i in 0 to 9
    enemies.push(spawn_enemy())
end
```

### Secure Token Generation

```quest
use "std/rand"
use "std/encoding/hex"

fun generate_api_token()
    let rng = rand.secure()  # Crypto-secure for tokens
    let token_bytes = rng.bytes(32)
    hex.encode(token_bytes)  # 64-character hex string
end

let api_token = generate_api_token()
puts("API Token: " .. api_token)
# API Token: 3f8b2a9c1e4d5f6a7b8c9d0e1f2a3b4c...
```

### Testing with Seeded RNG

```quest
use "std/rand"
use "std/test"

fun calculate_damage(attacker_level, rng)
    let base = attacker_level * 10
    let variation = rng.int(-5, 5)
    base + variation
end

test.describe("damage calculation", fun ()
    test.it("is deterministic with seed", fun ()
        let rng1 = rand.seed(42)
        let damage1 = calculate_damage(5, rng1)

        let rng2 = rand.seed(42)
        let damage2 = calculate_damage(5, rng2)

        test.assert_eq(damage1, damage2, nil)
    end)
end)
```

### Procedural World Generation

```quest
use "std/rand"

fun generate_world(seed_name)
    let rng = rand.seed(seed_name)

    let world_size = rng.int(50, 100)
    let num_cities = rng.int(5, 10)
    let terrain_types = ["plains", "forest", "mountain", "desert", "water"]

    let cities = []
    for i in 0 to num_cities - 1
        let city = {
            "name": "City_" .. i,
            "x": rng.int(0, world_size),
            "y": rng.int(0, world_size),
            "terrain": rng.choice(terrain_types),
            "population": rng.int(1000, 10000)
        }
        cities.push(city)
    end

    {"size": world_size, "cities": cities}
end

# Same seed = same world
let world1 = generate_world("world_001")
let world2 = generate_world("world_001")
# world1 and world2 are identical
```

### Monte Carlo Simulation

```quest
use "std/rand"
use "std/math"

fun estimate_pi(iterations)
    let rng = rand.fast()  # Fast RNG for many iterations
    let inside_circle = 0

    for i in 0 to iterations - 1
        let x = rng.float()
        let y = rng.float()

        # Check if point is inside quarter circle
        if (x * x) + (y * y) <= 1.0
            inside_circle = inside_circle + 1
        end
    end

    # Pi = 4 * (points inside circle / total points)
    (inside_circle / iterations) * 4.0
end

let pi_estimate = estimate_pi(1000000)
puts("Pi estimate: " .. pi_estimate)
puts("Actual pi: " .. math.pi)
```

### Shuffling and Dealing Cards

```quest
use "std/rand"

fun create_deck()
    let suits = ["♠", "♥", "♦", "♣"]
    let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    let deck = []

    for suit in suits
        for rank in ranks
            deck.push(rank .. suit)
        end
    end

    deck
end

let deck = create_deck()
let rng = rand.secure()
rng.shuffle(deck)

# Deal poker hand (5 cards)
let hand = []
for i in 0 to 4
    hand.push(deck[i])
end
puts("Your hand: " .. hand)

# Or use sample
let hand2 = rng.sample(deck, 5)
puts("Another hand: " .. hand2)
```

### Random Selection for A/B Testing

```quest
use "std/rand"

fun assign_test_group(user_id)
    # Use user ID as seed for consistent assignment
    let rng = rand.seed(user_id)

    let groups = ["control", "variant_a", "variant_b"]
    rng.choice(groups)
end

let group = assign_test_group("user_12345")
puts("Assigned to: " .. group)
# Same user always gets same group
```

### Random Password Generator

```quest
use "std/rand"

fun generate_password(length)
    let rng = rand.secure()  # Secure for passwords

    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    let char_array = chars.split("")  # Convert to array

    let password = ""
    for i in 0 to length - 1
        password = password .. rng.choice(char_array)
    end

    password
end

let pwd = generate_password(16)
puts("Password: " .. pwd)
```

## Security Considerations

### When to Use Secure RNG

Use `rand.secure()` for:
- **Cryptographic operations** - Keys, tokens, salts, IVs
- **Session management** - Session IDs, CSRF tokens
- **Security decisions** - Random delays, challenge generation
- **Password generation** - Random passwords, PINs
- **General-purpose** - When in doubt, use secure

### When to Use Fast RNG

Use `rand.fast()` for:
- **Games** - Enemy spawns, loot drops, damage variation
- **Simulations** - Physics, Monte Carlo, statistical sampling
- **Procedural generation** - Terrain, dungeons, noise (non-security)
- **Performance-critical loops** - Millions of iterations

**Never use `rand.fast()` for security-sensitive operations!**

### When to Use Seeded RNG

Use `rand.seed()` for:
- **Testing** - Reproducible test cases
- **Procedural generation** - Same seed = same world/level
- **Debugging** - Reproduce bugs deterministically
- **A/B testing** - Consistent user assignments

## Performance Characteristics

| Operation | Secure RNG | Fast RNG | Speedup |
|-----------|-----------|----------|---------|
| `int()` | ~50ns | ~20ns | 2.5x |
| `float()` | ~40ns | ~15ns | 2.7x |
| `bytes(32)` | ~500ns | ~200ns | 2.5x |
| `choice(100)` | ~60ns | ~25ns | 2.4x |
| `shuffle(1000)` | ~35μs | ~15μs | 2.3x |

**Recommendation:** Use `rand.secure()` by default. Only switch to `rand.fast()` if profiling shows RNG is a bottleneck.

## Comparison with Other Languages

### Python

```python
import random
import secrets

# Python's random is NOT crypto-secure!
random.randint(1, 10)      # Quest: rand.fast().int(1, 10)
random.random()            # Quest: rng.float()

# Need secrets module for security
secrets.randbelow(100)     # Quest: rand.secure().int(0, 99)
```

**Quest advantage:** Secure by default, clear distinction.

### JavaScript

```javascript
Math.random()                    // Quest: rng.float()
Math.floor(Math.random() * 10)  // Quest: rng.int(0, 9)

// Crypto RNG requires Web Crypto API
crypto.getRandomValues(array)    // Quest: rand.secure().bytes(32)
```

**Quest advantage:** Unified API, both secure and fast options.

### Rust

```rust
use rand::thread_rng;

let mut rng = thread_rng();     // Quest: let rng = rand.secure()
rng.gen_range(1..=10);          // Quest: rng.int(1, 10)
```

**Quest matches Rust:** Explicit generator creation.

## Notes

- All RNG objects are stateful - each call advances the internal state
- RNG objects are cloneable but share the same underlying state (via `Rc<RefCell<>>`)
- Secure and seeded RNGs use ChaCha20 algorithm
- Fast RNG uses PCG64 algorithm
- Empty arrays raise errors in `choice()`
- Sample size cannot exceed array length
- `shuffle()` modifies the array in place
- Seeded RNGs are deterministic across platforms
- Default recommendation: use `rand.secure()` unless you have specific performance needs
