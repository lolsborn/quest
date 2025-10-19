# Types

Quest features a rich type system that blends ideas from multiple language paradigms. Like Ruby and Smalltalk, everything in Quest is an object—even primitive values like numbers and booleans respond to methods. The language borrows Rust's trait-based composition for defining shared behavior without inheritance hierarchies. Structs can have both static class-level methods (like Python's `@classmethod`) and instance methods with implicit `self` access. User-defined types use reference semantics (like Python, Ruby, and JavaScript), allowing mutations to be visible across all references. Types are checked at runtime but can be annotated for clarity.

## Core Types

- **obj** - Base type for all values
- **fun** - Function type
- **str** - String type (always valid UTF-8)
- **bytes** - Binary data type (raw byte sequences)
- **num** - Number type (represents both ints and floats)
- **decimal** - Arbitrary-precision decimal type (see [Decimal Type](../types/decimal.md))
- **nil** - Null/nil type
- **bool** - Boolean type
- **arr** - Array type
- **dict** - Dictionary/map type


## Arrays

Arrays are Quest's general-purpose, dynamic collections. They can contain any mix of types and can be nested for multi-dimensional data.

### Basic Arrays

```quest
# Simple array
let numbers = [1, 2, 3, 4, 5]
numbers.push(6)
puts(numbers)  # [1, 2, 3, 4, 5, 6]

# Mixed types (arrays are heterogeneous)
let mixed = [1, "hello", 3.14, true, nil]

# String array
let lines = ["Hello", "World"]
lines.each(fun (l)
    puts(l)
end)
# Output:
# Hello
# World
```

### Nested Arrays

```quest
# 2D array (nested)
let matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
]

# Access elements
puts(matrix[0][1])  # 2

# Iterate over rows
matrix.each(fun (row)
    let sum = 0
    row.each(fun (col)
        sum = sum + col
    end)
    puts(sum)
end)
# Output:
# 6
# 15
# 24
```

### Arrays vs NDArrays

For numerical computing with large datasets, use the `std/ndarray` module which provides:
- Efficient multi-dimensional arrays
- Matrix operations (transpose, dot product, etc.)
- Broadcasting and reshaping
- Optimized numerical operations

See the [NDArray documentation](../stdlib/ndarray.md) for details.

```quest
use "std/ndarray" as np

# Create a 3x3 matrix
let m = np.zeros([3, 3])

# Matrix operations
let result = m.transpose().dot(m)
```


## User-Defined Types

Quest supports a Rust-inspired type system with structs and traits.

### Type Declarations

Define custom types with fields and methods:

```quest
type Person
    name: Str
    age: Num
    email: Str?  # Optional field (defaults to nil)
end
```

### Creating Instances

Use the `.new()` constructor with positional or named arguments:

```quest
# Positional arguments
let alice = Person.new("Alice", 30, "alice@example.com")

# Named arguments (order doesn't matter)
let bob = Person.new(name: "Bob", age: 25)
let charlie = Person.new(age: 35, name: "Charlie", email: "c@example.com")
```

### Instance Methods

Methods have implicit access to `self`:

```quest
type Point
    pub x: Num
    pub y: Num

    fun distance()
        (((self.x * self.x) + (self.y * self.y)).pow(0.5))
    end

    fun scale(factor)
        Point.new(x: self.x * factor, y: self.y * factor)
    end
end

let p = Point.new(x: 3, y: 4)
puts(p.distance())  # 5.0
```

### Class Methods

Use `fun self.method_name` (Ruby-style) for class-level methods. Class methods are called on the type itself (not instances) and are useful for constructors, factories, and utilities.

**Basic class method:**

```quest
type Point
    pub x: Num
    pub y: Num

    fun self.origin()
        Point.new(x: 0, y: 0)
    end
end

let p = Point.origin()  # Call on type, not instance
```

**Class methods with parameters:**

```quest
type Rectangle
    pub width: Num
    pub height: Num

    fun self.square(side)
        Rectangle.new(width: side, height: side)
    end

    fun self.from_diagonal(diagonal)
        let side = diagonal / 2.0.pow(0.5)
        Rectangle.new(width: side, height: side)
    end
end

let sq = Rectangle.square(5)
let r = Rectangle.from_diagonal(10)
```

**Common patterns - configuration and validation:**

```quest
type Configuration
    pub host: Str
    pub port: Int

    # Factory method with defaults
    fun self.default()
        Configuration.new(host: "localhost", port: 8080)
    end

    # Factory method with validation
    fun self.from_dict(dict)
        if not dict.contains("host")
            raise ValueErr.new("missing 'host'")
        end
        let port = 3000
        if dict.contains("port")
            port = dict["port"]
        end
        Configuration.new(host: dict["host"], port: port)
    end
end

let config1 = Configuration.default()
let config2 = Configuration.from_dict({host: "example.com", port: 443})
```

**Key differences from instance methods:**

| Feature | Instance Method | Class Method |
|---------|-----------------|--------------|
| Declaration | `fun method_name()` | `fun self.method_name()` |
| Called on | Instance: `obj.method()` | Type: `TypeName.method()` |
| Access to `self` | Yes (the instance) | Yes (the type itself) |
| Use case | Instance operations | Construction, factories, utilities |

### Traits

Define interfaces with required methods:

```quest
trait Drawable
    fun draw()
end

type Circle
    pub radius: Num

    impl Drawable
        fun draw()
            "Circle(r=" .. self.radius .. ")"
        end
    end
end

let c = Circle.new(radius: 5)
puts(c.draw())  # Circle(r=5)
```

### Type Introspection

Check types and traits at runtime:

```quest
let p = Point.new(x: 1, y: 2)

# Type checking
if p.is(Point)
    puts("It's a Point!")
end

# Trait checking
if c.does(Drawable)
    c.draw()
end
```

### Immutable Updates

Create modified copies with `.update()`:

```quest
type Point
    pub x: Num
    pub y: Num
end

let p1 = Point.new(x: 1, y: 2)
let p2 = p1.update(x: 5)  # New Point with x=5, y=2
puts(p1.x)  # 1 (unchanged)
puts(p2.x)  # 5
```

