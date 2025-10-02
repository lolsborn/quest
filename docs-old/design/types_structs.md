# Types and Structs Design

A practical type system for Quest that balances simplicity with power.

## Philosophy

- **Structs first**: Simple data structures before complex OOP
- **Duck typing**: Type checks at runtime, not compile time
- **Progressive enhancement**: Start simple, add complexity as needed
- **Immutable by default**: Structs are immutable unless explicitly mutable

## Basic Structs

### Defining a Struct

```quest
type Point
    x
    y
end

type Person
    name
    age
    email
end
```

### Creating Instances

```quest
# Using constructor
let p = Point.new(10, 20)
let person = Person.new("Alice", 30, "alice@example.com")

# Using named arguments (optional)
let p = Point.new(x: 10, y: 20)
let person = Person.new(name: "Alice", age: 30, email: "alice@example.com")
```

### Accessing Fields

```quest
let p = Point.new(10, 20)

puts(p.x)  # 10
puts(p.y)  # 20

let person = Person.new("Alice", 30, "alice@example.com")
puts(person.name)   # "Alice"
puts(person.age)    # 30
puts(person.email)  # "alice@example.com"
```

### Immutability

```quest
let p = Point.new(10, 20)

# This creates a NEW point with updated value
let p2 = p.with_x(15)
puts(p.x)   # 10 (original unchanged)
puts(p2.x)  # 15 (new instance)

# Or use the .with() method for multiple fields
let p3 = p.with(x: 15, y: 25)
```

## Methods on Structs

### Instance Methods

```quest
type Point
    x
    y

    # Instance methods
    fun distance_from_origin()
        math.sqrt(self.x * self.x + self.y * self.y)
    end

    fun distance_to(other)
        let dx = self.x - other.x
        let dy = self.y - other.y
        math.sqrt(dx * dx + dy * dy)
    end

    fun move_by(dx, dy)
        Point.new(self.x + dx, self.y + dy)
    end
end

# Usage
let p1 = Point.new(3, 4)
puts(p1.distance_from_origin())  # 5.0

let p2 = Point.new(0, 0)
puts(p1.distance_to(p2))  # 5.0

let p3 = p1.move_by(10, 10)
puts(p3.x, p3.y)  # 13, 14
```

### Static Methods

```quest
type Point
    x
    y

    # Static methods (called on the type itself)
    fun zero()
        Point.new(0, 0)
    end

    fun origin()
        Point.zero()
    end

    fun from_polar(r, theta)
        Point.new(
            r * math.cos(theta),
            r * math.sin(theta)
        )
    end
end

# Usage
let origin = Point.zero()
let p = Point.from_polar(10, math.pi / 4)
```

## Type Checking

### Runtime Type Checks

```quest
type Point
    x
    y
end

let p = Point.new(10, 20)

# Check type
puts(p.is(Point))  # true
puts(p.is(Person)) # false

# Get type name
puts(p.type())     # "Point"

# Type in conditionals
if obj.is(Point)
    puts("It's a point: ({obj.x}, {obj.y})")
elif obj.is(Person)
    puts("It's a person: {obj.name}")
end
```

## Optional Type Annotations

### Field Types (for documentation and validation)

```quest
type Person
    str: name
    num: age
    str: email

    fun is_adult()
        self.age >= 18
    end
end

# Runtime validation on construction
let person = Person.new("Alice", 30, "alice@example.com")  # OK
let bad = Person.new("Bob", "thirty", "bob@test.com")      # Error: age must be num
```

### Method Types

```quest
type Calculator
    value

    fun add(num: n) -> num
        Calculator.new(self.value + n)
    end

    fun multiply(num: n) -> num
        Calculator.new(self.value * n)
    end
end
```

## Nested Structs

```quest
type Address
    street
    city
    state
    zip
end

type Person
    name
    age
    address

    fun full_location()
        "{self.address.city}, {self.address.state}"
    end
end

let addr = Address.new("123 Main St", "New York", "NY", "10001")
let person = Person.new("Alice", 30, addr)

puts(person.address.city)  # "New York"
puts(person.full_location())  # "New York, NY"
```

## Struct Equality

```quest
type Point
    x
    y
end

let p1 = Point.new(10, 20)
let p2 = Point.new(10, 20)
let p3 = Point.new(15, 25)

# Structural equality (compares fields)
puts(p1 == p2)  # true
puts(p1 == p3)  # false

# Identity check
puts(p1._id() == p2._id())  # false (different objects)
```

## Destructuring (Future)

```quest
# Destructure in let
let Point(x, y) = point
puts(x, y)

# Destructure in function parameters
fun print_point(Point(x, y))
    puts("({x}, {y})")
end

# Destructure in for loop
let points = [Point.new(1, 2), Point.new(3, 4)]
for Point(x, y) in points
    puts(x, y)
end
```

## Traits/Interfaces (Advanced)

### Defining Traits

```quest
# A trait defines required methods
trait Drawable
    fun draw()
    fun bounds()
end

trait Movable
    fun move_to(x, y)
end
```

### Implementing Traits

```quest
type Circle
    x
    y
    radius

    impl Drawable
        fun draw()
            puts("Drawing circle at ({self.x}, {self.y})")
        end

        fun bounds()
            {
                x: self.x - self.radius,
                y: self.y - self.radius,
                width: self.radius * 2,
                height: self.radius * 2
            }
        end
    end

    impl Movable
        fun move_to(x, y)
            Circle.new(x, y, self.radius)
        end
    end
end

# Usage
let circle = Circle.new(10, 10, 5)
circle.draw()
let moved = circle.move_to(20, 20)

# Check trait implementation
puts(circle.implements(Drawable))  # true
puts(circle.implements(Movable))   # true
```

## Pattern Matching (Future)

```quest
type Shape
    Circle(radius)
    Rectangle(width, height)
    Triangle(base, height)
end

let shape = Shape.Circle(5)

match shape
    Shape.Circle(r) -> puts("Circle with radius {r}")
    Shape.Rectangle(w, h) -> puts("{w}x{h} rectangle")
    Shape.Triangle(b, h) -> puts("Triangle")
end
```

## Complete Examples

### Example 1: Vector Math

```quest
use "std/math" as math

type Vec2
    x
    y

    fun length()
        math.sqrt(self.x * self.x + self.y * self.y)
    end

    fun normalized()
        let len = self.length()
        if len == 0
            Vec2.new(0, 0)
        else
            Vec2.new(self.x / len, self.y / len)
        end
    end

    fun add(other)
        Vec2.new(self.x + other.x, self.y + other.y)
    end

    fun subtract(other)
        Vec2.new(self.x - other.x, self.y - other.y)
    end

    fun dot(other)
        self.x * other.x + self.y * other.y
    end

    fun scale(s)
        Vec2.new(self.x * s, self.y * s)
    end

    fun zero()
        Vec2.new(0, 0)
    end
end

# Usage
let v1 = Vec2.new(3, 4)
let v2 = Vec2.new(1, 2)

puts(v1.length())        # 5.0
puts(v1.dot(v2))         # 11
let v3 = v1.add(v2)
puts(v3.x, v3.y)         # 4, 6
```

### Example 2: Configuration Object

```quest
type Config
    host
    port
    ssl
    timeout

    fun default()
        Config.new(
            host: "localhost",
            port: 8080,
            ssl: false,
            timeout: 30
        )
    end

    fun with_ssl()
        self.with(ssl: true, port: 443)
    end

    fun connection_string()
        let protocol = if self.ssl "https" else "http" end
        "{protocol}://{self.host}:{self.port}"
    end
end

# Usage
let config = Config.default()
let secure_config = config.with_ssl()
puts(secure_config.connection_string())  # "https://localhost:443"
```

### Example 3: Result Type (Option/Result pattern)

```quest
type Result
    Ok(value)
    Err(error)

    fun is_ok()
        # Check which variant this is
        self._variant() == "Ok"
    end

    fun is_err()
        self._variant() == "Err"
    end

    fun unwrap()
        if self.is_ok()
            self.value
        else
            raise "Called unwrap on Err: {self.error}"
        end
    end

    fun unwrap_or(default)
        if self.is_ok() self.value else default end
    end

    fun map(fn)
        if self.is_ok()
            Result.Ok(fn(self.value))
        else
            self
        end
    end
end

# Usage
fun divide(a, b)
    if b == 0
        Result.Err("Division by zero")
    else
        Result.Ok(a / b)
    end
end

let result = divide(10, 2)
if result.is_ok()
    puts("Result: {result.unwrap()}")
else
    puts("Error: {result.error}")
end

# Chaining
let result = divide(10, 2)
    .map(fun(x) x * 2 end)
    .map(fun(x) x + 1 end)

puts(result.unwrap_or(0))  # 11
```

### Example 4: Tree Data Structure

```quest
type TreeNode
    value
    left
    right

    fun leaf(value)
        TreeNode.new(value, nil, nil)
    end

    fun is_leaf()
        self.left == nil and self.right == nil
    end

    fun height()
        if self.is_leaf()
            1
        else
            let left_height = if self.left == nil 0 else self.left.height() end
            let right_height = if self.right == nil 0 else self.right.height() end
            1 + math.max(left_height, right_height)
        end
    end

    fun traverse_inorder(fn)
        if self.left != nil
            self.left.traverse_inorder(fn)
        end
        fn(self.value)
        if self.right != nil
            self.right.traverse_inorder(fn)
        end
    end
end

# Build a tree
let tree = TreeNode.new(
    5,
    TreeNode.new(
        3,
        TreeNode.leaf(1),
        TreeNode.leaf(4)
    ),
    TreeNode.new(
        7,
        TreeNode.leaf(6),
        TreeNode.leaf(9)
    )
)

puts("Height: {tree.height()}")
tree.traverse_inorder(fun(val) puts(val) end)
```

## Implementation Strategy

### Phase 1: Basic Structs
1. Define struct types with fields
2. Generate `.new()` constructor
3. Field access via `.field_name`
4. Auto-generate `.with()` and `.with_field()` methods
5. Structural equality

### Phase 2: Methods
1. Instance methods with `self`
2. Static methods
3. Method visibility

### Phase 3: Type Checking
1. Runtime `.is(Type)` checks
2. Optional type annotations on fields
3. Runtime validation on construction

### Phase 4: Advanced (Future)
1. Traits/interfaces
2. Enum variants (tagged unions)
3. Pattern matching
4. Destructuring

## Syntax Summary

```quest
# Basic struct
type Point
    x
    y
end

# With typed fields
type Person
    str: name
    num: age
end

# With methods
type Rectangle
    width
    height

    fun area()
        self.width * self.height
    end

    fun scale(factor)
        Rectangle.new(self.width * factor, self.height * factor)
    end

    fun square(size)  # static method
        Rectangle.new(size, size)
    end
end

# With traits (future)
type Circle
    radius

    impl Drawable
        fun draw()
            # implementation
        end
    end
end

# Enum/tagged union (future)
type Option
    Some(value)
    None
end
```
