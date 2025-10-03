# Types

Quest features a rich type system that blends ideas from multiple language paradigms. Like Ruby and Smalltalk, everything in Quest is an object—even primitive values like numbers and booleans respond to methods. The language borrows Rust's trait-based composition for defining shared behavior without inheritance hierarchies. Structs can have both static class-level methods (like Python's `@classmethod`) and instance methods with implicit `self` access. Types are checked at runtime but can be annotated for clarity, and all data structures are immutable by default, following functional programming principles.

## Core Types

- **obj** - Base type for all values
- **fun** - Function type
- **str** - String type (always valid UTF-8)
- **bytes** - Binary data type (raw byte sequences)
- **num** - Number type (represents both ints and floats)
- **nil** - Null/nil type
- **bool** - Boolean type
- **arr** - Array type
- **dict** - Dictionary/map type


## Arrays

### String Array

```quest
arr{str}: lines = [
    "Hello",
    "World"
]
lines.each(fun (l)
    puts(l)
end)
# Output:
# "Hello"
# "World"
```

### 2D array
```quest
arr{num} a[3,3] = [
    1, 2, 3;
    4, 5, 6;
    7, 8, 9;
]

a.each(fun (row)
    sum = 0
    row.each(fun (col)
        sum += col
    end)
    puts(sum)
end)
# Output:
# 6
# 15
# 24
```

## Multi Dimensional Matrixes
```quest
arr{num} x = arr.dim(3,3) # 3x3 matrix
puts(x)
# [
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ],[
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ],[
#   0, 0, 0
#   0, 0, 0
#   0, 0, 0
# ]
```

```quest
arr{num} y = arr.dim(num,4,2) # 4x2 matrix
puts(y)
# [
#   0, 0
#   0, 0
#   0, 0
#   0, 0
# ]
```

```quest
arr{num} z = arr.dim(num,2,3) # 2x3 matrix
puts(z)
# [
#   0, 0, 0
#   0, 0, 0
# ]
```


## User-Defined Types

Quest supports a Rust-inspired type system with structs and traits.

### Type Declarations

Define custom types with fields and methods:

```quest
type Person
    str: name
    num: age
    str?: email  # Optional field (defaults to nil)
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
    num: x
    num: y

    fun distance()
        ((self.x * self.x) + (self.y * self.y)) ** 0.5
    end

    fun scale(factor)
        Point.new(x: self.x * factor, y: self.y * factor)
    end
end

let p = Point.new(x: 3, y: 4)
puts(p.distance())  # 5.0
```

### Static Methods

Use `static fun` for class-level methods:

```quest
type Point
    num: x
    num: y

    static fun origin()
        Point.new(x: 0, y: 0)
    end
end

let p = Point.origin()
```

### Traits

Define interfaces with required methods:

```quest
trait Drawable
    fun draw()
end

type Circle
    num: radius

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
let p1 = Point.new(x: 1, y: 2)
let p2 = p1.update(x: 5)  # New Point with x=5, y=2
puts(p1.x)  # 1 (unchanged)
puts(p2.x)  # 5
```

