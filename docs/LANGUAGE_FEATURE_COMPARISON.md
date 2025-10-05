# Language Feature Comparison: Quest vs Python vs Ruby

A comprehensive comparison of core language features and patterns (excluding standard library).

## Legend
- ✅ Fully Supported
- ⚠️ Partially Supported / Different Syntax
- ❌ Not Supported
- 🔄 Planned/In Progress

---

## Object Model & Type System

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Everything is an object | ✅ | ✅ | ✅ | All three treat primitives as objects |
| Primitive types | ✅ Int, Float, Decimal, Bool, Str, Bytes, Nil | ✅ int, float, bool, str, bytes, None | ✅ Integer, Float, TrueClass, FalseClass, String, Symbol, NilClass | Quest has Decimal for precision |
| Object ID tracking | ✅ `obj._id()` | ✅ `id(obj)` | ✅ `obj.object_id` | All provide unique identifiers |
| Type checking | ✅ `obj.is("Type")` | ✅ `isinstance()` | ✅ `obj.is_a?()` | Runtime type checking |
| Type annotations | ⚠️ Field types only | ⚠️ Optional (type hints) | ❌ | Quest: `int: field`, Python: function annotations |
| Duck typing | ✅ | ✅ | ✅ | All support duck typing |
| Singleton pattern | ✅ Nil (ID 0), Bool | ✅ None, True, False | ✅ nil, true, false | Nil always has ID 0 in Quest |
| Integer overflow handling | ✅ Checked overflow | ⚠️ Arbitrary precision | ⚠️ Arbitrary precision | Quest detects overflow; Python/Ruby auto-promote |

---

## User-Defined Types

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Class/Type definition | ✅ `type Name ... end` | ✅ `class Name:` | ✅ `class Name ... end` | Quest uses `type` keyword |
| Field declaration | ✅ `int: name`, `str?: email` | ⚠️ Via `__init__` or dataclass | ⚠️ Via `attr_accessor` | Quest has explicit field syntax |
| Optional fields | ✅ `int?: field` | ⚠️ Via defaults/Optional | ⚠️ Via defaults | Quest has `?` syntax |
| Constructor | ✅ `Type.new(...)` | ✅ `__init__()` | ✅ `initialize()` | Quest: static `.new()` method |
| Named arguments | ✅ `Type.new(name: "x")` | ✅ `func(name="x")` | ✅ `func(name: "x")` | All three support named args |
| Positional arguments | ✅ `Type.new("x", 10)` | ✅ `func("x", 10)` | ✅ `func("x", 10)` | Standard positional args |
| Instance methods | ✅ `fun method() ... end` | ✅ `def method(self):` | ✅ `def method ... end` | Quest: implicit `self` |
| Static methods | ✅ `static fun method()` | ✅ `@staticmethod` | ✅ `self.method` | Quest: explicit `static` keyword |
| Class methods | ❌ | ✅ `@classmethod` | ✅ `self.method` | Quest has static methods only |
| Self reference | ✅ `self` | ✅ `self` | ✅ `self` | All use `self` |
| Inheritance | ❌ | ✅ | ✅ | Quest planned for future |
| Multiple inheritance | ❌ | ✅ | ❌ (uses mixins) | Not in Quest |
| Mixins | ❌ | ❌ | ✅ | Ruby modules, not in Quest |
| Traits/Interfaces | ✅ `trait Name ... end` | ⚠️ ABC (abstract base class) | ⚠️ Modules | Quest has explicit trait system |
| Trait implementation | ✅ `impl TraitName ... end` | ⚠️ Inherit from ABC | ⚠️ `include Module` | Quest: explicit `impl` blocks |
| Trait validation | ✅ At definition time | ⚠️ At instantiation | ⚠️ At runtime | Quest validates at type declaration |
| Property/getter | ⚠️ Field access only | ✅ `@property` | ✅ `attr_reader` | Quest: direct field access |
| Setter | ⚠️ Direct assignment | ✅ `@property.setter` | ✅ `attr_writer` | Quest: direct field assignment |

---

## Variables & Scoping

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Variable declaration | ✅ `let x = 5` | ⚠️ Implicit | ⚠️ Implicit | Quest requires `let` |
| Multiple declaration | ✅ `let x=1, y=2, z=3` | ⚠️ `x = y = z = 0` (chained) | ⚠️ `x = y = z = 0` (chained) | Quest: comma-separated |
| Assignment | ✅ `x = 10` | ✅ `x = 10` | ✅ `x = 10` | Standard assignment |
| Compound assignment | ✅ `+=`, `-=`, `*=`, `/=` | ✅ `+=`, `-=`, `*=`, `/=`, etc. | ✅ `+=`, `-=`, `*=`, `/=`, etc. | All three support |
| Variable deletion | ✅ `del x` | ✅ `del x` | ❌ (can set to nil) | Quest/Python explicit delete |
| Global scope | ✅ REPL global HashMap | ✅ `global` keyword | ✅ `$global` prefix | Quest: default in REPL |
| Local scope | ✅ Function scopes | ✅ Function scopes | ✅ Function/block scopes | All support local scopes |
| Lexical scoping | ✅ | ✅ | ✅ | All support lexical scoping |
| Block scope | ⚠️ Limited | ❌ (function only) | ✅ | Ruby has block-level scope |
| Closure support | ✅ | ✅ | ✅ | All support closures |
| Variable shadowing | ✅ | ✅ | ✅ | All allow shadowing |
| Constants | ❌ | ⚠️ Convention (CAPS) | ✅ CONSTANT | Quest: no constant enforcement |

---

## Operators & Expressions

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Arithmetic | ✅ `+`, `-`, `*`, `/`, `%` | ✅ `+`, `-`, `*`, `/`, `%`, `//`, `**` | ✅ `+`, `-`, `*`, `/`, `%`, `**` | Quest lacks `**` (power) and `//` (floor div) |
| Comparison | ✅ `==`, `!=`, `>`, `<`, `>=`, `<=` | ✅ `==`, `!=`, `>`, `<`, `>=`, `<=` | ✅ `==`, `!=`, `>`, `<`, `>=`, `<=` | All equivalent |
| Logical | ✅ `and`, `or`, `not` | ✅ `and`, `or`, `not` | ✅ `&&`, `||`, `!` / `and`, `or`, `not` | Quest uses words like Python |
| Bitwise | ✅ `&`, `|`, `^`, `~`, `<<`, `>>` | ✅ `&`, `|`, `^`, `~`, `<<`, `>>` | ✅ `&`, `|`, `^`, `~`, `<<`, `>>` | All equivalent |
| String concatenation | ✅ `..` operator | ✅ `+` operator | ✅ `+` operator | Quest uses `..` |
| String interpolation | ✅ f-strings `f"text {var}"`, `.fmt()` | ✅ f-strings `f"{var}"` | ✅ `"#{var}"` | Quest: f-strings and .fmt() method |
| Ternary operator | ✅ `val if cond else other` | ✅ `val if cond else other` | ✅ `cond ? val : other` | Quest/Python identical |
| Operator overloading | ⚠️ Via methods | ✅ `__add__`, etc. | ✅ `def +`, etc. | Quest: method-based |
| Spaceship operator | ❌ | ❌ | ✅ `<=>` | Ruby only |
| Safe navigation | ❌ | ❌ | ✅ `&.` | Ruby only |
| Elvis operator | ❌ | ❌ | ❌ | None support (use `or`) |
| Operator precedence | ✅ Full precedence | ✅ Full precedence | ✅ Full precedence | All have proper precedence |

---

## Control Flow

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| If/elif/else | ✅ `if...elif...else...end` | ✅ `if...elif...else:` | ✅ `if...elsif...else...end` | Quest/Ruby use `end` |
| Inline if (ternary) | ✅ `val if cond else other` | ✅ `val if cond else other` | ✅ `cond ? val : other` | Quest/Python identical |
| Unless | ❌ | ❌ | ✅ `unless cond ... end` | Ruby only |
| While loop | ✅ `while cond ... end` | ✅ `while cond:` | ✅ `while cond ... end` | All support |
| Until loop | ❌ | ❌ | ✅ `until cond ... end` | Ruby only |
| For..in loop | ✅ `for x in iter ... end` | ✅ `for x in iter:` | ✅ `for x in iter ... end` | All support |
| Range iteration | ✅ `for i in 1..10` | ✅ `for i in range(1, 11)` | ✅ `for i in 1..10` | Quest/Ruby similar syntax |
| Break | ✅ `break` | ✅ `break` | ✅ `break` | All support |
| Continue | ✅ `continue` | ✅ `continue` | ✅ `next` | Ruby uses `next` |
| Loop else | ❌ | ✅ `else` clause | ❌ | Python only |
| Case/switch | ❌ | ⚠️ `match` (3.10+) | ✅ `case...when` | Quest: planned |
| Pattern matching | ❌ | ⚠️ `match` (3.10+) | ⚠️ Limited | Quest: not planned |

---

## Exception Handling

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Try/catch | ✅ `try...catch...end` | ✅ `try...except:` | ✅ `begin...rescue...end` | All support |
| Typed catch | ✅ `catch e: Type` | ✅ `except Type:` | ✅ `rescue Type` | All support type filtering |
| Finally/ensure | ✅ `ensure` | ✅ `finally:` | ✅ `ensure` | Quest/Ruby use `ensure` |
| Raise/throw | ✅ `raise "msg"` | ✅ `raise Exception()` | ✅ `raise "msg"` | All support |
| Re-raise | ✅ `raise` (bare) | ✅ `raise` (bare) | ✅ `raise` (bare) | All support re-raising |
| Exception object | ✅ QException | ✅ Exception class | ✅ Exception class | All have exception objects |
| Exception methods | ✅ `message()`, `exc_type()`, `stack()`, `line()` | ✅ `args`, `__str__`, etc. | ✅ `message`, `backtrace` | Quest has comprehensive methods |
| Stack traces | ✅ Via `e.stack()` | ✅ `traceback` module | ✅ `e.backtrace` | All support stack traces |
| Exception chaining | ✅ `e.cause()` | ✅ `raise...from` | ✅ `raise...from` | All support chaining |
| Custom exceptions | ⚠️ Via Type system | ✅ Inherit Exception | ✅ Inherit StandardError | Quest: type-based |
| Multiple except | ⚠️ Multiple catch blocks | ✅ Multiple `except` | ✅ Multiple `rescue` | All support |

---

## Functions & Callables

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Function definition | ✅ `fun name(params) ... end` | ✅ `def name(params):` | ✅ `def name(params) ... end` | Quest/Ruby use `end` |
| Lambda/anonymous | ⚠️ `fun(x) x * 2 end` | ✅ `lambda x: x * 2` | ✅ `lambda {|x| x * 2}` or `-> (x) { x * 2 }` | Quest: partially implemented |
| Closures | ✅ | ✅ | ✅ | All support closures |
| Default parameters | ⚠️ Via optional fields | ✅ `def f(x=10):` | ✅ `def f(x=10)` | Quest: limited support |
| Keyword arguments | ✅ `func(name: "x")` | ✅ `func(name="x")` | ✅ `func(name: "x")` | Quest/Ruby similar syntax |
| Variable arguments | ❌ | ✅ `*args`, `**kwargs` | ✅ `*args`, `**kwargs` | Quest: not supported |
| Argument unpacking | ❌ | ✅ `*list`, `**dict` | ✅ `*array`, `**hash` | Quest: not supported |
| First-class functions | ✅ `obj.method` returns QFun | ✅ Functions are objects | ✅ Methods are objects | All support first-class functions |
| Method references | ✅ `obj.method` (no parens) | ⚠️ Via getattr | ✅ `obj.method(:name)` | Quest: explicit syntax |
| Decorators | ❌ | ✅ `@decorator` | ❌ | Python only |
| Yield/generators | ❌ | ✅ `yield` | ✅ `yield` | Quest: not supported |
| Return value | ✅ Explicit `return` or last expression | ✅ Explicit `return` | ✅ Implicit last value or `return` | Ruby: implicit return |
| Multiple return | ⚠️ Via Array | ✅ `return x, y` | ✅ `return x, y` | Quest: manual tuple/array |

---

## Method Calling

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Method call | ✅ `obj.method()` | ✅ `obj.method()` | ✅ `obj.method` or `obj.method()` | Ruby: parens optional |
| Method reference | ✅ `obj.method` (no parens) | ⚠️ Via `getattr` | ✅ `obj.method(:name)` | Quest: returns QFun object |
| Chaining | ✅ `obj.m1().m2()` | ✅ `obj.m1().m2()` | ✅ `obj.m1.m2` | All support chaining |
| Operator methods | ✅ `plus()`, `minus()`, etc. | ✅ `__add__`, `__sub__`, etc. | ✅ `+`, `-` overloading | Quest: explicit method names |
| Magic methods | ⚠️ `_id()`, `_str()`, `_rep()` | ✅ `__str__`, `__repr__`, etc. | ✅ `to_s`, `inspect`, etc. | All have special methods |
| Method missing | ❌ | ⚠️ `__getattr__` | ✅ `method_missing` | Ruby: powerful metaprogramming |
| Dynamic dispatch | ✅ | ✅ | ✅ | All support runtime method dispatch |

---

## Collections

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Arrays/Lists | ✅ `[1, 2, 3]` | ✅ `[1, 2, 3]` | ✅ `[1, 2, 3]` | All support |
| Array mutability | ✅ Mutable | ✅ Mutable | ✅ Mutable | All mutable |
| Array methods | ✅ 40+ methods | ✅ Many methods | ✅ Many methods | All comprehensive |
| Dictionaries/Hashes | ✅ `{"key": val}` | ✅ `{"key": val}` | ✅ `{key: val}` or `{"key" => val}` | Quest/Python similar |
| Dict mutability | ✅ Mutable | ✅ Mutable | ✅ Mutable | All mutable |
| Sets | ✅ QSet type | ✅ `{1, 2, 3}` or `set()` | ✅ `Set.new([1, 2, 3])` | Quest has Set type |
| Tuples | ❌ (use Arrays) | ✅ `(1, 2, 3)` | ❌ (use Arrays) | Python only for immutable |
| Frozen collections | ❌ | ✅ `frozenset` | ✅ `.freeze` | Quest: not supported |
| List comprehension | ❌ | ✅ `[x*2 for x in list]` | ❌ (use `map`) | Python only |
| Dict comprehension | ❌ | ✅ `{k:v for...}` | ❌ (use methods) | Python only |
| Slicing | ✅ `arr.slice(start, end)` | ✅ `arr[start:end]` | ✅ `arr[start..end]` | Quest: method-based |
| Negative indexing | ⚠️ Via methods | ✅ `arr[-1]` | ✅ `arr[-1]` | Quest: method-based |
| Unpacking | ❌ | ✅ `a, b = [1, 2]` | ✅ `a, b = [1, 2]` | Quest: not supported |

---

## Strings & Text

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| String literals | ✅ `"text"` | ✅ `"text"`, `'text'` | ✅ `"text"`, `'text'` | Quest: double quotes only |
| String interpolation | ✅ f-strings `f"text {var}"`, `.fmt()` | ✅ f-strings `f"{var}"` | ✅ `"#{var}"` | Quest has f-strings and .fmt() |
| Raw strings | ❌ | ✅ `r"text"` | ❌ | Python only |
| Bytes literals | ✅ `b"data"` | ✅ `b"data"` | ✅ `"text".bytes` | Quest/Python similar syntax |
| Multi-line strings | ✅ `"""text"""` | ✅ `"""text"""` | ✅ `<<~HEREDOC` | Quest/Python use triple quotes |
| String immutability | ✅ Immutable | ✅ Immutable | ❌ Mutable | Ruby strings mutable |
| String methods | ✅ 30+ methods | ✅ Many methods | ✅ Many methods | All comprehensive |
| Regex | ✅ `std/regex` module | ✅ `re` module | ✅ Built-in `/pattern/` | Quest/Python: module-based, Ruby: built-in |
| String encoding | ✅ Always UTF-8 | ⚠️ Usually UTF-8 | ⚠️ Multiple encodings | Quest: UTF-8 only |
| Format strings | ✅ `.fmt()` method | ✅ `"{} {}".format()` | ✅ `"%s %s" % []` | Quest has .fmt() for formatting |

---

## Context Managers & Resources

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| With statement | ✅ `with obj ... end` | ✅ `with obj:` | ❌ (use blocks) | Quest/Python similar |
| Context protocol | ✅ `_enter()`, `_exit()` | ✅ `__enter__`, `__exit__` | ⚠️ Block-based | Quest: underscore prefix |
| Variable binding | ✅ `with obj as var` | ✅ `with obj as var:` | ⚠️ Block params | Quest/Python identical |
| Multiple contexts | ❌ | ✅ `with a, b:` (3.1+) | ⚠️ Nested blocks | Quest: not supported |
| Exception handling | ✅ `_exit()` always called | ✅ `__exit__` with exc info | ⚠️ Block ensure | All ensure cleanup |
| Variable shadowing | ✅ | ✅ | ✅ | All support shadowing |

---

## Modules & Imports

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Import statement | ✅ `use "module"` | ✅ `import module` | ✅ `require 'module'` | Different keywords |
| Import from | ❌ | ✅ `from mod import x` | ❌ | Python only |
| Relative imports | ⚠️ Path-based | ✅ `.module` | ⚠️ Path-based | Python: explicit relative |
| Module namespace | ✅ Required prefix | ⚠️ Optional | ⚠️ Optional | Quest enforces module prefix |
| Module reload | ⚠️ Cached (no reload) | ✅ `importlib.reload()` | ✅ `load 'file'` | Quest caches, Python/Ruby can reload |
| Module search path | ✅ `os.search_path` | ✅ `sys.path` | ✅ `$LOAD_PATH` | All configurable |
| Circular imports | ⚠️ Possible | ⚠️ Possible | ⚠️ Possible | All can have circular issues |

---

## Literals & Data Types

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Integers | ✅ 64-bit signed | ⚠️ Arbitrary precision | ⚠️ Arbitrary precision | Quest has fixed size |
| Floats | ✅ 64-bit (f64) | ✅ 64-bit (float) | ✅ 64-bit (Float) | All equivalent |
| Decimals | ✅ Built-in | ⚠️ Via `decimal` module | ⚠️ Via `bigdecimal` | Quest: native support |
| Booleans | ✅ true, false | ✅ True, False | ✅ true, false | Quest/Ruby lowercase |
| Nil/None/Null | ✅ nil | ✅ None | ✅ nil | Quest/Ruby use `nil` |
| Symbols | ❌ | ❌ | ✅ `:symbol` | Ruby only |
| Complex numbers | ❌ | ✅ `1+2j` | ✅ Complex | Quest: not supported |
| Binary literals | ✅ `0b1010` | ✅ `0b1010` | ✅ `0b1010` | All support |
| Hex literals | ✅ `0xFF` | ✅ `0xFF` | ✅ `0xFF` | All support |
| Octal literals | ✅ `0o777` | ✅ `0o777` | ✅ `0o777` | All support |
| Scientific notation | ✅ `1e10` | ✅ `1e10` | ✅ `1e10` | All support |
| Underscores in numbers | ✅ `1_000_000` | ✅ `1_000_000` | ✅ `1_000_000` | All support |

---

## REPL & Interactive Features

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| REPL | ✅ | ✅ | ✅ (irb) | All have REPLs |
| Multi-line input | ✅ Nesting-aware | ✅ Continuation prompt | ✅ Continuation prompt | Quest tracks nesting depth |
| Last result | ⚠️ Via assignment | ✅ `_` variable | ✅ `_` variable | Quest: manual |
| Command history | ✅ | ✅ | ✅ | All support history |
| Tab completion | ⚠️ Limited | ✅ | ✅ | Python/Ruby better |
| Help system | ⚠️ `._doc()` method | ✅ `help()` | ✅ `ri` | All have docs |
| Nil suppression | ✅ Doesn't print nil | ❌ Prints None | ❌ Prints nil | Quest feature |

---

## Metaprogramming & Reflection

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Object introspection | ⚠️ Limited | ✅ `dir()`, `vars()` | ✅ Many methods | Quest: basic support |
| Type/class of object | ✅ `obj.cls()` | ✅ `type(obj)` | ✅ `obj.class` | All support |
| Callable check | ⚠️ Manual | ✅ `callable()` | ✅ `obj.respond_to?` | Quest: limited |
| Attribute access | ⚠️ Direct field access | ✅ `getattr()`, `setattr()` | ✅ `send()`, `instance_variable_get` | Quest: limited |
| Method missing | ❌ | ⚠️ `__getattr__` | ✅ `method_missing` | Ruby: most powerful |
| Define methods at runtime | ❌ | ✅ `setattr` | ✅ `define_method` | Quest: not supported |
| Eval | ❌ | ✅ `eval()` | ✅ `eval()` | Quest: not supported |
| Monkey patching | ❌ | ⚠️ Possible | ✅ Easy | Quest: not supported |
| Open classes | ❌ | ⚠️ Limited | ✅ | Ruby: powerful feature |

---

## Memory & Performance

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Manual memory management | ❌ | ❌ | ❌ | All use automatic GC |
| Reference counting | ⚠️ Rust Rc | ✅ | ❌ | Quest uses Rust's Rc |
| Garbage collection | ⚠️ Rust ownership | ✅ | ✅ | Quest relies on Rust |
| Weak references | ❌ | ✅ `weakref` | ✅ WeakRef | Quest: not supported |
| Copy semantics | ✅ Clone trait | ⚠️ Copy/deepcopy | ⚠️ dup/clone | Quest: explicit clone |
| Value vs reference | ⚠️ Hybrid | ⚠️ Hybrid | ⚠️ Hybrid | All have mixed semantics |

---

## Concurrency (Note: Most not implemented in Quest)

| Feature | Quest | Python | Ruby | Notes |
|---------|-------|--------|------|-------|
| Threads | ❌ | ✅ (GIL limited) | ✅ | Quest: not implemented |
| Async/await | ❌ | ✅ `asyncio` | ✅ Fiber | Quest: not planned |
| Coroutines | ❌ | ✅ | ✅ | Quest: not planned |
| Generators | ❌ | ✅ `yield` | ✅ `yield` | Quest: not planned |
| Multiprocessing | ❌ | ✅ | ✅ | Quest: not planned |

---

## Summary Statistics

### Feature Coverage (Approximate)

| Category | Quest | Python | Ruby |
|----------|-------|--------|------|
| Core Object Model | 90% | 95% | 95% |
| Type System | 70% | 85% | 80% |
| Control Flow | 75% | 90% | 95% |
| Functions | 70% | 95% | 95% |
| Collections | 80% | 95% | 95% |
| Exception Handling | 85% | 95% | 95% |
| Modules | 75% | 90% | 90% |
| Metaprogramming | 20% | 85% | 95% |
| Concurrency | 0% | 80% | 85% |

### Quest's Unique Features
1. **Explicit `let` declarations** - Prevents accidental variable creation
2. **`..` string concatenation operator** - Different from Python/Ruby's `+`
3. **Method reference syntax** - `obj.method` returns callable without `getattr`
4. **Type system with traits** - More explicit than Python/Ruby's duck typing
5. **Nil singleton with ID 0** - Consistent identity checking
6. **Integer overflow checking** - Safer than arbitrary precision
7. **Module namespace enforcement** - Must use `module.function()` prefix
8. **Decimal as built-in type** - Not module-based like Python
9. **Bytes literal syntax** - Python-inspired `b"..."` (Ruby uses `.bytes` method)
10. **Field type annotations** - More structured than Python/Ruby

### Quest's Design Philosophy
- **Explicit over implicit** - `let` declarations, module prefixes
- **Developer happiness** - REPL-first, clear error messages
- **Type safety** - Trait validation at definition time
- **Simplicity** - No metaprogramming complexity (yet)
- **Modern features** - Context managers, exceptions, traits

---

## Notes

- **Quest is still in active development** - Many features are works in progress
- **Standard library excluded** - This comparison focuses on core language features
- **Design goals differ** - Quest prioritizes explicit syntax and developer happiness
- Quest takes inspiration from both Python (syntax clarity) and Ruby (everything is an object)
- Some Quest features are planned but not yet implemented (marked as 🔄 in other docs)
