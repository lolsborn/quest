# Quest Language Comparison

**Status:** Documentation
**Created:** 2025-10-06
**Purpose:** Compare Quest's syntax and features with other popular languages

## Table of Contents

1. [Type Annotation Syntax](#type-annotation-syntax)
2. [Function Parameters](#function-parameters)
3. [Struct/Class Field Definitions](#structclass-field-definitions)
4. [Default Parameters](#default-parameters)
5. [Named/Keyword Arguments](#namedkeyword-arguments)
6. [Variadic Parameters](#variadic-parameters)
7. [Complete Feature Matrix](#complete-feature-matrix)

---

## Type Annotation Syntax

### Function Parameters

| Language | Syntax | Example |
|----------|--------|---------|
| **Quest** | `name: type` | `fun greet(name: str, age: int)` |
| Python | `name: type` | `def greet(name: str, age: int)` |
| TypeScript | `name: type` | `function greet(name: string, age: number)` |
| Rust | `name: type` | `fn greet(name: &str, age: i32)` |
| Swift | `name: type` | `func greet(name: String, age: Int)` |
| Kotlin | `name: type` | `fun greet(name: String, age: Int)` |
| Go | `name type` | `func greet(name string, age int)` |
| C++ | `type name` | `void greet(string name, int age)` |
| Java | `type name` | `void greet(String name, int age)` |
| C# | `type name` | `void greet(string name, int age)` |

**Quest follows:** Python, TypeScript, Rust, Swift, Kotlin (modern languages)

### Struct/Class Fields

| Language | Syntax | Example |
|----------|--------|---------|
| **Quest** | `type: name` | `type Person { str: name, int: age }` |
| Python | `name: type` | `class Person:\n    name: str\n    age: int` |
| TypeScript | `name: type` | `interface Person { name: string; age: number }` |
| Rust | `name: type` | `struct Person { name: String, age: i32 }` |
| Swift | `name: type` | `struct Person { var name: String; var age: Int }` |
| Kotlin | `name: type` | `data class Person(val name: String, val age: Int)` |
| Go | `name type` | `type Person struct { name string; age int }` |
| C++ | `type name` | `struct Person { string name; int age; }` |
| Java | `type name` | `class Person { String name; int age; }` |
| C# | `type name` | `class Person { string name; int age; }` |

**Quest is unique:** Most languages use `name: type` or `name type` for fields
**Quest rationale:** Type-first emphasis, visual distinction from methods

---

## Function Parameters

### Basic Parameters

```quest
# Quest
fun greet(name, greeting)
    greeting .. ", " .. name
end
```

```python
# Python
def greet(name, greeting):
    return f"{greeting}, {name}"
```

```typescript
// TypeScript
function greet(name: string, greeting: string): string {
    return `${greeting}, ${name}`;
}
```

```rust
// Rust
fn greet(name: &str, greeting: &str) -> String {
    format!("{}, {}", greeting, name)
}
```

```ruby
# Ruby
def greet(name, greeting)
  "#{greeting}, #{name}"
end
```

```go
// Go
func greet(name string, greeting string) string {
    return greeting + ", " + name
}
```

---

## Default Parameters

| Language | Syntax | Example | Optional Position |
|----------|--------|---------|-------------------|
| **Quest** | `param = value` | `fun f(a, b = 10)` | Required first, then optional |
| Python | `param=value` | `def f(a, b=10)` | Required first, then optional |
| TypeScript | `param = value` | `function f(a, b = 10)` | Required first, then optional |
| JavaScript | `param = value` | `function f(a, b = 10)` | Required first, then optional |
| Rust | `N/A` | ❌ No default params | N/A (use Option<T>) |
| Swift | `param: Type = value` | `func f(a: Int, b: Int = 10)` | Required first, then optional |
| Kotlin | `param: Type = value` | `fun f(a: Int, b: Int = 10)` | Any position |
| Go | `N/A` | ❌ No default params | N/A |
| Ruby | `param = value` | `def f(a, b = 10)` | Any position |
| C++ | `type param = value` | `void f(int a, int b = 10)` | Optional must be last |
| C# | `type param = value` | `void f(int a, int b = 10)` | Optional must be last |

**Quest matches:** Python, TypeScript, JavaScript, C++, C# (required before optional)

### Default Parameter Examples

```quest
# Quest (QEP-029)
fun connect(host, port = 8080, timeout = 30)
    # ...
end

connect("localhost")              # port=8080, timeout=30
connect("localhost", 3000)        # timeout=30
connect("localhost", 3000, 60)    # All specified
```

```python
# Python
def connect(host, port=8080, timeout=30):
    pass

connect("localhost")              # port=8080, timeout=30
connect("localhost", 3000)        # timeout=30
connect("localhost", 3000, 60)    # All specified
```

```typescript
// TypeScript
function connect(host: string, port = 8080, timeout = 30): void {
}

connect("localhost");             // port=8080, timeout=30
connect("localhost", 3000);       // timeout=30
connect("localhost", 3000, 60);   // All specified
```

```kotlin
// Kotlin (can have defaults anywhere)
fun connect(host: String, port: Int = 8080, timeout: Int = 30) {
}

connect("localhost")              // port=8080, timeout=30
connect(host = "localhost", timeout = 60) // Skip port!
```

---

## Named/Keyword Arguments

| Language | Syntax | Reordering | Status |
|----------|--------|------------|--------|
| **Quest** | `name: value` | ✅ Yes | Planned (QEP-031) |
| Python | `name=value` | ✅ Yes | ✅ Built-in |
| TypeScript | `N/A` | ❌ No | ❌ Not supported |
| JavaScript | `N/A` | ❌ No | ❌ Not supported (use object) |
| Rust | `N/A` | ❌ No | ❌ Not supported |
| Swift | `label: value` | ✅ Yes | ✅ Built-in (required!) |
| Kotlin | `name = value` | ✅ Yes | ✅ Built-in |
| Go | `N/A` | ❌ No | ❌ Not supported |
| Ruby | `name: value` | ✅ Yes | ✅ Built-in |
| C++ | `N/A` | ❌ No | ❌ Not supported |
| C# | `name: value` | ✅ Yes | ✅ Built-in |

**Quest matches:** Python, Ruby, C# (named arguments with reordering)
**Quest syntax:** Uses `:` like Ruby/C# (not `=` like Python/Kotlin)

### Named Arguments Examples

```quest
# Quest (QEP-031)
fun connect(host, port, timeout)
    # ...
end

connect(host: "localhost", port: 8080, timeout: 30)
connect(timeout: 30, host: "localhost", port: 8080)  # Reordered
connect("localhost", port: 8080, timeout: 30)        # Mixed
```

```python
# Python
def connect(host, port, timeout):
    pass

connect(host="localhost", port=8080, timeout=30)
connect(timeout=30, host="localhost", port=8080)     # Reordered
connect("localhost", port=8080, timeout=30)          # Mixed
```

```ruby
# Ruby
def connect(host:, port:, timeout:)
end

connect(host: "localhost", port: 8080, timeout: 30)
connect(timeout: 30, host: "localhost", port: 8080)  # Reordered
```

```swift
// Swift (named parameters are the default!)
func connect(host: String, port: Int, timeout: Int) {
}

connect(host: "localhost", port: 8080, timeout: 30)
connect(timeout: 30, host: "localhost", port: 8080)  // Error: order matters!
```

```csharp
// C#
void Connect(string host, int port, int timeout) {
}

Connect(host: "localhost", port: 8080, timeout: 30);
Connect(timeout: 30, host: "localhost", port: 8080);  // Reordered
```

```kotlin
// Kotlin
fun connect(host: String, port: Int, timeout: Int) {
}

connect(host = "localhost", port = 8080, timeout = 30)
connect(timeout = 30, host = "localhost", port = 8080)  // Reordered
```

---

## Variadic Parameters

| Language | Syntax | Keyword Varargs | Status |
|----------|--------|-----------------|--------|
| **Quest** | `*args, **kwargs` | ✅ Yes | Planned (QEP-030) |
| Python | `*args, **kwargs` | ✅ Yes | ✅ Built-in |
| TypeScript | `...args` | ❌ No | ✅ Built-in (rest) |
| JavaScript | `...args` | ❌ No | ✅ Built-in (rest) |
| Rust | `N/A` | ❌ No | ❌ Not supported (macros only) |
| Swift | `args...` | ❌ No | ✅ Built-in |
| Kotlin | `vararg args` | ❌ No | ✅ Built-in |
| Go | `args ...Type` | ❌ No | ✅ Built-in |
| Ruby | `*args, **kwargs` | ✅ Yes | ✅ Built-in |
| C++ | `...` (C-style) | ❌ No | ✅ Built-in (variadic templates) |
| Java | `Type... args` | ❌ No | ✅ Built-in |
| C# | `params Type[] args` | ❌ No | ✅ Built-in |

**Quest matches:** Python, Ruby (both positional and keyword varargs)

### Variadic Examples

```quest
# Quest (QEP-030)
fun sum(*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

fun configure(**options)
    for key in options.keys()
        puts(key, " = ", options[key])
    end
end

sum(1, 2, 3, 4, 5)  # varargs
configure(host: "localhost", port: 8080, debug: true)  # kwargs
```

```python
# Python
def sum(*numbers):
    return sum(numbers)

def configure(**options):
    for key, value in options.items():
        print(f"{key} = {value}")

sum(1, 2, 3, 4, 5)
configure(host="localhost", port=8080, debug=True)
```

```ruby
# Ruby
def sum(*numbers)
  numbers.sum
end

def configure(**options)
  options.each { |key, value| puts "#{key} = #{value}" }
end

sum(1, 2, 3, 4, 5)
configure(host: "localhost", port: 8080, debug: true)
```

```typescript
// TypeScript (no keyword varargs)
function sum(...numbers: number[]): number {
    return numbers.reduce((a, b) => a + b, 0);
}

// Must use object for named options
function configure(options: {host?: string, port?: number, debug?: boolean}) {
    Object.entries(options).forEach(([key, value]) => {
        console.log(`${key} = ${value}`);
    });
}

sum(1, 2, 3, 4, 5);
configure({host: "localhost", port: 8080, debug: true});
```

```go
// Go
func sum(numbers ...int) int {
    total := 0
    for _, n := range numbers {
        total += n
    }
    return total
}

sum(1, 2, 3, 4, 5)
```

---

## Complete Feature Matrix

| Feature | Quest | Python | TypeScript | Rust | Ruby | Go | Swift | Kotlin |
|---------|-------|--------|------------|------|------|----|-------|--------|
| **Type Annotations** |
| Function params | ✅ `name: type` | ✅ `name: type` | ✅ `name: type` | ✅ `name: type` | ❌ No | ✅ `name type` | ✅ `name: type` | ✅ `name: type` |
| Struct/class fields | ✅ `type: name` | ✅ `name: type` | ✅ `name: type` | ✅ `name: type` | ❌ No | ✅ `name type` | ✅ `name: type` | ✅ `name: type` |
| Return types | ✅ `-> type` | ✅ `-> type` | ✅ `: type` | ✅ `-> type` | ❌ No | ✅ `type` | ✅ `-> type` | ✅ `: type` |
| Type enforcement | ✅ Runtime | ❌ Optional | ✅ Compile | ✅ Compile | ❌ No | ✅ Compile | ✅ Compile | ✅ Compile |
| **Default Parameters** |
| Supported | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| Position | End only | End only | End only | N/A | Anywhere | N/A | End only | Anywhere |
| Call-time eval | ✅ Yes | ❌ Def-time | ✅ Yes | N/A | ✅ Yes | N/A | ✅ Yes | ✅ Yes |
| Reference earlier params | ✅ Yes | ❌ No | ❌ No | N/A | ✅ Yes | N/A | ❌ No | ❌ No |
| **Named Arguments** |
| Supported | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |
| Syntax | `name: value` | `name=value` | N/A | N/A | `name: value` | N/A | `name: value` | `name = value` |
| Reordering | ✅ Yes | ✅ Yes | N/A | N/A | ✅ Yes | N/A | ⚠️ Limited | ✅ Yes |
| Skip optional | ✅ Yes | ✅ Yes | N/A | N/A | ✅ Yes | N/A | ✅ Yes | ✅ Yes |
| **Variadic Parameters** |
| Positional varargs | ✅ `*args` | ✅ `*args` | ✅ `...args` | ❌ No | ✅ `*args` | ✅ `...Type` | ✅ `args...` | ✅ `vararg` |
| Keyword varargs | ✅ `**kwargs` | ✅ `**kwargs` | ❌ No | ❌ No | ✅ `**kwargs` | ❌ No | ❌ No | ❌ No |
| Unpacking | ✅ `*arr, **dict` | ✅ `*arr, **dict` | ✅ `...arr` | ❌ No | ✅ `*arr, **hash` | ⚠️ Limited | ❌ No | ✅ `*arr` |
| Type annotations | ✅ Element type | ❌ No | ✅ Array type | N/A | ❌ No | ✅ Element type | ✅ Element type | ✅ Element type |
| **Other Features** |
| Optional types | ✅ `int?` | ✅ `Optional[int]` | ✅ `number \| null` | ✅ `Option<i32>` | N/A | ✅ `*int` | ✅ `Int?` | ✅ `Int?` |
| Keyword-only params | 🔄 Future | ✅ After `*` | ❌ No | ❌ No | ✅ After `*` | ❌ No | ❌ No | ❌ No |
| Positional-only params | 🔄 Future | ✅ Before `/` | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |

**Legend:**
- ✅ Fully supported
- ⚠️ Partially supported
- 🔄 Planned/Future
- ❌ Not supported
- N/A Not applicable

---

## Quest's Unique Position

### Most Similar To: **Python + Ruby**

Quest combines the best features from multiple languages:

| Feature | Inherited From | Rationale |
|---------|----------------|-----------|
| `*args, **kwargs` | Python, Ruby | Best practice for flexible APIs |
| Named arguments | Python, Ruby, C# | Improves readability |
| Default parameters | Python, TypeScript | Better DX than Option<T> |
| Type annotations | TypeScript, Rust, Swift | Modern standard |
| Runtime type checking | Python (optional), Typed Racket | Dynamic language with safety |
| Call-time default eval | Ruby, JavaScript | Enables dynamic defaults |
| Everything is an object | Ruby, Python | Consistent model |

### Unique Quest Features

1. **Type-first struct fields:** `str: name` (different from most languages)
2. **Runtime type enforcement:** Types checked at runtime (unlike Python hints)
3. **Stricter than Python:** Types are enforced, not optional
4. **Defaults reference earlier params:** `fun f(x, y = x + 1)`
5. **Combined best practices:** Python + Ruby + TypeScript features

---

## Syntax Comparison Cheat Sheet

### Variable Declarations

```quest
# Quest
let x = 5
let name: str = "Alice"
const PI = 3.14
```

```python
# Python
x = 5
name: str = "Alice"
PI = 3.14  # Convention only
```

```typescript
// TypeScript
let x = 5;
let name: string = "Alice";
const PI = 3.14;
```

```rust
// Rust
let x = 5;
let name: &str = "Alice";
const PI: f64 = 3.14;
```

### Function Definitions

```quest
# Quest
fun greet(name: str, greeting: str = "Hello") -> str
    greeting .. ", " .. name
end
```

```python
# Python
def greet(name: str, greeting: str = "Hello") -> str:
    return f"{greeting}, {name}"
```

```typescript
// TypeScript
function greet(name: string, greeting: string = "Hello"): string {
    return `${greeting}, ${name}`;
}
```

```rust
// Rust
fn greet(name: &str, greeting: &str) -> String {
    format!("{}, {}", greeting, name)
}
```

```ruby
# Ruby
def greet(name, greeting = "Hello")
  "#{greeting}, #{name}"
end
```

### Struct/Type Definitions

```quest
# Quest (unique!)
type Person
    str: name
    int: age
    str?: email

    fun greet()
        "Hello, " .. self.name
    end
end
```

```python
# Python
class Person:
    name: str
    age: int
    email: str | None

    def greet(self):
        return f"Hello, {self.name}"
```

```typescript
// TypeScript
interface Person {
    name: string;
    age: number;
    email?: string;
}
```

```rust
// Rust
struct Person {
    name: String,
    age: i32,
    email: Option<String>,
}

impl Person {
    fn greet(&self) -> String {
        format!("Hello, {}", self.name)
    }
}
```

```ruby
# Ruby
class Person
  attr_accessor :name, :age, :email

  def greet
    "Hello, #{@name}"
  end
end
```

---

## Language Philosophy Comparison

| Language | Philosophy | Quest Similarity |
|----------|------------|------------------|
| **Python** | "Batteries included", readability | ⭐⭐⭐⭐⭐ Very similar |
| **Ruby** | "Programmer happiness", elegant | ⭐⭐⭐⭐⭐ Very similar |
| **TypeScript** | JavaScript + types | ⭐⭐⭐⭐ Similar goals |
| **Rust** | Safety + performance | ⭐⭐ Type safety, but different focus |
| **Go** | Simplicity, explicit | ⭐⭐ Simple, but more verbose |
| **Swift** | Modern, safe, expressive | ⭐⭐⭐ Similar modern features |
| **Kotlin** | Pragmatic, Java++ | ⭐⭐⭐ Similar improvements |

**Quest's philosophy:** Developer happiness (Ruby) + Safety (TypeScript) + Flexibility (Python)

---

## Migration Guides

### For Python Developers

**What's the same:**
- `*args` and `**kwargs`
- Named arguments
- Default parameters
- Object-oriented model

**What's different:**
- `end` instead of indentation
- `fun` instead of `def`
- Type annotations **enforced** at runtime
- Struct fields use `type: name` (reversed)
- String concatenation: `..` not `+`

### For Ruby Developers

**What's the same:**
- Everything is an object
- Named arguments with `name: value`
- Blocks/closures
- `end` keyword

**What's different:**
- Type annotations (optional but enforced)
- `fun` instead of `def`
- Struct syntax different
- Explicit `return` optional

### For TypeScript Developers

**What's the same:**
- Type annotations
- Optional types with `?`
- Similar type system

**What's different:**
- Runtime type checking (not compile-time)
- No compilation step
- Named arguments supported
- `**kwargs` for flexible APIs

---

## See Also

- [SYNTAX_CONVENTIONS.md](SYNTAX_CONVENTIONS.md) - Quest-specific syntax decisions
- [QEP-015: Type Annotations](qep-015-type-annotations.md)
- [QEP-029: Default Parameters](qep-029-default-parameters.md)
- [QEP-030: Variadic Parameters](qep-030-variadic-parameters.md)
- [QEP-031: Named Arguments](qep-031-named-arguments.md)
- [CLAUDE.md](../CLAUDE.md) - Complete language reference

## Copyright

This document is placed in the public domain.
