# Bugs Found in Session 001

## Bug 1: Private Field Access in User-Defined Types

**Severity**: High
**Category**: Type System / Field Visibility

### Description
When defining a user type with fields, the fields are private by default. Accessing them even from within test code that created the instance raises `AttrErr: Field 'value' of type Calculator is private`.

### Reproduction
```quest
type Calculator
    value: Int
end

let calc = Calculator.create(100)
test.assert_eq(calc.value, 100)  # AttrErr: Field 'value' of type Calculator is private
```

### Expected Behavior
Either:
1. Fields should be public by default (like Ruby, Python, JavaScript)
2. Or there should be a clear `pub` keyword to make fields public (like Rust)

### Actual Behavior
Fields are private by default with no documented way to make them public.

### Impact
- Cannot test or validate type instances properly
- Makes types difficult to use in practice
- Breaks common patterns for data objects

---

## Bug 2: Same Issue - Field Visibility in Type with Defaults

**Severity**: High
**Category**: Type System / Field Visibility

### Description
Same issue as Bug 1 but with a different type (Point). Fields `x`, `y`, `label` are private.

### Reproduction
```quest
type Point
    x: Int
    y: Int
    label: Str

    static fun origin(x = 0, y = 0, label = "origin")
        return Point.new(x: x, y: y, label: label)
    end
end

let p1 = Point.origin()
test.assert_eq(p1.x, 0)  # AttrErr: Field 'x' of type Point is private
```

### Expected Behavior
Should be able to access public fields on instances.

### Actual Behavior
All fields are private by default.

---

## Analysis

The CLAUDE.md documentation doesn't mention field visibility rules. Looking at the type system section:

```quest
type Person
    name: str        # Required typed field
    age: Int?        # Optional (defaults to nil)
```

There's no indication these would be private. The documentation should clarify:
1. Default visibility (private or public)
2. How to declare public fields (if `pub` keyword exists)
3. Best practices for data types vs encapsulated types

## Workaround

Until field visibility is clarified, need to add getter methods:

```quest
type Calculator
    value: Int

    fun get_value()
        return self.value
    end
end
```

But this is verbose and defeats the purpose of having fields.
