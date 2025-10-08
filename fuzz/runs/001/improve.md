# Improvement Suggestions from Session 001

## 1. Field Visibility Clarity

**Priority**: High

The type system needs clearer field visibility semantics:

### Option A: Public by Default (Simpler)
```quest
type Point
    x: Int           # Public by default
    y: Int
    private z: Int   # Explicitly private
end
```

Pros:
- Matches Python, Ruby, JavaScript behavior
- Less boilerplate for data types
- Easier for beginners

Cons:
- Less encapsulation by default

### Option B: Rust-style Explicit (Safer)
```quest
type Point
    pub x: Int       # Explicitly public
    pub y: Int
    z: Int           # Private by default
end
```

Pros:
- Explicit intent
- Better encapsulation
- Matches Rust (which Quest seems inspired by)

Cons:
- More verbose
- Extra keyword to learn

**Recommendation**: Go with Option B (Rust-style) since Quest already uses Rust-inspired syntax for types. But **document it clearly** in CLAUDE.md and add examples showing `pub` usage.

---

## 2. Better Error Messages for Private Fields

Current error:
```
AttrErr: Field 'value' of type Calculator is private
```

Better error:
```
AttrErr: Field 'value' of type Calculator is private
  Hint: Add 'pub' before the field declaration to make it public:
        type Calculator
            pub value: Int
        end
```

---

## 3. Documentation Improvements

CLAUDE.md should include:

```quest
# User-Defined Types

type Person
    pub name: Str      # Public field - accessible as person.name
    pub age: Int       # Public field
    secret: Str        # Private field - only accessible within type methods

    fun greet()
        "Hello, " .. self.name  # Can access private fields in methods
    end

    fun get_secret()
        self.secret  # Private fields accessible via methods
    end
end

let p = Person.new(name: "Alice", age: 30, secret: "password123")
puts(p.name)        # OK - public field
puts(p.secret)      # Error - private field
puts(p.get_secret()) # OK - accessed via method
```

---

## 4. Struct-like Public Types

For pure data types (like Point, Rectangle, etc.), consider a shorthand:

```quest
# All fields public by default
struct Point
    x: Int
    y: Int
end

# Equivalent to:
type Point
    pub x: Int
    pub y: Int
end
```

This would make data types more ergonomic while keeping `type` for encapsulated objects.

---

## 5. Property Decorators / Getters-Setters

For encapsulated types, Python-style properties would be nice:

```quest
type Temperature
    celsius: Float

    @property
    fun fahrenheit()
        self.celsius * 9.0 / 5.0 + 32.0
    end

    @setter
    fun fahrenheit(value)
        self.celsius = (value - 32.0) * 5.0 / 9.0
    end
end

let temp = Temperature.new(celsius: 0.0)
puts(temp.fahrenheit)        # 32.0 (looks like field access)
temp.fahrenheit = 100.0      # Sets via setter
puts(temp.celsius)           # ~37.78
```

This would provide clean field-like syntax while maintaining encapsulation.

---

## 6. Varargs/Kwargs Work Perfectly!

**Positive feedback**: All the varargs (`*args`) and kwargs (`**kwargs`) features tested worked flawlessly:
- Basic collection ✓
- With required parameters ✓
- With default parameters ✓
- Named argument reordering ✓
- Skipping defaults with named args ✓
- Combining all parameter types ✓
- Lambdas with varargs ✓
- Nested closures over varargs ✓

These features are production-ready and well-implemented!
